import 'dart:convert';
import 'dart:io';

import 'package:bmtc_predictor/features/schedule/domain/network.dart';
import 'package:flutter_test/flutter_test.dart';

Network tiny() => Network(
      feedVersion: 't',
      routes: const [BusRoute(id: 'r1', short: '500-D', long: 'A ⇔ C', vajra: false, corridors: ['orr'])],
      stops: const [
        Stop(id: 'a', name: 'A', desc: 'A (Towards C)', kn: 'ಎ', lat: 0, lon: 0),
        Stop(id: 'b', name: 'B', desc: 'B (Towards C)', kn: '', lat: 0, lon: 0),
        Stop(id: 'c', name: 'C', desc: 'C', kn: '', lat: 0, lon: 0),
      ],
      patterns: const [
        Pattern(
          id: 'p0',
          routeId: 'r1',
          headsign: 'C',
          stopIds: ['a', 'b', 'c'],
          profiles: [
            [0, 600, 1200], // off-peak: 10 min per hop
            [0, 1200, 2400], // peak: 20 min per hop
          ],
          trips: [(8 * 3600, 1), (12 * 3600, 0), (23 * 3600 + 55 * 60, 0)],
        ),
      ],
    );

void main() {
  final day = DateTime.utc(2026, 11, 5);

  test('arrivals use the trip profile (peak running times)', () {
    final net = tiny();
    final at = net.arrivalsAt('b', day.add(const Duration(hours: 8)));
    expect(at.first.scheduled, day.add(const Duration(hours: 8, minutes: 20)));
    expect(at.first.progress, 0.5);
    expect(at.first.minutesFromStart, 20);
  });

  test('terminating buses are not listed at the last stop', () {
    expect(tiny().arrivalsAt('c', day.add(const Duration(hours: 8))), isEmpty);
  });

  test('trips crossing midnight are found the next morning', () {
    final net = tiny();
    // 23:55 trip reaches B at 00:05 the next day.
    final at = net.arrivalsAt('b', day.add(const Duration(days: 1)), window: const Duration(minutes: 30));
    expect(at, hasLength(1));
    expect(at.single.scheduled, day.add(const Duration(days: 1, minutes: 5)));
    expect(at.single.tripStart, day.add(const Duration(hours: 23, minutes: 55)));
  });

  test('timeline lists every stop of the trip', () {
    final net = tiny();
    final a = net.arrivalsAt('a', day.add(const Duration(hours: 12))).first;
    expect(net.tripTimeline(a).map((x) => x.stopId), ['a', 'b', 'c']);
  });

  test('search matches English and Kannada', () {
    final net = tiny();
    expect(net.searchStops('a (tow').single.id, 'a');
    expect(net.searchStops('ಎ').single.id, 'a');
    expect(net.searchStops(''), isEmpty);
  });

  group('bundled network.json', () {
    final net = Network.fromJson(
        jsonDecode(File('assets/data/network.json').readAsStringSync()) as Map<String, dynamic>);

    test('has the 12 routes and Kannada names', () {
      expect(net.routes.length, 12);
      expect(net.routes.values.map((r) => r.short), containsAll(['500-D', 'V-500D', 'KIA-9', 'KBS-3A']));
      expect(net.stops.values.where((s) => s.kn.isNotEmpty).length, greaterThan(300));
    });

    test('Central Silk Board has buses on a weekday morning', () {
      final silk = net.searchStops('Central Silk Board');
      expect(silk, isNotEmpty);
      final morning = DateTime.utc(2026, 11, 5, 8, 30);
      final buses = silk.expand((s) => net.arrivalsAt(s.id, morning)).toList();
      expect(buses.length, greaterThan(10));
      expect(buses.every((b) => !b.scheduled.isBefore(morning.subtract(const Duration(minutes: 5)))), isTrue);
    });
  });
}
