import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/app_links.dart';
import '../../../live/domain/live_audio_engine.dart';
import '../viewmodels/session_view_model.dart';

/// Panel de la transmisión en vivo de la sala (ADR-0015): el emisor elige qué
/// audio compartir y los receptores ven qué está sonando.
class LiveCard extends StatelessWidget {
  const LiveCard({required this.model, super.key});

  final SessionViewModel model;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: model.isEmitter ? _EmitterPanel(model: model) : _ReceiverPanel(model: model),
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle, required this.live});

  final String title;
  final String subtitle;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(live ? Icons.graphic_eq : Icons.podcasts, size: 32, color: live ? scheme.primary : null),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: 1.5),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmitterPanel extends StatefulWidget {
  const _EmitterPanel({required this.model});

  final SessionViewModel model;

  @override
  State<_EmitterPanel> createState() => _EmitterPanelState();
}

class _EmitterPanelState extends State<_EmitterPanel> {
  CaptureSource? _selected;

  CaptureOption? _optionFor(CaptureSource source) {
    for (final option in widget.model.captureOptions) {
      if (option.source == source) return option;
    }
    return null;
  }

  /// Lo elegido, o la primera opción disponible mientras no se elija nada.
  CaptureSource? get _effective {
    final chosen = _selected;
    if (chosen != null && (_optionFor(chosen)?.available ?? false)) return chosen;
    for (final option in widget.model.captureOptions) {
      if (option.available) return option.source;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final scheme = Theme.of(context).colorScheme;
    if (model.isSharing) return _sharing(context, model, scheme);

    final options = model.captureOptions;
    final selected = _effective;
    if (_isPhoneBrowser && options.isNotEmpty && options.every((o) => !o.available)) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            title: 'TRANSMISIÓN EN VIVO',
            subtitle: 'Desde aquí solo puedes escuchar',
            live: false,
          ),
          SizedBox(height: 12),
          _PhoneBrowserNotice(),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Header(
          title: 'TRANSMISIÓN EN VIVO',
          subtitle: 'Elige qué audio compartir',
          live: false,
        ),
        const SizedBox(height: 12),
        if (options.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Expanded(child: Text('Comprobando qué puede compartir este dispositivo…')),
              ],
            ),
          )
        else
          for (final option in options) ...[
            _SourceTile(
              option: option,
              selected: option.source == selected,
              onTap: option.available ? () => setState(() => _selected = option.source) : null,
            ),
            const SizedBox(height: 8),
          ],
        if (selected != null) ...[
          const SizedBox(height: 4),
          Text(kIsWeb ? selected.browserHint : selected.nativeHint, style: Theme.of(context).textTheme.bodySmall),
        ],
        if (model.liveMessage != null) ...[
          const SizedBox(height: 12),
          Text(model.liveMessage!, style: TextStyle(color: scheme.error)),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const Key('empezar-compartir'),
            onPressed: selected == null || model.loading ? null : () => model.startSharing(selected),
            icon: const Icon(Icons.cast),
            label: const Text('EMPEZAR A COMPARTIR'),
          ),
        ),
      ],
    );
  }

  Widget _sharing(BuildContext context, SessionViewModel model, ColorScheme scheme) {
    final source = model.liveSource;
    final reconnecting = model.liveState == LiveLinkState.reconnecting;
    final connecting = model.liveState == LiveLinkState.connecting;
    final stats = model.liveStats;
    final status = connecting
        ? (kIsWeb ? 'Esperando el permiso del navegador…' : 'Esperando tu permiso…')
        : reconnecting
            ? 'Se perdió la conexión; reconectando…'
            : 'EN VIVO · ${source?.title ?? 'Audio'}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          title: 'TRANSMISIÓN EN VIVO',
          subtitle: status,
          live: !connecting && !reconnecting,
        ),
        if (stats?.sent != null) ...[
          const SizedBox(height: 8),
          Text(
            'Paquetes enviados: ${stats!.sent}'
            '${(stats.dropped ?? 0) > 0 ? ' · descartados: ${stats.dropped}' : ''}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Los receptores oyen lo que suena en ${source == CaptureSource.tab ? 'esa pestaña' : 'lo que elegiste'}. '
          'Si sales de esta pantalla, la transmisión se detiene.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('dejar-compartir'),
            onPressed: model.stopSharing,
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('DEJAR DE COMPARTIR'),
          ),
        ),
      ],
    );
  }
}

