import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/services/settings.dart';
import '../../../core/utils/app_constants.dart';
import '../../arrival_report/data/report_store.dart';
import '../../rain_mode/presentation/rain_toggle.dart';
import '../../schedule/data/network_repository.dart';
import '../../schedule/domain/network.dart';
import '../data/recent_stops.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _search = TextEditingController();

  static const popular = [
    'Central Silk Board',
    'Kempegowda Bus Station',
    'Hebbala',
    'Marathahalli',
    'Banashankari Bus Station',
    'Electronic City',
    'Kempegowda International Airport',
    'BTM Layout',
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(Stop s) {
    ref.read(recentStopsProvider.notifier).visit(s.id);
    context.push(AppRoutes.stop(s.id));
  }

  @override
  Widget build(BuildContext context) {
    final network = ref.watch(networkProvider);
    final kannada = ref.watch(kannadaNamesProvider).value ?? false;
    final reports = ref.watch(reportsProvider).value?.length ?? 0;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          TextButton(
            key: const Key('lang-toggle'),
            onPressed: () => ref.read(kannadaNamesProvider.notifier).toggle(),
            child: Text(kannada ? 'EN' : 'ಕನ್ನಡ'),
          ),
          IconButton(
            tooltip: 'Your reports',
            onPressed: () => context.push(AppRoutes.reports),
            icon: Badge(
              isLabelVisible: reports > 0,
              label: Text('$reports'),
              child: const Icon(Icons.fact_check_outlined),
            ),
          ),
        ],
      ),
      body: network.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load the timetable: $e')),
        data: (net) {
          final q = _search.text;
          final results = net.searchStops(q);
          final recent = [
            for (final id in ref.watch(recentStopsProvider).value ?? const <String>[])
              if (net.stops[id] != null) net.stops[id]!,
          ];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(AppConstants.tagline,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                key: const Key('stop-search'),
                controller: _search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search your stop (English or ಕನ್ನಡ)',
                  suffixIcon: q.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(_search.clear),
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              if (q.isNotEmpty) ...[
                if (results.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No stop found on the bundled routes.', textAlign: TextAlign.center),
                  ),
                for (final s in results) _StopTile(stop: s, network: net, kannada: kannada, onTap: () => _open(s)),
              ] else ...[
                const RainToggleCard(),
                if (recent.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Recent', style: theme.textTheme.titleMedium),
                  for (final s in recent)
                    _StopTile(stop: s, network: net, kannada: kannada, onTap: () => _open(s)),
                ],
                const SizedBox(height: 12),
                Text('Popular stops', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final name in popular)
                      if (net.searchStops(name).isNotEmpty)
                        ActionChip(
                          avatar: const Icon(Icons.place_outlined, size: 18),
                          label: Text(name),
                          onPressed: () => _open(net.searchStops(name).first),
                        ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  '${net.routes.length} busy routes (Silk Board, ORR, Majestic, airport) · '
                  '${net.stops.length} stops · BMTC timetable ${net.feedVersion}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _StopTile extends StatelessWidget {
  const _StopTile({required this.stop, required this.network, required this.kannada, required this.onTap});

  final Stop stop;
  final Network network;
  final bool kannada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final routes = network.routesAt(stop.id);
    return Card(
      child: ListTile(
        key: ValueKey('stop-${stop.id}'),
        leading: const Icon(Icons.directions_bus_outlined),
        title: Text(stop.display(kannada: kannada)),
        subtitle: Text(
          [if (kannada) stop.desc else if (stop.kn.isNotEmpty) stop.kn, routes.join(' · ')]
              .where((s) => s.isNotEmpty)
              .join('\n'),
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
