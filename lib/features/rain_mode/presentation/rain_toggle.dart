import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'rain_mode_providers.dart';

/// Card switch: "Raining now?" Predictions update instantly.
class RainToggleCard extends ConsumerWidget {
  const RainToggleCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(rainModeProvider).value ?? false;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: on ? const Color(0xFFE3F2FD) : null,
      child: SwitchListTile(
        key: const Key('rain-toggle'),
        secondary: Icon(on ? Icons.thunderstorm : Icons.wb_cloudy_outlined,
            color: on ? const Color(0xFF1565C0) : scheme.outline),
        title: const Text('Rain mode'),
        subtitle: Text(on ? 'Predicting for heavy rain' : 'Turn on when it is raining'),
        value: on,
        onChanged: (v) => ref.read(rainModeProvider.notifier).set(v),
      ),
    );
  }
}

/// Small app-bar indicator + toggle.
class RainIconButton extends ConsumerWidget {
  const RainIconButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(rainModeProvider).value ?? false;
    return IconButton(
      tooltip: on ? 'Rain mode on' : 'Rain mode off',
      isSelected: on,
      icon: const Icon(Icons.wb_cloudy_outlined),
      selectedIcon: const Icon(Icons.thunderstorm, color: Color(0xFF1565C0)),
      onPressed: () => ref.read(rainModeProvider.notifier).toggle(),
    );
  }
}
