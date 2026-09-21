import 'package:flutter/material.dart';

import '../../data/models/room.dart';
import '../viewmodels/session_view_model.dart';

class RoomPage extends StatefulWidget {
  const RoomPage({required this.viewModel, super.key});
  final SessionViewModel viewModel;

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_changed);
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_changed);
    widget.viewModel.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final model = widget.viewModel;
    final room = model.room;
    if (room == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final emitter = room.participants.any((p) => p.role == ParticipantRole.emitter && p.id == model.identity);
    return Scaffold(appBar: AppBar(title: const Text('Sala AudioShare')), body: RefreshIndicator(onRefresh: model.refresh, child: ListView(padding: const EdgeInsets.all(20), children: [
      Text('SALA', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary, letterSpacing: 2)),
      const SizedBox(height: 8),
      SelectableText(room.id, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 18),
      _StateCard(room: room),
      const SizedBox(height: 16),
      if (model.error != null) Text(model.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      if (emitter) Row(children: [Expanded(child: FilledButton.icon(onPressed: model.loading || room.status == PlaybackStatus.playing ? null : model.play, icon: const Icon(Icons.play_arrow), label: const Text('INICIAR'))), const SizedBox(width: 12), Expanded(child: OutlinedButton.icon(onPressed: model.loading || room.status != PlaybackStatus.playing ? null : model.pause, icon: const Icon(Icons.pause), label: const Text('PAUSAR')))]),
      const SizedBox(height: 22),
      Text('PARTICIPANTES (${room.participants.length})', style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 1)),
      const SizedBox(height: 10),
      ...room.participants.map((participant) => _ParticipantTile(participant: participant, onVolume: participant.role == ParticipantRole.receiver ? (value) => model.setReceiverVolume(participant.id, value) : null)),
      const SizedBox(height: 22),
      _SyncCard(snapshot: model.synchronization, simulated: model.audio.isSimulated),
    ])));
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.room});
  final Room room;

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Wrap(
            spacing: 28,
            runSpacing: 14,
            children: [
              Text(
                'Estado\n${room.status.name.toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Receptores conectados\n${room.connectedReceivers}'),
              Text('startAt\n${room.startAt ?? 'pendiente'}'),
            ],
          ),
        ),
      );
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({required this.participant, this.onVolume});
  final Participant participant;
  final ValueChanged<double>? onVolume;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), child: Row(children: [Icon(participant.role == ParticipantRole.emitter ? Icons.volume_up : Icons.headphones), const SizedBox(width: 12), Expanded(child: Text('${participant.id}\n${participant.role.name}')), if (onVolume != null) SizedBox(width: 120, child: Slider(value: .8, onChanged: onVolume))])));
}

class _SyncCard extends StatelessWidget {
  const _SyncCard({required this.snapshot, required this.simulated});
  final dynamic snapshot;
  final bool simulated;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('SINCRONIZACIÓN', style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 1)), const SizedBox(height: 12), Text('Reproducción: ${snapshot.playing ? 'activa' : 'en pausa'}'), Text('startAt: ${snapshot.startAt ?? 'pendiente'}'), Text('Posición: ${snapshot.positionMs} ms'), const SizedBox(height: 8), Text(simulated ? 'Audio: simulado, listo para sustituir por captura y reproducción real.' : 'Audio: activo')])));
}
