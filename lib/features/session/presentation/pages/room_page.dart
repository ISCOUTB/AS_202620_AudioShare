import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../audio/data/mp3_picker.dart';
import '../../../sync/domain/sync_service.dart';
import '../../data/models/room.dart';
import '../viewmodels/session_view_model.dart';

class RoomPage extends StatefulWidget {
  const RoomPage({required this.viewModel, super.key});
  final SessionViewModel viewModel;

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  bool _closing = false;

  /// Posición (ms) que el emisor está arrastrando en la barra, mientras no la suelta.
  double? _dragMs;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_changed);
    // Con la sala sonando la barra avanza sola; se repinta cada medio segundo.
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted && widget.viewModel.room?.status == PlaybackStatus.playing) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    widget.viewModel.removeListener(_changed);
    widget.viewModel.dispose();
    super.dispose();
  }

  void _changed() {
    final reason = widget.viewModel.ended;
    if (reason != null && !_closing) {
      // La sala terminó para este dispositivo: se vuelve al inicio con el motivo.
      _closing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(reason);
      });
    }
    if (mounted) setState(() {});
  }

  Future<void> _confirmLeave() async {
    final model = widget.viewModel;
    final emitter = model.isEmitter;
    final choice = await showDialog<_LeaveChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(emitter ? '¿Salir de tu sala?' : '¿Salir de la sala?'),
        content: Text(
          emitter
              ? 'Si sales, la sala sigue activa y puedes volver desde la pantalla de inicio. '
                  'Si la cierras, se borra para todos.'
              : 'Dejarás de escuchar y desaparecerás de la lista de participantes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          if (emitter)
            TextButton(
              onPressed: () => Navigator.of(context).pop(_LeaveChoice.close),
              child: const Text('Cerrar sala'),
            ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_LeaveChoice.leave),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (choice == _LeaveChoice.leave) await model.leaveRoom();
    if (choice == _LeaveChoice.close) await model.closeRoom();
  }

  Future<void> _confirmKick(Participant participant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Expulsar a ${participant.id}?'),
        content: const Text('Saldrá de la sala y no podrá volver a entrar con ese nombre.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Expulsar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.viewModel.kick(participant.id);
  }

  Future<void> _changeTrack() async {
    final model = widget.viewModel;
    try {
      final picked = await pickMp3();
      if (picked == null) return;
      await model.changeTrack(picked.bytes, picked.name);
    } on Mp3PickException catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exception.message)));
    }
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código copiado')));
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.viewModel;
    final room = model.room;
    if (room == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final emitter = model.isEmitter;
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Sala AudioShare'),
          actions: [
            TextButton.icon(
              onPressed: _confirmLeave,
              icon: const Icon(Icons.logout),
              label: const Text('Salir'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: model.refresh,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _CodeCard(code: room.id, onCopy: () => _copyCode(room.id)),
              const SizedBox(height: 16),
              _NowPlayingCard(
                room: room,
                emitter: emitter,
                busy: model.loading,
                positionMs: _dragMs?.round() ?? model.currentPositionMs(),
                durationMs: model.durationMs,
                onPlay: model.play,
                onPause: model.pause,
                onChangeTrack: model.trackRepository == null ? null : _changeTrack,
                onDrag: (value) => setState(() => _dragMs = value),
                onSeekEnd: (value) async {
                  await model.seekTo(value.round());
                  if (mounted) setState(() => _dragMs = null);
                },
                onSeekBy: model.seekBy,
                onRestart: () => model.seekTo(0),
              ),
              if (model.trackStatus != TrackStatus.none) ...[
                const SizedBox(height: 12),
                _TrackCard(
                  status: model.trackStatus,
                  loading: model.loading,
                  onRetry: model.retryTrack,
                ),
              ],
              if (model.error != null) ...[
                const SizedBox(height: 12),
                Text(model.error!, style: TextStyle(color: scheme.error)),
              ],
              const SizedBox(height: 22),
              Text(
                'PARTICIPANTES (${room.participants.length})',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 1),
              ),
              const SizedBox(height: 10),
              ...room.participants.map(
                (participant) => _ParticipantTile(
                  participant: participant,
                  isMe: participant.id == model.identity,
                  volume: model.volumeOf(participant.id),
                  onVolume: participant.id == model.identity
                      ? (value) => model.setReceiverVolume(participant.id, value)
                      : null,
                  onKick: emitter && participant.role == ParticipantRole.receiver
                      ? () => _confirmKick(participant)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              _TechnicalDetails(
                room: room,
                snapshot: model.synchronization,
                simulated: model.audio.isSimulated,
                offsetMs: model.clockOffsetMs,
                warning: [model.calibrationWarning, model.audioWarning].whereType<String>().join('\n'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _LeaveChoice { leave, close }

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code, required this.onCopy});
  final String code;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CÓDIGO DE LA SALA',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          letterSpacing: 2,
                          color: scheme.onPrimaryContainer,
                        ),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    code,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4,
                          color: scheme.onPrimaryContainer,
                        ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Copiar código',
              onPressed: onCopy,
              icon: const Icon(Icons.copy),
            ),
          ],
        ),
      ),
    );
  }
}

class _NowPlayingCard extends StatelessWidget {
  const _NowPlayingCard({
    required this.room,
    required this.emitter,
    required this.busy,
    required this.positionMs,
    required this.durationMs,
    required this.onPlay,
    required this.onPause,
    required this.onChangeTrack,
    required this.onDrag,
    required this.onSeekEnd,
    required this.onSeekBy,
    required this.onRestart,
  });
  final Room room;
  final bool emitter;
  final bool busy;
  final int positionMs;
  final int? durationMs;
  final Future<void> Function() onPlay;
  final Future<void> Function() onPause;
  final Future<void> Function()? onChangeTrack;
  final ValueChanged<double> onDrag;
  final Future<void> Function(double) onSeekEnd;
  final Future<void> Function(int) onSeekBy;
  final Future<void> Function() onRestart;

