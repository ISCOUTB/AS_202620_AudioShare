import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_client.dart';
import '../../../audio/data/audio_track_repository.dart';
import '../../../audio/data/mp3_picker.dart';
import '../../../audio/domain/audio_service.dart';
import '../../../sync/data/sync_repository.dart';
import '../../data/emitter_session_store.dart';
import '../../data/repositories/room_control_repository.dart';
import '../../data/repositories/room_repository.dart';
import '../viewmodels/session_view_model.dart';
import 'room_page.dart';

enum _Mode { join, create }

/// Longitud del código de sala que genera el servidor.
const _roomCodeLength = 6;

/// Longitud máxima del nombre que acepta el servidor.
const _maxNameLength = 30;

class HomePage extends StatefulWidget {
  const HomePage({
    required this.repository,
    this.syncRepository,
    this.api,
    this.audioFactory,
    this.audioTrackRepository,
    this.control,
    this.emitterStore,
    super.key,
  });
  final RoomRepository repository;
  final SyncRepository? syncRepository;

  /// Si se indica, se muestran las opciones avanzadas del servidor y se
  /// descarga la pista de la sala.
  final ApiClient? api;

  /// Crea el [AudioService] de cada sala; por defecto, el simulado.
  final AudioService Function()? audioFactory;
  final AudioTrackRepository? audioTrackRepository;

  /// Salir, expulsar, cerrar la sala y volver como emisor.
  final RoomControlRepository? control;

