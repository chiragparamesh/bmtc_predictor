/// A rider's "bus arrived" report: the ground truth the model learns from.
class ArrivalReport {
  const ArrivalReport({
    required this.tripKey,
    required this.routeShort,
    required this.stopId,
    required this.stopName,
    required this.scheduled,
    required this.reportedAt,
    required this.rainMode,
    required this.features,
    required this.predictedQ50,
    required this.predictedQ90,
  });

  final String tripKey;
  final String routeShort;
  final String stopId;
  final String stopName;

  /// IST wall-clock times (see core/utils/ist_time.dart).
  final DateTime scheduled;
  final DateTime reportedAt;
  final bool rainMode;

  /// Model input at report time, so Colab can retrain without re-deriving it.
  final List<double> features;
  final double predictedQ50;
  final double predictedQ90;

  /// Actual delay in minutes (positive = late).
  double get delayMin => reportedAt.difference(scheduled).inSeconds / 60;

  /// Model error for this bus (actual - predicted median).
  double get errorMin => delayMin - predictedQ50;
  bool get withinQ90 => delayMin <= predictedQ90;

  Map<String, dynamic> toJson() => {
        'tripKey': tripKey,
        'route': routeShort,
        'stopId': stopId,
        'stopName': stopName,
        'scheduled': scheduled.toIso8601String(),
        'reportedAt': reportedAt.toIso8601String(),
        'rain': rainMode,
        'features': features,
        'q50': predictedQ50,
        'q90': predictedQ90,
      };

  factory ArrivalReport.fromJson(Map<String, dynamic> j) => ArrivalReport(
        tripKey: j['tripKey'] as String,
        routeShort: j['route'] as String,
        stopId: j['stopId'] as String,
        stopName: j['stopName'] as String,
        scheduled: DateTime.parse(j['scheduled'] as String),
        reportedAt: DateTime.parse(j['reportedAt'] as String),
        rainMode: j['rain'] as bool,
        features: [for (final f in j['features'] as List) (f as num).toDouble()],
        predictedQ50: (j['q50'] as num).toDouble(),
        predictedQ90: (j['q90'] as num).toDouble(),
      );
}

/// CSV for ml/train_delay_model.py --reports: f0..fN feature columns + delay_min.
String reportsToCsv(List<ArrivalReport> reports) {
  if (reports.isEmpty) return '';
  final n = reports.first.features.length;
  final header = [
    for (var i = 0; i < n; i++) 'f$i',
    'delay_min', 'route', 'stop_id', 'scheduled_ist', 'reported_ist', 'rain_mode', 'pred_q50', 'pred_q90',
  ];
  String esc(String s) => s.contains(',') ? '"${s.replaceAll('"', '""')}"' : s;
  final rows = [
    for (final r in reports)
      [
        for (final f in r.features) f.toStringAsFixed(6),
        r.delayMin.toStringAsFixed(2),
        esc(r.routeShort),
        r.stopId,
        r.scheduled.toIso8601String(),
        r.reportedAt.toIso8601String(),
        r.rainMode ? '1' : '0',
        r.predictedQ50.toStringAsFixed(2),
        r.predictedQ90.toStringAsFixed(2),
      ].join(','),
  ];
  return '${header.join(',')}\n${rows.join('\n')}\n';
}
