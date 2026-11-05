import '../../arrival_report/domain/arrival_report.dart';
import '../../schedule/domain/network.dart';
import 'delay_features.dart';
import 'delay_model.dart';

/// Predicted delay for one scheduled arrival.
class DelayPrediction {
  const DelayPrediction({
    required this.q50,
    required this.q90,
    required this.features,
    this.correctionMin = 0,
    this.reportsUsed = 0,
  });

  /// Median delay in minutes (half the buses are later than this).
  final double q50;

  /// 90% of buses arrive within this delay.
  final double q90;
  final List<double> features;

  /// Shift applied from the rider's own reports on this route.
  final double correctionMin;
  final int reportsUsed;

  DateTime expected(DateTime scheduled) => scheduled.add(_mins(q50));
  DateTime latest(DateTime scheduled) => scheduled.add(_mins(q90));

  static Duration _mins(double m) => Duration(seconds: (m * 60).round());
}

abstract class DelayPredictor {
  DelayPrediction predict(ScheduledArrival arrival, {required double rainMmh});
}

/// Model prediction, nudged by the rider's own "bus arrived" reports.
///
/// Per route: correction = mean(actual - predicted) x n / (n + k). With few
/// reports the shift stays small (shrinkage); with many it trusts the data.
/// This is on-device learning until the next Colab retrain.
class ModelDelayPredictor implements DelayPredictor {
  ModelDelayPredictor(this.model, {List<ArrivalReport> reports = const [], this.shrinkK = 3})
      : _corrections = _buildCorrections(reports, shrinkK);

  final DelayModel model;
  final double shrinkK;
  final Map<String, (double, int)> _corrections;

  static Map<String, (double, int)> _buildCorrections(List<ArrivalReport> reports, double k) {
    final byRoute = <String, List<double>>{};
    for (final r in reports) {
      byRoute.putIfAbsent(r.routeShort, () => []).add(r.errorMin);
    }
    return {
      for (final e in byRoute.entries)
        e.key: (
          e.value.reduce((a, b) => a + b) / e.value.length * e.value.length / (e.value.length + k),
          e.value.length,
        ),
    };
  }

  @override
  DelayPrediction predict(ScheduledArrival arrival, {required double rainMmh}) {
    final x = delayFeatures(arrival, rainMmh: rainMmh);
    final (q50, q90) = model.predict(x);
    final (shift, n) = _corrections[arrival.route.short] ?? (0.0, 0);
    return DelayPrediction(
      q50: q50 + shift,
      q90: q90 + shift,
      features: x,
      correctionMin: shift,
      reportsUsed: n,
    );
  }
}