  /// Dónde se guarda la llave de la sala de la que este dispositivo es emisor.
  final EmitterSessionStore? emitterStore;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final codeController = TextEditingController();
  final nameController = TextEditingController();
  late final String _defaultServer = widget.api?.baseUri.toString() ?? '';
  late final serverController = TextEditingController(text: _defaultServer);
  _Mode _mode = _Mode.join;
  String? error;
  String? notice;
  bool loading = false;
  PickedMp3? selected;
  EmitterSession? _saved;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    codeController.dispose();
    nameController.dispose();
    serverController.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final session = await widget.emitterStore?.load();
    if (mounted) setState(() => _saved = session);
  }

  String? _nameProblem() {
    final name = nameController.text.trim();
    if (name.isEmpty) return 'Escribe tu nombre para continuar.';
    if (name.length > _maxNameLength) {
      return 'El nombre puede tener hasta $_maxNameLength caracteres.';
    }
    return null;
  }

  /// Aplica el servidor escrito en las opciones avanzadas. Devuelve false (y
  /// muestra el error) si no es una dirección válida.
  bool _applyServer() {
    final api = widget.api;
    if (api == null) return true;
    final server = Uri.tryParse(serverController.text.trim());
    if (server == null || !(server.scheme == 'http' || server.scheme == 'https') || server.host.isEmpty) {
      setState(() => error = 'Servidor inválido. Usa el formato http://192.168.1.10:3000');
      return false;
    }
    api.baseUri = server;
    return true;
  }

  SessionViewModel _newViewModel() => SessionViewModel(
        repository: widget.repository,
        syncRepository: widget.syncRepository,
        control: widget.control,
        trackRepository: widget.audioTrackRepository,
        audio: widget.audioFactory?.call(),
        trackUri: widget.api?.resolve('/track'),
      );

  void _fail(SessionViewModel viewModel, String message) {
    viewModel.dispose();
    if (mounted) {
      setState(() {
        loading = false;
        error = message;
      });
    }
  }

  Future<void> _join() async {
    final problem = _nameProblem();
    final code = codeController.text.trim();
    if (code.length != _roomCodeLength) {
      setState(() => error = 'El código de la sala tiene $_roomCodeLength dígitos.');
      return;
    }
    if (problem != null) {
      setState(() => error = problem);
      return;
    }
    if (!_applyServer()) return;
    setState(() {
      loading = true;
      error = null;
      notice = null;
    });
    final viewModel = _newViewModel();
    await viewModel.joinRoom(code, nameController.text.trim());
    if (!mounted) {
      viewModel.dispose();
      return;
    }
    final failure = viewModel.error;
    if (failure != null) {
      _fail(viewModel, failure);
      return;
    }
    await _enter(viewModel);
  }

  Future<void> _create() async {
    final problem = _nameProblem();
    if (problem != null) {
      setState(() => error = problem);
      return;
    }
    final track = selected;
    final uploader = widget.audioTrackRepository;
    if (uploader != null && track == null) {
      setState(() => error = 'Selecciona un archivo MP3 antes de crear la sala.');
      return;
    }
    if (!_applyServer()) return;
    if (_saved != null && !await _confirmReplace()) return;
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
      notice = null;
    });
    final name = nameController.text.trim();
    final viewModel = _newViewModel();
    await viewModel.createRoom(name);
    if (!mounted) {
      viewModel.dispose();
      return;
    }
    final failure = viewModel.error;
    if (failure != null) {
      _fail(viewModel, failure);
      return;
    }
    final roomId = viewModel.room!.id;
    if (uploader != null && track != null) {
      try {
        await uploader.upload(roomId, track.bytes, trackName: track.name);
        // El emisor también descarga la pista para oírla con los receptores.
        await viewModel.prepareOwnTrack();
      } catch (exception) {
        _fail(viewModel, 'No se pudo subir el MP3: $exception');
        return;
      }
    }
    final key = widget.api?.emitterKeys[roomId];
    final store = widget.emitterStore;
    if (store != null && key != null) {
      final session = EmitterSession(roomId: roomId, emitterId: name, emitterKey: key);
      await store.save(session);
      _saved = session;
    }
    if (!mounted) {
      viewModel.dispose();
      return;
    }
    await _enter(viewModel);
  }

  Future<void> _resume(EmitterSession session) async {
    final control = widget.control;
    if (control == null || !_applyServer()) return;
    setState(() {
      loading = true;
      error = null;
      notice = null;
    });
    final String emitterId;
    try {
      emitterId = await control.rejoinAsEmitter(session.roomId, session.emitterKey);
    } on ApiException catch (exception) {
      final status = exception.statusCode;
      final gone = status == 401 || status == 403 || status == 404;
      if (gone) await widget.emitterStore?.clear();
      if (!mounted) return;
      setState(() {
        loading = false;
        if (gone) _saved = null;
        error = gone ? 'Esa sala ya no existe o caducó.' : exception.message;
      });
      return;
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'No se pudo volver a la sala: $exception';
      });
      return;
    }
    if (!mounted) return;
    final viewModel = _newViewModel();
    await viewModel.restoreEmitter(session.roomId, emitterId);
    if (!mounted) {
      viewModel.dispose();
      return;
    }
    final failure = viewModel.error;
    if (failure != null) {
      _fail(viewModel, failure);
      return;
    }
    await _enter(viewModel);
  }

  Future<void> _enter(SessionViewModel viewModel) async {
    final result = await Navigator.of(context).push<RoomEnd>(
      MaterialPageRoute(builder: (_) => RoomPage(viewModel: viewModel)),
    );
    final emitter = viewModel.isEmitter;
    final sessionEnded = emitter && (result == RoomEnd.closed || result == RoomEnd.gone);
    if (sessionEnded) await widget.emitterStore?.clear();
    final saved = sessionEnded ? null : await widget.emitterStore?.load();
    if (!mounted) return;
    setState(() {
      loading = false;
      _saved = saved;
      notice = _noticeFor(result, emitter);
    });
  }

  String? _noticeFor(RoomEnd? reason, bool emitter) => switch (reason) {
        RoomEnd.removed => 'El emisor te expulsó de la sala.',
        RoomEnd.closed => emitter ? 'Cerraste la sala.' : 'El emisor cerró la sala.',
        RoomEnd.gone => 'La sala ya no existe.',
        RoomEnd.left || null => null,
      };

  Future<bool> _confirmReplace() async {
    final replace = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ya tienes una sala activa'),
        content: Text('Si creas otra, perderás el acceso a la sala ${_saved?.roomId}. ¿Continuar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Crear otra'),
          ),
        ],
      ),
    );
    return replace == true;
  }

  Future<void> _pickTrack() async {
    try {
      final picked = await pickMp3();
      if (picked == null || !mounted) return;
      setState(() {
        selected = picked;
        error = null;
      });
    } on Mp3PickException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final saved = _saved;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 24),
                Row(
                  children: [
                    Icon(Icons.graphic_eq, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'AUDIOSHARE',
                      style: textTheme.labelLarge?.copyWith(letterSpacing: 2, color: scheme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Escuchen lo mismo,\nal mismo tiempo.',
                  style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text('Crea una sala y comparte el código, o únete con el código de otra persona.'),
                const SizedBox(height: 24),
                if (saved != null) ...[
                  _ActiveRoomCard(
                    session: saved,
                    busy: loading,
                    onResume: () => _resume(saved),
                  ),
                  const SizedBox(height: 16),
                ],
                if (notice != null) _Banner(notice!, isError: false),
                SegmentedButton<_Mode>(
                  segments: const [
                    ButtonSegment(value: _Mode.join, icon: Icon(Icons.headphones), label: Text('Unirme')),
                    ButtonSegment(value: _Mode.create, icon: Icon(Icons.add_circle_outline), label: Text('Crear sala')),
                  ],
                  selected: {_mode},
                  onSelectionChanged: loading
                      ? null
                      : (selection) => setState(() {
                            _mode = selection.first;
                            error = null;
                          }),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _mode == _Mode.join ? _joinForm(context) : _createForm(),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  _Banner(error!, isError: true),
                ],
                if (widget.api != null) ...[
                  const SizedBox(height: 8),
                  _AdvancedOptions(
                    controller: serverController,
                    onReset: () => serverController.text = _defaultServer,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _nameField() => TextField(
        key: const Key('nombre'),
        controller: nameController,
        maxLength: _maxNameLength,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Tu nombre',
          helperText: 'Así te verán los demás en la sala.',
          counterText: '',
        ),
      );

  Widget _primaryButton(String label, VoidCallback onPressed) => SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          key: const Key('accion-principal'),
          onPressed: loading ? null : onPressed,
          icon: loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.arrow_forward),
          label: Text(label),
        ),
      );

  Widget _joinForm(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('codigo-sala'),
            controller: codeController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(_roomCodeLength),
            ],
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  letterSpacing: 8,
                  fontWeight: FontWeight.bold,
                ),
            decoration: const InputDecoration(labelText: 'Código de la sala', hintText: '000000'),
          ),
          const SizedBox(height: 12),
          _nameField(),
          const SizedBox(height: 16),
          _primaryButton('Unirme a la sala', _join),
        ],
      );

  Widget _createForm() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _nameField(),
          if (widget.audioTrackRepository != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: loading ? null : _pickTrack,
                  icon: const Icon(Icons.audio_file),
                  label: const Text('Elegir MP3'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selected?.name ?? 'La canción se enviará a los receptores.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _primaryButton('Crear sala', _create),
        ],
      );
}