/// Navegador de un celular o tableta: ahí no se puede capturar audio, así que
/// en lugar de varias opciones bloqueadas se explica qué hacer.
bool get _isPhoneBrowser =>
    kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

class _PhoneBrowserNotice extends StatelessWidget {
  const _PhoneBrowserNotice();

  Future<void> _openApp(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (androidAppUrl.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('El enlace de descarga todavía no está disponible.')),
      );
      return;
    }
    final opened = await launchUrl(Uri.parse(androidAppUrl), mode: LaunchMode.externalApplication);
    if (!opened) {
      messenger.showSnackBar(const SnackBar(content: Text('No se pudo abrir el enlace.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final android = defaultTargetPlatform == TargetPlatform.android;
    return Container(
      key: const Key('aviso-navegador-telefono'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Los navegadores del teléfono no pueden capturar audio',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            android
                ? 'Para transmitir desde este celular usa la app de Android. '
                    'También puedes abrir AudioShare en un computador con Chrome o Edge.'
                : 'Para transmitir, abre AudioShare en un computador con Chrome o Edge.',
          ),
          if (android) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('descargar-app-android'),
                onPressed: () => _openApp(context),
                icon: const Icon(Icons.android),
                label: const Text('DESCARGAR LA APP DE ANDROID'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.option, required this.selected, required this.onTap});

  final CaptureOption option;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = option.available;
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: Key('origen-${option.source.name}'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                !enabled
                    ? Icons.block
                    : selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                color: enabled ? scheme.primary : scheme.outline,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.source.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: enabled ? null : scheme.outline,
                      ),
                    ),
                    Text(
                      enabled ? option.source.description : (option.reason ?? 'No disponible.'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: enabled ? null : scheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiverPanel extends StatelessWidget {
  const _ReceiverPanel({required this.model});

  final SessionViewModel model;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = model.liveState;
    final source = model.liveSource;
    final playing = state == LiveLinkState.playing;
    final String subtitle;
    if (state == LiveLinkState.error) {
      subtitle = 'No se puede reproducir';
    } else if (state == LiveLinkState.blocked) {
      subtitle = 'El navegador bloqueó el audio';
    } else if (model.broadcasting) {
      subtitle = playing ? 'Escuchando: ${source?.title ?? 'audio en vivo'}' : 'Conectando con el audio…';
    } else if (state == LiveLinkState.reconnecting) {
      subtitle = 'Reconectando…';
    } else if (state == LiveLinkState.connecting) {
      subtitle = 'Conectando…';
    } else {
      subtitle = 'Esperando al emisor';
    }
    final latency = model.liveStats?.latencyMs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(title: 'TRANSMISIÓN EN VIVO', subtitle: subtitle, live: playing),
        if (!model.broadcasting && state != LiveLinkState.error && state != LiveLinkState.blocked) ...[
          const SizedBox(height: 8),
          const Text('Cuando el emisor comparta audio, empezará a sonar aquí.'),
        ],
        if (playing && latency != null) ...[
          const SizedBox(height: 8),
          Text('Retardo de reproducción: $latency ms', style: Theme.of(context).textTheme.bodySmall),
        ],
        if (model.liveMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            model.liveMessage!,
            style: TextStyle(color: state == LiveLinkState.error ? scheme.error : null),
          ),
        ],
        if (state == LiveLinkState.blocked) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('activar-audio'),
              onPressed: model.unlockAudio,
              icon: const Icon(Icons.volume_up),
              label: const Text('ACTIVAR AUDIO'),
            ),
          ),
        ],
      ],
    );
  }
}
