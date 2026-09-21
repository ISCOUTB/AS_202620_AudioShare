import 'package:flutter/material.dart';

import '../../data/repositories/room_repository.dart';
import '../viewmodels/session_view_model.dart';
import 'room_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({required this.repository, super.key});
  final RoomRepository repository;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final emitterController = TextEditingController(text: 'emitter-mobile');
  final roomController = TextEditingController();
  final receiverController = TextEditingController(text: 'receiver-mobile');
  String? error;
  bool loading = false;

  @override
  void dispose() {
    emitterController.dispose();
    roomController.dispose();
    receiverController.dispose();
    super.dispose();
  }

  Future<void> _open({required bool create}) async {
    setState(() { loading = true; error = null; });
    final viewModel = SessionViewModel(repository: widget.repository);
    if (create) {
      await viewModel.createRoom(emitterController.text.trim());
    } else {
      await viewModel.joinRoom(roomController.text.trim(), receiverController.text.trim());
    }
    if (!mounted) return;
    if (viewModel.error != null) {
      setState(() { loading = false; error = viewModel.error; });
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoomPage(viewModel: viewModel)));
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 30),
                  Text('AUDIOSHARE', style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 2, color: Theme.of(context).colorScheme.primary)),
                  const SizedBox(height: 12),
                  Text('Comparte el ritmo\nen tu red local.', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  const Text('Crea una sala como emisor o únete como receptor. El estado de reproducción se coordina mediante el backend AudioShare.'),
                  const SizedBox(height: 32),
                  if (error != null) _ErrorBanner(error!),
                  LayoutBuilder(builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 600;
                    final cards = [
                      _ActionCard(title: 'Crear sala', subtitle: 'Este dispositivo será el emisor.', controller: emitterController, label: 'Identificador del emisor', button: 'CREAR SALA', onPressed: loading ? null : () => _open(create: true)),
                      _ActionCard(title: 'Unirse a sala', subtitle: 'Conecta este dispositivo como receptor.', controller: roomController, label: 'Código de sala', secondaryController: receiverController, secondaryLabel: 'Identificador del receptor', button: 'UNIRSE', onPressed: loading ? null : () => _open(create: false)),
                    ];
                    return narrow ? Column(children: [cards[0], const SizedBox(height: 16), cards[1]]) : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: cards[0]), const SizedBox(width: 16), Expanded(child: cards[1])]);
                  }),
                  const SizedBox(height: 28),
                  const _StatusNote(),
                ],
              ),
            ),
          ),
        ),
      );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.title, required this.subtitle, required this.controller, required this.label, required this.button, required this.onPressed, this.secondaryController, this.secondaryLabel});
  final String title, subtitle, label, button;
  final TextEditingController controller;
  final TextEditingController? secondaryController;
  final String? secondaryLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 6), Text(subtitle), const SizedBox(height: 20), TextField(controller: controller, decoration: InputDecoration(labelText: label)), if (secondaryController != null) ...[const SizedBox(height: 12), TextField(controller: secondaryController, decoration: InputDecoration(labelText: secondaryLabel))], const SizedBox(height: 18), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: onPressed, icon: const Icon(Icons.arrow_forward), label: Text(button)))])));
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)));
}

class _StatusNote extends StatelessWidget {
  const _StatusNote();
  @override
  Widget build(BuildContext context) => const Card(child: Padding(padding: EdgeInsets.all(18), child: Row(children: [Icon(Icons.info_outline), SizedBox(width: 12), Expanded(child: Text('El transporte de audio físico está preparado como abstracción, pero continúa simulado en este corte A-01.'))])));
}
