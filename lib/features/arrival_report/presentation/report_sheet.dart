import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/clock.dart';
import '../../../core/utils/ist_time.dart';
import '../../prediction/domain/delay_predictor.dart';
import '../../rain_mode/presentation/rain_mode_providers.dart';
import '../../schedule/domain/network.dart';
import '../data/report_store.dart';
import '../domain/arrival_report.dart';

/// Reports are only accepted close to the scheduled time, to keep the data clean.
bool canReport(ScheduledArrival a, DateTime now) {
  final m = now.difference(a.scheduled).inMinutes;
  return m >= -30 && m <= 120;
}

/// Confirms and saves "this bus arrived now".
Future<void> showReportSheet(
  BuildContext context,
  WidgetRef ref, {
  required ScheduledArrival arrival,
  required Stop stop,
  required DelayPrediction prediction,
}) async {
  final now = ref.read(clockProvider)();
  final delay = now.difference(arrival.scheduled).inSeconds / 60;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Did ${arrival.route.short} just arrive?', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('At ${stop.desc}'),
            const SizedBox(height: 4),
            Text('Scheduled ${formatTime(arrival.scheduled)} · now ${formatTime(now)} '
                '(${formatDelay(delay)})'),
            Text('Model expected ${formatDelay(prediction.q50)}'),
            const SizedBox(height: 16),
            Text('Your report is stored on this phone and teaches the model about this route.',
                style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('confirm-arrived'),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Yes, it arrived'),
                ),
              ),
            ]),
          ],
        ),
      ),
    ),
  );
  if (ok != true) return;
  await ref.read(reportsProvider.notifier).add(ArrivalReport(
        tripKey: arrival.tripKey,
        routeShort: arrival.route.short,
        stopId: stop.id,
        stopName: stop.desc,
        scheduled: arrival.scheduled,
        reportedAt: now,
        rainMode: ref.read(rainModeProvider).value ?? false,
        features: prediction.features,
        predictedQ50: prediction.q50,
        predictedQ90: prediction.q90,
      ));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Thanks! ${arrival.route.short} was ${formatDelay(delay)}.'),
    ));
  }
}
