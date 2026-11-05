import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/services/clock.dart';
import '../../../core/services/settings.dart';
import '../../../core/utils/ist_time.dart';
import '../../../core/widgets/bus_widgets.dart';
import '../../arrival_report/data/report_store.dart';
import '../../arrival_report/presentation/report_sheet.dart';
import '../../prediction/domain/delay_predictor.dart';
import '../../prediction/presentation/predictor_provider.dart';
import '../../rain_mode/presentation/rain_mode_providers.dart';
import '../../rain_mode/presentation/rain_toggle.dart';
import '../data/network_repository.dart';
import '../domain/network.dart';
import 'trip_screen.dart';

/// Upcoming buses at one stop with scheduled, expected and "90% by" times.
class StopScreen extends ConsumerStatefulWidget {
  const StopScreen({super.key, required this.stopId});

  final String stopId;

  @override
  ConsumerState<StopScreen> createState() => _StopScreenState();
}

class _StopScreenState extends ConsumerState<StopScreen> {
  /// Null = live ("now"); otherwise a planned IST time.
  DateTime? _planned;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_planned == null && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final now = ref.read(clockProvider)();
    final base = _planned ?? now;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: base.hour, minute: base.minute),
      helpText: 'Plan for (Bengaluru time)',
    );
    if (t == null) return;
    var planned = DateTime.utc(now.year, now.month, now.day, t.hour, t.minute);
    if (planned.isBefore(now.subtract(const Duration(minutes: 30)))) {
      planned = planned.add(const Duration(days: 1)); // e.g. "8 am" picked at night = tomorrow
    }
    setState(() => _planned = planned);
  }

  @override
  Widget build(BuildContext context) {
    final network = ref.watch(networkProvider).value;
    final predictor = ref.watch(predictorProvider);
    final kannada = ref.watch(kannadaNamesProvider).value ?? false;
    final rain = ref.watch(rainMmhProvider);
    final now = ref.watch(clockProvider)();
    final theme = Theme.of(context);

    final stop = network?.stops[widget.stopId];
    if (network == null || stop == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: network == null ? const CircularProgressIndicator() : const Text('Stop not found')),
      );
    }

    final from = _planned ?? now;
    final arrivals = network.arrivalsAt(stop.id, from);
    final live = _planned == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(stop.name),
        actions: const [RainIconButton()],
      ),
      body: predictor.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Model error: $e')),
        data: (p) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(stop.display(kannada: kannada), style: theme.textTheme.titleMedium),
            if (!kannada && stop.kn.isNotEmpty)
              Text(stop.kn, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text('Now · ${formatTime(now)}'),
                  selected: live,
                  onSelected: (_) => setState(() => _planned = null),
                ),
                ChoiceChip(
                  key: const Key('plan-time'),
                  avatar: const Icon(Icons.schedule, size: 18),
                  label: Text(live ? 'Plan for later' : 'At ${formatTime(_planned!)}'),
                  selected: !live,
                  onSelected: (_) => _pickTime(),
                ),
                if (rain > 0)
                  const Chip(avatar: Icon(Icons.thunderstorm, size: 18), label: Text('Rain mode')),
              ],
            ),
            const SizedBox(height: 12),
            if (arrivals.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.nights_stay_outlined),
                  title: Text('No buses in the next 2 hours'),
                  subtitle: Text('Use "Plan for later" to see another time.'),
                ),
              ),
            for (final a in arrivals)
              _ArrivalCard(
                arrival: a,
                stop: stop,
                prediction: p.predict(a, rainMmh: rain),
                now: now,
                live: live,
              ),
            const SizedBox(height: 8),
            Text(
              'Expected = schedule + predicted delay. "90% by" = 9 in 10 buses arrive before this time.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArrivalCard extends ConsumerWidget {
  const _ArrivalCard({
    required this.arrival,
    required this.stop,
    required this.prediction,
    required this.now,
    required this.live,
  });

  final ScheduledArrival arrival;
  final Stop stop;
  final DelayPrediction prediction;
  final DateTime now;
  final bool live;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final a = arrival;
    final expected = prediction.expected(a.scheduled);
    final reported = (ref.watch(reportsProvider).value ?? const [])
        .any((r) => r.tripKey == a.tripKey && r.stopId == stop.id);
    return Card(
      key: ValueKey('arrival-${a.tripKey}'),
      child: InkWell(
        onTap: () => context.push(AppRoutes.trip, extra: TripArgs(arrival: a, stopId: stop.id)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RouteBadge(route: a.route),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('to ${a.pattern.headsign}', style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('Expected ${formatTime(expected)}'
                        '${live ? ' (${formatRelative(expected, now)})' : ''}',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    Text('Scheduled ${formatTime(a.scheduled)} · 90% by ${formatTime(prediction.latest(a.scheduled))}',
                        style: theme.textTheme.bodySmall),
                    if (prediction.reportsUsed > 0)
                      Text('Adjusted with your ${prediction.reportsUsed} report${prediction.reportsUsed == 1 ? '' : 's'}',
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  DelayChip(minutes: prediction.q50),
                  const SizedBox(height: 6),
                  if (reported)
                    const Icon(Icons.check_circle, color: Color(0xFF2E7D32))
                  else if (live && canReport(a, now))
                    TextButton(
                      key: ValueKey('arrived-${a.tripKey}'),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () => showReportSheet(context, ref,
                          arrival: a, stop: stop, prediction: prediction),
                      child: const Text('Arrived'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
