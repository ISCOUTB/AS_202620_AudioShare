package com.example.audioshare

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import java.util.concurrent.LinkedBlockingQueue

/**
 * Reproduce el audio en vivo que llega de la sala (receptor en Android).
 *
 * Dart decodifica los paquetes y decide cuándo debe sonar cada uno; aquí solo se
 * encolan PCM16 estéreo y se escriben en un [AudioTrack] desde un hilo propio,
 * para no bloquear el hilo principal.
 */
class LivePlayback {
    private class Chunk(val generation: Int, val data: ByteArray)

    private val lock = Any()
    private val queue = LinkedBlockingQueue<Chunk>(MAX_QUEUED_CHUNKS)
    private var track: AudioTrack? = null
    private var writer: Thread? = null
    private var sampleRate = 48000
    private var generation = 0
    private var volume = 1f
    @Volatile private var running = false

    fun start(rate: Int) {
        synchronized(lock) {
            stopLocked()
            sampleRate = rate
            running = true
            newTrackLocked()
            writer = Thread { writeLoop() }.also {
                it.name = "audioshare-playback"
                it.isDaemon = true
                it.start()
            }
        }
    }

    /**
     * Encola [pcm]. Con [reset] descarta lo pendiente y empieza un track nuevo
     * (resincronización); [silenceMs] rellena de silencio antes del audio para
     * que el paquete suene a la hora que le toca.
     */
    fun write(pcm: ByteArray, silenceMs: Int, reset: Boolean) {
        synchronized(lock) {
            if (!running) return
            if (reset) {
                generation++
                queue.clear()
                newTrackLocked()
            }
            if (silenceMs > 0) {
                val frames = sampleRate * silenceMs / 1000
                queue.offer(Chunk(generation, ByteArray(frames * BYTES_PER_FRAME)))
            }
            // Si la cola está llena se descarta el paquete: en vivo no sirve audio atrasado.
            queue.offer(Chunk(generation, pcm))
        }
    }

    fun setVolume(value: Float) {
        synchronized(lock) {
            volume = value.coerceIn(0f, 1f)
            track?.setVolume(volume)
        }
    }

    fun stop() {
        synchronized(lock) { stopLocked() }
    }

    private fun stopLocked() {
        running = false
        generation++
        queue.clear()
        writer?.interrupt()
        writer = null
        releaseTrackLocked()
    }

    private fun releaseTrackLocked() {
        val old = track ?: return
        track = null
        try { old.stop() } catch (_: IllegalStateException) {}
        old.release()
    }

    private fun newTrackLocked() {
        releaseTrackLocked()
        val minBuffer = AudioTrack.getMinBufferSize(
            sampleRate, AudioFormat.CHANNEL_OUT_STEREO, AudioFormat.ENCODING_PCM_16BIT
        )
        val created = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(sampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO)
                    .build()
            )
            // Medio segundo: cabe el retardo de 400 ms más un margen.
            .setBufferSizeInBytes(maxOf(minBuffer, sampleRate * BYTES_PER_FRAME / 2))
            .setTransferMode(AudioTrack.MODE_STREAM)
            .setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
            .build()
        created.setVolume(volume)
        created.play()
        track = created
    }

    private fun writeLoop() {
        while (running) {
            val chunk = try {
                queue.take()
            } catch (_: InterruptedException) {
                return
            }
            val target = synchronized(lock) {
                if (chunk.generation != generation) null else track
            } ?: continue
            try {
                // Bloquea hasta que cabe en el buffer; un reset lo libera.
                target.write(chunk.data, 0, chunk.data.size)
            } catch (_: IllegalStateException) {
                // El track se liberó durante una resincronización.
            }
        }
    }

    companion object {
        private const val BYTES_PER_FRAME = 4 // 2 canales x 16 bits
        private const val MAX_QUEUED_CHUNKS = 128
    }
}
