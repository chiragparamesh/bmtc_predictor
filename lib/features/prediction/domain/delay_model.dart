import 'dart:math' as math;

/// The Colab-trained MLP (ml/train_delay_model.py), evaluated in plain Dart so
/// it runs on Android and in the Chrome preview without a TFLite plugin.
///
/// Layers: Dense+ReLU, Dense+ReLU, Dense(2). Head: q50 = out0,
/// q90 = out0 + softplus(out1), so the 90% bound is never below the median.
class DelayModel {
  DelayModel({
    required this.name,
    required this.version,
    required this.trainedOn,
    required this.features,
    required this.layers,
    required this.metrics,
  });

  final String name;
  final String version;
  final String trainedOn;
  final List<String> features;
  final List<DenseLayer> layers;
  final Map<String, num> metrics;

  /// True while the model has seen no real rider reports.
  bool get isPriorOnly => (metrics['real_reports_used'] ?? 0) == 0;

  factory DelayModel.fromJson(Map<String, dynamic> j) => DelayModel(
        name: j['name'] as String,
        version: j['version'] as String,
        trainedOn: j['trainedOn'] as String,
        features: [for (final f in j['features'] as List) f as String],
        layers: [for (final l in j['layers'] as List) DenseLayer.fromJson(l as Map<String, dynamic>)],
        metrics: {
          for (final e in (j['metrics'] as Map<String, dynamic>).entries) e.key: e.value as num,
        },
      );

  /// Returns (q50, q90) delay in minutes.
  (double, double) predict(List<double> x) {
    if (x.length != features.length) {
      throw ArgumentError('expected ${features.length} features, got ${x.length}');
    }
    var h = x;
    for (final layer in layers) {
      h = layer.apply(h);
    }
    return (h[0], h[0] + softplus(h[1]));
  }

  static double softplus(double x) => math.log(1 + math.exp(-x.abs())) + math.max(x, 0);
}

class DenseLayer {
  DenseLayer(this.w, this.b, this.relu);

  /// w[input][output], as exported from numpy.
  final List<List<double>> w;
  final List<double> b;
  final bool relu;

  factory DenseLayer.fromJson(Map<String, dynamic> j) => DenseLayer(
        [
          for (final row in j['w'] as List) [for (final v in row as List) (v as num).toDouble()],
        ],
        [for (final v in j['b'] as List) (v as num).toDouble()],
        j['activation'] == 'relu',
      );

  List<double> apply(List<double> x) {
    final out = List<double>.of(b);
    for (var i = 0; i < x.length; i++) {
      final xi = x[i];
      if (xi == 0) continue;
      final row = w[i];
      for (var j = 0; j < out.length; j++) {
        out[j] += xi * row[j];
      }
    }
    if (relu) {
      for (var j = 0; j < out.length; j++) {
        if (out[j] < 0) out[j] = 0;
      }
    }
    return out;
  }
}
