import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/clock.dart';
import '../../../core/services/settings.dart';
import '../../../core/utils/ist_time.dart';
import '../../../core/widgets/bus_widgets.dart';
import '../../arrival_report/presentation/report_sheet.dart';
import '../../prediction/presentation/predictor_provider.dart';
import '../../rain_mode/presentation/rain_mode_providers.dart';
import '../../rain_mode/presentation/rain_toggle.dart';
import '../data/network_repository.dart';
import '../domain/network.dart';

class TripArgs {
  const TripArgs({required this.arrival, required this.stopId});

  final ScheduledArrival arrival;
  final String stopId;
}

/// Stop-by-stop timeline of one bus: scheduled vs expected, delay building up.
class TripScreen extends ConsumerWidget {
  const TripScreen({super.key, required this.args});

  final TripArgs? args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final network = ref.watch(networkProvider).value;
    final predictor = ref.watch(predictorProvider).value;
    final kannada = ref.watch(kannadaNamesProvider).value ?? false;
    final rain = ref.watch(rainMmhProvider);
    final now = ref.watch(clockProvider)();
    final theme = Theme.of(context);
    final a = args?.arrival;

    if (a == null || network == null || predictor == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: a == null ? const Text('Open a bus from a stop.') : const CircularProgressIndicator()),
      );
    }
    final full = network.tripTimeline(a);
    final firstShown = (a.stopIndex - 2).clamp(0, full.length - 1);
    final timeline = full.sublist(firstShown);
    final mine = network.stops[args!.stopId]!;
    final myPrediction = predictor.predict(a, rainMmh: rain);

    return Scaffold(
      appBar: AppBar(title: Text('${a.route.short} to ${a.pattern.headsign}'), actions: const [RainIconButton()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Row(children: [
            RouteBadge(route: a.route),
            const SizedBox(width: 12),
            Expanded(child: Text(a.route.long, style: theme.textTheme.bodyMedium)),
          ]),
          const SizedBox(height: 12),
          if (firstShown > 0)
            Padding(
              padding: const EdgeInsets.only(left: 32, bottom: 4),
              child: Text('$firstShown earlier stop${firstShown == 1 ? '' : 's'} from ${a.route.long.split(' ⇔ ').first}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
            ),
          for (final s in timeline)
            _TimelineRow(
              stop: network.stops[s.stopId]!,
              scheduled: s.scheduled,
              expected: predictor.predict(s, rainMmh: rain).expected(s.scheduled),
              delay: predictor.predict(s, rainMmh: rain).q50,
              isMine: s.stopIndex == a.stopIndex,
              isPast: s.stopIndex < a.stopIndex,
              isFirst: s.stopIndex == firstShown,
              isLast: s.stopIndex == full.length - 1,
              kannada: kannada,
            ),
        ],
      ),
      bottomNavigationBar: canReport(a, now)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  key: const Key('trip-arrived'),
                  onPressed: () => showReportSheet(context, ref, arrival: a, stop: mine, prediction: myPrediction),
                  icon: const Icon(Icons.where_to_vote),
                  label: Text('Bus arrived at ${mine.name}'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                ),
              ),
            )
          : null,
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.stop,
    required this.scheduled,
    required this.expected,
    required this.delay,
    required this.isMine,
    required this.isPast,
    required this.isFirst,
    required this.isLast,
    required this.kannada,
  });

  final Stop stop;
  final DateTime scheduled;
  final DateTime expected;
  final double delay;
  final bool isMine;
  final bool isPast;
  final bool isFirst;
  final bool isLast;
  final bool kannada;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dot = isMine ? scheme.primary : (isPast ? scheme.outlineVariant : DelayChip.colorFor(delay));
    final muted = isPast ? scheme.outline : null;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(children: [
              Expanded(child: Container(width: 2, color: isFirst ? Colors.transparent : scheme.outlineVariant)),
              Container(
                width: isMine ? 16 : 10,
                height: isMine ? 16 : 10,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              Expanded(child: Container(width: 2, color: isLast ? Colors.transparent : scheme.outlineVariant)),
            ]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: isMine
                  ? BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(12))
                  : null,
              child: Row(children: [
                Expanded(
                  child: Text(stop.display(kannada: kannada),
                      style: (isMine ? theme.textTheme.titleSmall : theme.textTheme.bodyMedium)?.copyWith(color: muted)),
                ),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(formatTime(expected),
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: muted)),
                  Text('sched ${formatTime(scheduled)}', style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline)),
                ]),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