  static String _format(int ms) {
    final total = ms ~/ 1000;
    return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final playing = room.status == PlaybackStatus.playing;
    final title = room.trackVersion == 0
        ? 'Aún no hay canción'
        : (room.trackName ?? 'Canción sin título');
    final duration = durationMs;
    final hasDuration = duration != null && duration > 0;
    final canSeek = emitter && !busy && hasDuration;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(playing ? Icons.graphic_eq : Icons.music_note, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playing ? 'SONANDO' : 'DETENIDA',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: 1.5),
                      ),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (duration != null && hasDuration) ...[
              const SizedBox(height: 12),
              if (emitter)
                Slider(
                  value: positionMs.clamp(0, duration).toDouble(),
                  max: duration.toDouble(),
                  onChanged: busy ? null : onDrag,
                  onChangeEnd: busy ? null : onSeekEnd,
                )
              else
                LinearProgressIndicator(
                  value: (positionMs / duration).clamp(0.0, 1.0).toDouble(),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_format(positionMs), style: Theme.of(context).textTheme.bodySmall),
                  Text(_format(duration), style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
            if (emitter) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Atrasar 10 s',
                    onPressed: canSeek ? () => onSeekBy(-10000) : null,
                    icon: const Icon(Icons.replay_10),
                  ),
                  IconButton(
                    tooltip: 'Desde el inicio',
                    onPressed: canSeek ? onRestart : null,
                    icon: const Icon(Icons.skip_previous),
                  ),
                  IconButton(
                    tooltip: 'Adelantar 10 s',
                    onPressed: canSeek ? () => onSeekBy(10000) : null,
                    icon: const Icon(Icons.forward_10),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy || playing ? null : onPlay,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('INICIAR'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy || !playing ? null : onPause,
                      icon: const Icon(Icons.pause),
                      label: const Text('PAUSAR'),
                    ),
                  ),
                ],
              ),
              if (onChangeTrack != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: busy ? null : onChangeTrack,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Cambiar canción'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({required this.status, required this.loading, required this.onRetry});
  final TrackStatus status;
  final bool loading;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final (icon, text) = switch (status) {
      TrackStatus.downloading => (Icons.downloading, 'Descargando la pista…'),
      TrackStatus.ready => (Icons.check_circle_outline, 'Pista lista en este dispositivo'),
      TrackStatus.failed => (Icons.error_outline, 'No se pudo descargar la pista'),
      TrackStatus.none => (Icons.info_outline, ''),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon), const SizedBox(width: 12), Expanded(child: Text(text))]),
            if (status == TrackStatus.downloading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (status == TrackStatus.failed) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: loading ? null : onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('REINTENTAR'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({
    required this.participant,
    required this.isMe,
    required this.volume,
    this.onVolume,
    this.onKick,
  });
  final Participant participant;
  final bool isMe;
  final double volume;
  final ValueChanged<double>? onVolume;
  final VoidCallback? onKick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final emitter = participant.role == ParticipantRole.emitter;
    final initial = participant.id.isEmpty ? '?' : participant.id.substring(0, 1).toUpperCase();
    final role = emitter ? 'Emisor' : 'Receptor';
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  backgroundColor: emitter ? scheme.primary : scheme.secondaryContainer,
                  foregroundColor: emitter ? scheme.onPrimary : scheme.onSecondaryContainer,
                  child: Text(initial),
                ),
                if (!emitter)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: participant.connected ? Colors.green : Colors.grey,
                        border: Border.all(color: scheme.surface, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMe ? '${participant.id} (tú)' : participant.id,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    emitter
                        ? role
                        : (participant.connected ? '$role · conectado' : '$role · sin conexión'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (onVolume != null)
              SizedBox(width: 120, child: Slider(value: volume, onChanged: onVolume)),
            if (onKick != null)
              IconButton(
                tooltip: 'Expulsar',
                onPressed: onKick,
                icon: const Icon(Icons.person_remove_outlined),
              ),
          ],
        ),
      ),
    );
  }
}

class _TechnicalDetails extends StatelessWidget {
  const _TechnicalDetails({
    required this.room,
    required this.snapshot,
    required this.simulated,
    this.offsetMs,
    this.warning,
  });
  final Room room;
  final SyncSnapshot snapshot;
  final bool simulated;
  final double? offsetMs;
  final String? warning;

  @override
  Widget build(BuildContext context) {
    final hasWarning = warning != null && warning!.isNotEmpty;
    return Card(
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(hasWarning ? Icons.warning_amber : Icons.tune),
        title: const Text('Detalles técnicos'),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Estado: ${room.status.name}'),
          Text('Receptores conectados: ${room.connectedReceivers}'),
          Text('Reproducción: ${snapshot.playing ? 'activa' : 'en pausa'}'),
          Text('startAt: ${snapshot.startAt ?? 'pendiente'}'),
          Text('Posición: ${snapshot.positionMs} ms'),
          if (offsetMs != null) Text('Offset de reloj: ${offsetMs!.toStringAsFixed(1)} ms'),
          if (hasWarning)
            Text(warning!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 8),
          Text(simulated ? 'Audio: simulado' : 'Audio: activo'),
        ],
      ),
    );
  }
}
