import 'package:flutter/material.dart';

import '../utils/app_constants.dart';

/// Temporary landing screen shown until the real features are built.
class SkeletonHome extends StatelessWidget {
  const SkeletonHome({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.appName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(AppConstants.tagline, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Project skeleton. These modules are planned:',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          for (final m in AppConstants.modules)
            Card(
              child: ListTile(
                title: Text(m.title),
                subtitle: Text(m.description),
                trailing: const Chip(label: Text('Planned')),
              ),
            ),
        ],
      ),
    );
  }
}
