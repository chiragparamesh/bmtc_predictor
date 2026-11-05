import 'dart:convert';
import 'dart:io';

import 'package:bmtc_predictor/core/utils/ist_time.dart';
import 'package:bmtc_predictor/features/arrival_report/domain/arrival_report.dart';
import 'package:bmtc_predictor/features/prediction/domain/delay_features.dart';
import 'package:bmtc_predictor/features/prediction/domain/delay_model.dart';
import 'package:bmtc_predictor/features/prediction/domain/delay_predictor.dart';
import 'package:bmtc_predictor/features/schedule/domain/network.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final json = jsonDecode(File('assets/models/delay_model.json').readAsStringSync()) as Map<String, dynamic>;
  final model = DelayModel.fromJson(json);
  final net = Network.fromJson(
      jsonDecode(File('assets/data/network.json').readAsStringSync()) as Map<String, dynamic>);

  test('Dart inference matches the Python export (parity checks)', () {
    for (final c in json['checks'] as List) {
      final x = [for (final v in c['x'] as List) (v as num).toDouble()];
      final y = [for (final v in c['y'] as List) (v as num).toDouble()];
      final (q50, q90) = model.predict(x);
      expect(q50, closeTo(y[0], 1e-6));
      expect(q90, closeTo(y[1], 1e-6));
    }
  });

  test('q90 is never below q50', () {
    final silk = net.searchStops('Central Silk Board').first;
    for (final a in net.arrivalsAt(silk.id, DateTime.utc(2026, 11, 5, 6), window: const Duration(hours: 16))) {
      final (q50, q90) = model.predict(delayFeatures(a, rainMmh: 0));
      expect(q90, greaterThanOrEqualTo(q50));
    }
  });

  test('model behaves sensibly: peak > night, rain > dry, later stops > first stops', () {
    final pattern = net.patterns.firstWhere((p) => net.routes[p.routeId]!.short == '500-D');
    double q50At(int hour, int stopIndex, double rain, {int day = 5}) {
      final dayStart = DateTime.utc(2026, 11, day);
      final t = pattern.trips.indexWhere((t) => t.$1 >= hour * 3600);
      final a = net.arrival(pattern, t, stopIndex, dayStart);
      return model.predict(delayFeatures(a, rainMmh: rain)).$1;
    }
    final mid = pattern.stopIds.length ~/ 2;
    expect(q50At(18, mid, 0), greaterThan(q50At(5, mid, 0)));
    expect(q50At(18, mid, 10), greaterThan(q50At(18, mid, 0)));
    expect(q50At(18, pattern.stopIds.length - 2, 0), greaterThan(q50At(18, 1, 0)));
  });

  test('feature vector length matches the model contract', () {
    final a = net.arrivalsAt(net.stops.keys.first, DateTime.utc(2026, 11, 5, 9), window: const Duration(hours: 24)).first;
    expect(delayFeatures(a, rainMmh: 5), hasLength(model.features.length));
  });

  group('report correction', () {
    final silk = net.searchStops('Central Silk Board').first;
    final a = net.arrivalsAt(silk.id, DateTime.utc(2026, 11, 5, 8, 30)).first;

    ArrivalReport report(double actualDelay, double predicted) => ArrivalReport(
          tripKey: 'x', routeShort: a.route.short, stopId: silk.id, stopName: silk.desc,
          scheduled: a.scheduled, reportedAt: a.scheduled.add(Duration(seconds: (actualDelay * 60).round())),
          rainMode: false, features: delayFeatures(a, rainMmh: 0), predictedQ50: predicted, predictedQ90: predicted + 5,
        );

    test('no reports = pure model', () {
      final p = ModelDelayPredictor(model).predict(a, rainMmh: 0);
      expect(p.q50, closeTo(model.predict(delayFeatures(a, rainMmh: 0)).$1, 1e-9));
      expect(p.reportsUsed, 0);
    });

    test('shrinks towards the reports as they accumulate', () {
      // Each report says the bus was 10 min later than predicted.
      final one = ModelDelayPredictor(model, reports: [report(15, 5)]).predict(a, rainMmh: 0);
      final nine = ModelDelayPredictor(model, reports: List.generate(9, (_) => report(15, 5))).predict(a, rainMmh: 0);
      expect(one.correctionMin, closeTo(10 * 1 / 4, 1e-9)); // n/(n+3)
      expect(nine.correctionMin, closeTo(10 * 9 / 12, 1e-9));
      expect(nine.reportsUsed, 9);
    });

    test('other routes are not corrected', () {
      final other = net.arrivalsAt(silk.id, DateTime.utc(2026, 11, 5, 8, 30))
          .firstWhere((x) => x.route.short != a.route.short, orElse: () => a);
      if (other.route.short == a.route.short) return;
      expect(ModelDelayPredictor(model, reports: [report(15, 5)]).predict(other, rainMmh: 0).reportsUsed, 0);
    });

    test('CSV export has feature columns + delay for Colab', () {
      final csv = reportsToCsv([report(12.5, 5)]);
      final lines = csv.trim().split('\n');
      expect(lines.first.split(',').take(12).toList(), [for (var i = 0; i < 11; i++) 'f$i', 'delay_min']);
      expect(lines[1].split(',')[11], '12.50');
    });
  });

  test('time formatting', () {
    expect(formatTime(DateTime.utc(2026, 1, 1, 8, 42)), '8:42 am');
    expect(formatTime(DateTime.utc(2026, 1, 1, 0, 5)), '12:05 am');
    expect(formatTime(DateTime.utc(2026, 1, 1, 18, 0)), '6:00 pm');
    expect(formatDelay(11.4), '+11 min');
    expect(formatDelay(0.2), 'on time');
    expect(formatDelay(-2), '-2 min');
  });
}