class _ActiveRoomCard extends StatelessWidget {
  const _ActiveRoomCard({required this.session, required this.busy, required this.onResume});
  final EmitterSession session;
  final bool busy;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: ListTile(
          leading: const Icon(Icons.meeting_room_outlined),
          title: Text('Tu sala activa: ${session.roomId}'),
          subtitle: const Text('Eres el emisor. Vuelve para controlarla.'),
          trailing: FilledButton(
            onPressed: busy ? null : onResume,
            child: const Text('Volver'),
          ),
        ),
      );
}

class _AdvancedOptions extends StatelessWidget {
  const _AdvancedOptions({required this.controller, required this.onReset});
  final TextEditingController controller;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => ExpansionTile(
        tilePadding: EdgeInsets.zero,
        shape: const Border(),
        collapsedShape: const Border(),
        title: const Text('Opciones avanzadas'),
        subtitle: const Text('Solo para quien usa su propio servidor'),
        children: [
          const Text(
            'No lo cambies a menos que tu equipo te indique otro servidor. '
            'Todos deben usar el mismo servidor para encontrarse en una sala.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Servidor',
              helperText: 'Por ejemplo http://192.168.1.10:3000',
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.restore),
              label: const Text('Restablecer'),
            ),
          ),
        ],
      );
}

class _Banner extends StatelessWidget {
  const _Banner(this.message, {required this.isError});
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.info_outline,
            size: 20,
            color: isError ? scheme.error : scheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: isError ? scheme.error : null)),
          ),
        ],
      ),
    );
  }
}
