/*
 * AudioShare — motor de audio en vivo para Flutter Web (ADR-0015).
 *
 * Emisor:   captura el audio de una pestaña o de todo el sistema con
 *           getDisplayMedia, lo convierte en paquetes PCM de 16 bits y los envía
 *           por un WebSocket a /rooms/:roomId/live.
 * Receptor: recibe los paquetes por el mismo WebSocket y los reproduce con Web
 *           Audio en el instante «captura + retardo», usando el reloj del
 *           servidor (el mismo offset que ya calibra la app con GET /time).
 *
 * Dart solo pasa configuración como JSON y recibe eventos como JSON: el audio
 * nunca pasa por Dart. Protocolo de paquetes y mensajes: src/modules/live/index.ts.
 */
(function () {
  'use strict';

  var root = typeof window !== 'undefined' ? window : globalThis;

  var PROTOCOL_VERSION = 1;
  var HEADER_BYTES = 20;
  var FRAMES_PER_PACKET = 1024; // ~21 ms a 48 kHz
  var SAMPLE_RATE = 48000;
  var MAX_BUFFERED_BYTES = 512 * 1024;
  var DEFAULT_DELAY_MS = 400;
  var RESYNC_SECONDS = 0.06;
  var STATS_INTERVAL_MS = 2000;
  var FATAL_CLOSE = {
    4400: 'El servidor rechazó el protocolo de audio.',
    4401: 'La llave de emisor ya no es válida para esta sala.',
    4403: 'El emisor te sacó de la sala.',
    4404: 'La sala o el receptor ya no existen.',
    4409: 'Esta sala se abrió desde otro dispositivo o pestaña.',
    4410: 'La sala se cerró.',
    4413: 'La sala alcanzó el máximo de receptores.'
  };

  // ---------------------------------------------------------------- utilidades

  function emit(listener, event) {
    try {
      if (listener) listener(JSON.stringify(event));
    } catch (error) {
      // Un fallo del oyente no debe tumbar el audio.
    }
  }

  function messageOf(error) {
    return error && error.message ? error.message : String(error);
  }

  function describeClose(code) {
    return FATAL_CLOSE[code] || null;
  }

  function wait(ms) {
    return new Promise(function (resolve) { setTimeout(resolve, ms); });
  }

  // ------------------------------------------------------------- paquetes (v1)

  /** Cabecera de 20 bytes + muestras PCM16 intercaladas (little endian). */
  function buildPacket(pcm, channels, sampleRate, sequence, captureMs) {
    var buffer = new ArrayBuffer(HEADER_BYTES + pcm.byteLength);
    var view = new DataView(buffer);

    view.setUint8(0, PROTOCOL_VERSION);
    view.setUint8(1, 0); // códec 0 = PCM16
    view.setUint8(2, channels);
    view.setUint8(3, 0);
    view.setUint32(4, sampleRate, true);
    view.setUint32(8, sequence >>> 0, true);
    view.setFloat64(12, captureMs, true);
    new Uint8Array(buffer, HEADER_BYTES).set(new Uint8Array(pcm));

    return buffer;
  }

  /** Devuelve null si el paquete no es válido. */
  function parsePacket(buffer) {
    if (!(buffer instanceof ArrayBuffer) || buffer.byteLength <= HEADER_BYTES) return null;

    var view = new DataView(buffer);
    var channels = view.getUint8(2);
    var sampleRate = view.getUint32(4, true);
    var payload = buffer.byteLength - HEADER_BYTES;

    if (view.getUint8(0) !== PROTOCOL_VERSION || view.getUint8(1) !== 0) return null;
    if (channels !== 1 && channels !== 2) return null;
    if (sampleRate < 8000 || sampleRate > 96000) return null;
    if (payload % (2 * channels) !== 0) return null;

    return {
      channels: channels,
      sampleRate: sampleRate,
      sequence: view.getUint32(8, true),
      captureMs: view.getFloat64(12, true),
      frames: payload / (2 * channels)
    };
  }

  /**
   * Línea de tiempo de captura: marca cada paquete con su instante en reloj del
   * servidor. Se avanza por duración de muestras (sin la inestabilidad de
   * cuándo se entrega el mensaje) y se corrige despacio hacia el reloj real.
   */
  function createTimeline() {
    var next = null;

    return function stamp(nowServerMs, durationMs) {
      var arrivalStart = nowServerMs - durationMs;

      if (next === null || Math.abs(arrivalStart - next) > 100) {
        next = arrivalStart;
      }

      var captureMs = next;

      next += durationMs + (arrivalStart - next) * 0.01;

      return captureMs;
    };
  }

  /**
   * Cuándo (en tiempo del AudioContext) debe sonar un paquete. Devuelve null si
   * ya es tarde para tocarlo; así el retardo se mantiene aunque la red se atasque.
   */
  function schedulePacket(state, ctxTime, nowServerMs, packet, delayMs) {
    var ideal = ctxTime + (packet.captureMs + delayMs - nowServerMs) / 1000;
    var duration = packet.frames / packet.sampleRate;

    if (ideal + duration < ctxTime + 0.005) return { when: null, resynced: false };

    var resync = state.nextTime === null ||
      state.nextTime < ctxTime ||
      Math.abs(ideal - state.nextTime) > RESYNC_SECONDS;
    var when = resync ? Math.max(ideal, ctxTime + 0.01) : state.nextTime;

    state.nextTime = when + duration;

    return { when: when, resynced: resync && state.started === true };
  }

  // ------------------------------------------------------------ capacidades

  function audioContextClass() {
    return root.AudioContext || root.webkitAudioContext || null;
  }

  function capabilities() {
    var ua = (root.navigator && root.navigator.userAgent) || '';
    var mobile = /Android|iPhone|iPad|iPod/.test(ua);
    var chromium = /Chrome\/|Chromium\/|Edg\//.test(ua);
    var hasDisplayMedia = !!(root.navigator && root.navigator.mediaDevices &&
      root.navigator.mediaDevices.getDisplayMedia);
    var hasWorklet = typeof root.AudioWorkletNode !== 'undefined' && !!audioContextClass();
    var systemAudio = /Windows|CrOS/.test(ua);
    var emitReason = null;

    if (mobile) {
      emitReason = 'Los navegadores del teléfono no pueden capturar audio. Transmite desde un computador o desde la app nativa.';
    } else if (!hasDisplayMedia || !hasWorklet) {
      emitReason = 'Este navegador no permite capturar audio de la pantalla. Usa Chrome o Edge en un computador.';
    } else if (!chromium) {
      emitReason = 'Firefox y Safari no entregan el audio al compartir pantalla. Usa Chrome o Edge en un computador.';
    }

    return JSON.stringify({
      receive: !!audioContextClass(),
      device: emitReason ? { ok: false, reason: emitReason } :
        systemAudio ? { ok: true } :
          { ok: false, reason: 'En macOS y Linux el navegador no puede capturar el audio del sistema. Elige «Una pestaña».' },
      app: { ok: false, reason: 'Un navegador no puede capturar el audio de una sola aplicación. Elige «Una pestaña», o usa la app de Android o de escritorio.' },
      tab: emitReason ? { ok: false, reason: emitReason } : { ok: true }
    });
  }

  // ------------------------------------------------------------------ emisor

  var WORKLET_SOURCE =
    'class AudioSharePcm extends AudioWorkletProcessor {' +
    '  constructor(options) {' +
    '    super();' +
    '    this.frames = options.processorOptions.frames;' +
    '    this.left = new Float32Array(this.frames);' +
    '    this.right = new Float32Array(this.frames);' +
    '    this.filled = 0;' +
    '  }' +
    '  process(inputs) {' +
    '    var input = inputs[0];' +
    '    if (!input || input.length === 0) return true;' +
    '    var l = input[0];' +
    '    var r = input.length > 1 ? input[1] : input[0];' +
    '    var offset = 0;' +
    '    while (offset < l.length) {' +
    '      var n = Math.min(this.frames - this.filled, l.length - offset);' +
    '      this.left.set(l.subarray(offset, offset + n), this.filled);' +
    '      this.right.set(r.subarray(offset, offset + n), this.filled);' +
    '      this.filled += n;' +
    '      offset += n;' +
    '      if (this.filled === this.frames) {' +
    '        var out = new Int16Array(this.frames * 2);' +
    '        for (var i = 0; i < this.frames; i++) {' +
    '          var a = Math.max(-1, Math.min(1, this.left[i]));' +
    '          var b = Math.max(-1, Math.min(1, this.right[i]));' +
    '          out[2 * i] = a < 0 ? a * 32768 : a * 32767;' +
    '          out[2 * i + 1] = b < 0 ? b * 32768 : b * 32767;' +
    '        }' +
    '        this.port.postMessage({ pcm: out.buffer }, [out.buffer]);' +
    '        this.filled = 0;' +
    '      }' +
    '    }' +
    '    return true;' +
    '  }' +
    '}' +
    'registerProcessor("audioshare-pcm", AudioSharePcm);';

  var emitter = null;

  function sourceLabel(source) {
    return source === 'device' ? 'Todo el dispositivo' : source === 'app' ? 'Una aplicación' : 'Una pestaña';
  }

  function stopTracks(stream) {
    if (!stream) return;
    stream.getTracks().forEach(function (track) {
      try { track.stop(); } catch (error) { /* ya estaba detenida */ }
    });
  }

  /** Pide al usuario qué compartir y comprueba que de verdad llegue audio. */
  async function captureStream(source) {
    var media = root.navigator && root.navigator.mediaDevices;

    if (!media || !media.getDisplayMedia) {
      throw new Error('Este navegador no permite capturar audio de la pantalla.');
    }

    var options = {
      audio: { echoCancellation: false, noiseSuppression: false, autoGainControl: false, channelCount: 2 },
      video: { displaySurface: source === 'tab' ? 'browser' : 'monitor' },
      selfBrowserSurface: 'exclude',
      systemAudio: source === 'tab' ? 'exclude' : 'include'
    };

    if (source === 'device') options.monitorTypeSurfaces = 'include';

    var stream;

    try {
      stream = await media.getDisplayMedia(options);
    } catch (error) {
      if (error && (error.name === 'NotAllowedError' || error.name === 'AbortError')) {
        throw new Error('Cancelaste la selección o el navegador no dio permiso.');
      }
      throw error;
    }

    var video = stream.getVideoTracks()[0];
    var surface = video && video.getSettings ? video.getSettings().displaySurface : undefined;

    if (source === 'tab' && surface && surface !== 'browser') {
      stopTracks(stream);
      throw new Error('Elegiste una ventana o una pantalla. Para compartir una pestaña elige la opción «Pestaña de Chrome».');
    }

    if (source === 'device' && surface && surface !== 'monitor') {
      stopTracks(stream);
      throw new Error('Para compartir todo el dispositivo elige «Pantalla completa» en el selector.');
    }

    if (stream.getAudioTracks().length === 0) {
      stopTracks(stream);
      throw new Error(source === 'tab'
        ? 'No se compartió audio. En el selector, elige la pestaña y activa «Compartir audio de la pestaña».'
        : 'No se compartió el audio del sistema. Elige «Pantalla completa» y activa «Compartir audio del sistema».');
    }

    // El vídeo no se usa, pero se deja vivo: el navegador lo exige para mantener
    // la captura y así «Dejar de compartir» del navegador corta todo a la vez.
    if (video && video.applyConstraints) {
      try { await video.applyConstraints({ frameRate: 1, width: 320, height: 180 }); } catch (error) { /* opcional */ }
    }

    return stream;
  }

  function sendControl(ws, message) {
    if (ws && ws.readyState === 1) ws.send(JSON.stringify(message));
  }

  async function startEmitInternal(configJson, listener) {
    var config = JSON.parse(configJson);
    var source = config.source;
    var offsetMs = Number(config.offsetMs) || 0;

    if (source !== 'device' && source !== 'tab') {
      throw new Error('Este navegador no puede compartir «' + sourceLabel(source) + '».');
    }

    stopEmit(true);
    emit(listener, { type: 'state', side: 'emit', state: 'connecting', source: source });

    var Context = audioContextClass();

    if (!Context || typeof root.AudioWorkletNode === 'undefined') {
      throw new Error('Este navegador no soporta AudioWorklet.');
    }

    // Se pide la captura primero: es lo que exige un gesto reciente del usuario.
    var stream = await captureStream(source);
    var session = {
      source: source,
      label: sourceLabel(source),
      listener: listener,
      stream: stream,
      ctx: null,
      ws: null,
      ready: false,
      stopped: false,
      attempt: 0,
      sequence: 0,
      timeline: createTimeline(),
      sent: 0,
      dropped: 0,
      statsAt: Date.now()
    };

    emitter = session;

    try {
      session.ctx = new Context({ sampleRate: SAMPLE_RATE, latencyHint: 'interactive' });
      if (session.ctx.state === 'suspended') await session.ctx.resume();

      var url = URL.createObjectURL(new Blob([WORKLET_SOURCE], { type: 'application/javascript' }));

      try {
        await session.ctx.audioWorklet.addModule(url);
      } finally {
        URL.revokeObjectURL(url);
      }

      var input = session.ctx.createMediaStreamSource(new root.MediaStream(stream.getAudioTracks()));
      var node = new root.AudioWorkletNode(session.ctx, 'audioshare-pcm', {
        numberOfInputs: 1,
        numberOfOutputs: 1,
        outputChannelCount: [2],
        processorOptions: { frames: FRAMES_PER_PACKET }
      });
      var mute = session.ctx.createGain();

      mute.gain.value = 0; // el nodo debe llegar a la salida para que el navegador lo procese
      input.connect(node);
      node.connect(mute);
      mute.connect(session.ctx.destination);

      node.port.onmessage = function (event) {
        var ws = session.ws;
        var pcm = event.data && event.data.pcm;

        if (session.stopped || !pcm || !session.ready || !ws || ws.readyState !== 1) return;

        if (ws.bufferedAmount > MAX_BUFFERED_BYTES) {
          session.dropped += 1; // en vivo no sirve acumular audio atrasado
          return;
        }

        var rate = session.ctx.sampleRate;
        var durationMs = (FRAMES_PER_PACKET / rate) * 1000;
        var captureMs = session.timeline(Date.now() + offsetMs, durationMs);

        ws.send(buildPacket(pcm, 2, rate, session.sequence, captureMs));
        session.sequence += 1;
        session.sent += 1;

        if (Date.now() - session.statsAt >= STATS_INTERVAL_MS) {
          session.statsAt = Date.now();
          emit(session.listener, { type: 'stats', side: 'emit', sent: session.sent, dropped: session.dropped });
        }
      };

      // «Dejar de compartir» del navegador.
      stream.getTracks().forEach(function (track) {
        track.addEventListener('ended', function () {
          if (!session.stopped) finishEmit(session, 'ended', 'Dejaste de compartir desde el navegador.');
        });
      });
    } catch (error) {
      finishEmit(session, 'error', messageOf(error));
      throw error;
    }

    connectEmitter(session, config);
  }

  /** Devuelve '' si todo fue bien o el mensaje de error: así Dart no maneja promesas rechazadas. */
  async function startEmit(configJson, listener) {
    try {
      await startEmitInternal(configJson, listener);
      return '';
    } catch (error) {
      return messageOf(error) || 'No se pudo empezar a compartir.';
    }
  }

  function connectEmitter(session, config) {
    if (session.stopped) return;

    var ws = new root.WebSocket(config.url);

    ws.binaryType = 'arraybuffer';
    session.ws = ws;
    session.ready = false;

    ws.onopen = function () {
      sendControl(ws, { type: 'hello', role: 'emitter', key: config.key });
    };

    ws.onmessage = function (event) {
      if (typeof event.data !== 'string') return;

      var message;

      try { message = JSON.parse(event.data); } catch (error) { return; }

      if (message.type === 'ready') {
        session.ready = true;
        session.attempt = 0;
        sendControl(ws, { type: 'live.start', source: session.source, label: session.label });
        emit(session.listener, { type: 'state', side: 'emit', state: 'sharing', source: session.source, label: session.label });
      }
    };

    ws.onclose = function (event) {
      if (session.stopped || session.ws !== ws) return;

      session.ready = false;

      var fatal = describeClose(event.code);

      if (fatal) {
        finishEmit(session, 'error', fatal, event.code);
        return;
      }

      session.attempt += 1;
      emit(session.listener, { type: 'state', side: 'emit', state: 'reconnecting', source: session.source });
      setTimeout(function () { connectEmitter(session, config); }, Math.min(5000, 500 * session.attempt));
    };

    ws.onerror = function () { /* el cierre posterior informa del motivo */ };
  }

  function finishEmit(session, state, message, code) {
    if (session.stopped) return;

    session.stopped = true;

    try {
      sendControl(session.ws, { type: 'live.stop' });
      if (session.ws) session.ws.close(1000);
    } catch (error) { /* ya estaba cerrado */ }

    stopTracks(session.stream);

    if (session.ctx && session.ctx.state !== 'closed') {
      try { session.ctx.close(); } catch (error) { /* ya estaba cerrado */ }
    }

    if (emitter === session) emitter = null;

    emit(session.listener, { type: 'state', side: 'emit', state: state, message: message, code: code });
  }

  function stopEmit(silent) {
    if (!emitter) return;

    var session = emitter;

    finishEmit(session, 'closed', silent ? undefined : 'Dejaste de compartir.');
  }

  // ---------------------------------------------------------------- receptor

  var rxCtx = null;
  var rxGain = null;
  var rxVolume = 0.8;
  var receiver = null;

  function ensureReceiverContext() {
    var Context = audioContextClass();

    if (!Context) throw new Error('Este navegador no soporta Web Audio.');

    if (!rxCtx || rxCtx.state === 'closed') {
      rxCtx = new Context({ sampleRate: SAMPLE_RATE, latencyHint: 'interactive' });
      rxGain = rxCtx.createGain();
      rxGain.gain.value = rxVolume;
      rxGain.connect(rxCtx.destination);
    }

    return rxCtx;
  }

  /** Llamar dentro de un gesto del usuario (clic): desbloquea el audio. */
  async function prepareReceiver() {
    var ctx;

    try {
      ctx = ensureReceiverContext();
    } catch (error) {
      return 'unsupported';
    }

    if (ctx.state === 'suspended') {
      try { await ctx.resume(); } catch (error) { /* se informará como bloqueado */ }
    }

    return ctx.state === 'running' ? 'running' : 'blocked';
  }

  function startReceive(configJson, listener) {
    var config = JSON.parse(configJson);

    stopReceive(true);

    try {
      ensureReceiverContext();
    } catch (error) {
      emit(listener, { type: 'state', side: 'receive', state: 'error', message: messageOf(error) });
      return;
    }

    var session = {
      config: config,
      listener: listener,
      delayMs: Number(config.delayMs) > 0 ? Number(config.delayMs) : DEFAULT_DELAY_MS,
      offsetMs: Number(config.offsetMs) || 0,
      ws: null,
      stopped: false,
      attempt: 0,
      active: false,
      nextTime: null,
      started: false,
      playing: false,
      blockedReported: false,
      played: 0,
      late: 0,
      resyncs: 0,
      statsAt: Date.now()
    };

    receiver = session;
    emit(listener, { type: 'state', side: 'receive', state: 'connecting' });
    connectReceiver(session);
  }

  function connectReceiver(session) {
    if (session.stopped) return;

    var ws = new root.WebSocket(session.config.url);

    ws.binaryType = 'arraybuffer';
    session.ws = ws;

    ws.onopen = function () {
      sendControl(ws, { type: 'hello', role: 'receiver', receiverId: session.config.receiverId });
    };

    ws.onmessage = function (event) {
      if (session.stopped || session.ws !== ws) return;

      if (typeof event.data === 'string') {
        var message;

        try { message = JSON.parse(event.data); } catch (error) { return; }

        if (message.type === 'ready') {
          session.attempt = 0;
          emit(session.listener, { type: 'state', side: 'receive', state: 'connected' });
        } else if (message.type === 'live.state') {
          session.active = !!message.active;

          if (!session.active) {
            session.nextTime = null;
            session.playing = false;
          }

          emit(session.listener, {
            type: 'live',
            active: session.active,
            source: message.source || null,
            label: message.label || null
          });
        }

        return;
      }

      playPacket(session, event.data);
    };

    ws.onclose = function (event) {
      if (session.stopped || session.ws !== ws) return;

      session.playing = false;
      session.nextTime = null;

      var fatal = describeClose(event.code);

      if (fatal) {
        session.stopped = true;
        if (receiver === session) receiver = null;
        emit(session.listener, { type: 'state', side: 'receive', state: 'error', message: fatal, code: event.code });
        return;
      }

      session.attempt += 1;
      emit(session.listener, { type: 'state', side: 'receive', state: 'reconnecting' });
      setTimeout(function () { connectReceiver(session); }, Math.min(5000, 500 * session.attempt));
    };

    ws.onerror = function () { /* el cierre posterior informa del motivo */ };
  }

  function playPacket(session, buffer) {
    var ctx = rxCtx;
    var packet = parsePacket(buffer);

    if (!ctx || !packet) return;

    if (ctx.state !== 'running') {
      try { ctx.resume(); } catch (error) { /* sigue bloqueado */ }

      if (!session.blockedReported) {
        session.blockedReported = true;
        emit(session.listener, { type: 'state', side: 'receive', state: 'blocked',
          message: 'El navegador bloqueó el audio. Toca «Activar audio».' });
      }

      return;
    }

    session.blockedReported = false;

    var slot = schedulePacket(session, ctx.currentTime, Date.now() + session.offsetMs, packet, session.delayMs);

    if (slot.when === null) {
      session.late += 1;
      return;
    }

    if (slot.resynced) session.resyncs += 1;

    var audio = ctx.createBuffer(2, packet.frames, packet.sampleRate);
    var left = audio.getChannelData(0);
    var right = audio.getChannelData(1);
    var samples = new Int16Array(buffer, HEADER_BYTES, packet.frames * packet.channels);

    for (var i = 0; i < packet.frames; i++) {
      left[i] = samples[i * packet.channels] / 32768;
      right[i] = packet.channels === 2 ? samples[i * packet.channels + 1] / 32768 : left[i];
    }

    var node = ctx.createBufferSource();

    node.buffer = audio;
    node.connect(rxGain);
    node.start(slot.when);
    session.started = true;
    session.played += 1;

    if (!session.playing) {
      session.playing = true;
      emit(session.listener, { type: 'state', side: 'receive', state: 'playing' });
    }

    if (Date.now() - session.statsAt >= STATS_INTERVAL_MS) {
      session.statsAt = Date.now();
      emit(session.listener, {
        type: 'stats',
        side: 'receive',
        latencyMs: Math.round((slot.when - ctx.currentTime) * 1000),
        played: session.played,
        late: session.late,
        resyncs: session.resyncs
      });
    }
  }

  function stopReceive(silent) {
    if (!receiver) return;

    var session = receiver;

    session.stopped = true;
    receiver = null;

    try { if (session.ws) session.ws.close(1000); } catch (error) { /* ya estaba cerrado */ }

    if (!silent) emit(session.listener, { type: 'state', side: 'receive', state: 'closed' });
  }

  function setVolume(value) {
    var volume = Math.max(0, Math.min(1, Number(value)));

    rxVolume = isNaN(volume) ? rxVolume : volume;

    if (rxGain && rxCtx) rxGain.gain.setTargetAtTime(rxVolume, rxCtx.currentTime, 0.02);
  }

  // --------------------------------------------------------------------- API

  root.AudioShareLive = {
    version: PROTOCOL_VERSION,
    capabilities: capabilities,
    prepareReceiver: prepareReceiver,
    unlock: prepareReceiver,
    startEmit: startEmit,
    stopEmit: function () { stopEmit(false); },
    startReceive: startReceive,
    stopReceive: function () { stopReceive(false); },
    setVolume: setVolume,
    // Solo para pruebas.
    _internals: {
      buildPacket: buildPacket,
      parsePacket: parsePacket,
      createTimeline: createTimeline,
      schedulePacket: schedulePacket,
      HEADER_BYTES: HEADER_BYTES,
      wait: wait
    }
  };
})();
