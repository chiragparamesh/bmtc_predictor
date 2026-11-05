import 'dart:math' as math;

import '../../../core/utils/ist_time.dart';
import '../../schedule/domain/network.dart';

/// Builds the model input. MUST match `features()` in ml/train_delay_model.py:
/// hour_sin, hour_cos, is_weekend, trip_progress, sched_min_from_start/120,
/// corridor_orr, corridor_silk_board, corridor_majestic, corridor_airport,
/// is_vajra, rain_mmh/10 (capped at 30 mm/h).
List<double> delayFeatures(ScheduledArrival a, {required double rainMmh}) {
  final hour = hourOfDay(a.scheduled);
  final c = a.route.corridors;
  double flag(bool v) => v ? 1 : 0;
  return [
    math.sin(2 * math.pi * hour / 24),
    math.cos(2 * math.pi * hour / 24),
    flag(isWeekend(a.scheduled)),
    a.progress,
    a.minutesFromStart / 120,
    flag(c.contains('orr')),
    flag(c.contains('silk_board')),
    flag(c.contains('majestic')),
    flag(c.contains('airport')),
    flag(a.route.vajra),
    math.min(rainMmh, 30) / 10,
  ];
}
