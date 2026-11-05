import '../../../core/utils/ist_time.dart';

/// A BMTC route (one route id = one direction family in the GTFS feed).
class BusRoute {
  const BusRoute({
    required this.id,
    required this.short,
    required this.long,
    required this.vajra,
    required this.corridors,
  });

  final String id;

  /// Route number as shown on the bus, e.g. "500-D", "V-500D", "KIA-9".
  final String short;
  final String long;

  /// AC Vajra / Vayu Vajra service.
  final bool vajra;

  /// "orr", "silk_board", "majestic", "airport" (model features).
  final List<String> corridors;

  factory BusRoute.fromJson(Map<String, dynamic> j) => BusRoute(
        id: j['id'] as String,
        short: j['short'] as String,
        long: j['long'] as String,
        vajra: j['vajra'] as bool,
        corridors: [for (final c in j['corridors'] as List) c as String],
      );
}

class Stop {
  const Stop({
    required this.id,
    required this.name,
    required this.desc,
    required this.kn,
    required this.lat,
    required this.lon,
  });

  final String id;

  /// Short name, e.g. "Central Silk Board".
  final String name;

  /// Name with direction, e.g. "Central Silk Board (Towards Marathahalli)".
  final String desc;

  /// Kannada name (may be empty).
  final String kn;
  final double lat;
  final double lon;

  String display({bool kannada = false}) => kannada && kn.isNotEmpty ? kn : desc;

  factory Stop.fromJson(Map<String, dynamic> j) => Stop(
        id: j['id'] as String,
        name: j['name'] as String,
        desc: j['desc'] as String,
        kn: j['kn'] as String? ?? '',
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
      );
}

/// All trips of one route + direction that stop at the same sequence of stops.
class Pattern {
  const Pattern({
    required this.id,
    required this.routeId,
    required this.headsign,
    required this.stopIds,
    required this.profiles,
    required this.trips,
  });

  final String id;
  final String routeId;
  final String headsign;
  final List<String> stopIds;

  /// Seconds from trip start to each stop. Several profiles because BMTC
  /// schedules slower running times at peak hours.
  final List<List<int>> profiles;

  /// (start second of day, profile index) per trip.
  final List<(int, int)> trips;

  int offsetSec(int tripIndex, int stopIndex) => profiles[trips[tripIndex].$2][stopIndex];

  factory Pattern.fromJson(Map<String, dynamic> j) => Pattern(
        id: j['id'] as String,
        routeId: j['route'] as String,
        headsign: j['headsign'] as String,
        stopIds: [for (final s in j['stops'] as List) s as String],
        profiles: [
          for (final p in j['profiles'] as List) [for (final o in p as List) o as int],
        ],
        trips: [
          for (final t in j['trips'] as List) ((t as List)[0] as int, t[1] as int),
        ],
      );
}

/// One scheduled bus arrival at one stop.
class ScheduledArrival {
  const ScheduledArrival({
    required this.route,
    required this.pattern,
    required this.tripIndex,
    required this.stopIndex,
    required this.tripStart,
    required this.scheduled,
  });

  final BusRoute route;
  final Pattern pattern;
  final int tripIndex;
  final int stopIndex;

  /// IST wall-clock start of this trip (first stop).
  final DateTime tripStart;

  /// IST wall-clock scheduled arrival at this stop.
  final DateTime scheduled;

  String get stopId => pattern.stopIds[stopIndex];
  double get progress => stopIndex / (pattern.stopIds.length - 1);
  double get minutesFromStart => scheduled.difference(tripStart).inSeconds / 60;

  /// Stable id for this bus run, e.g. "p6#41@2026-11-05".
  String get tripKey =>
      '${pattern.id}#$tripIndex@${tripStart.toIso8601String().substring(0, 10)}';
}

/// The bundled timetable subset with a stop -> (pattern, index) lookup.
class Network {
  Network({
    required this.feedVersion,
    required List<BusRoute> routes,
    required List<Stop> stops,
    required this.patterns,
  })  : routes = {for (final r in routes) r.id: r},
        stops = {for (final s in stops) s.id: s} {
    for (final p in patterns) {
      for (var i = 0; i < p.stopIds.length; i++) {
        _byStop.putIfAbsent(p.stopIds[i], () => []).add((p, i));
      }
    }
  }

  final String feedVersion;
  final Map<String, BusRoute> routes;
  final Map<String, Stop> stops;
  final List<Pattern> patterns;
  final Map<String, List<(Pattern, int)>> _byStop = {};

  factory Network.fromJson(Map<String, dynamic> j) => Network(
        feedVersion: j['feedVersion'] as String? ?? '',
        routes: [for (final r in j['routes'] as List) BusRoute.fromJson(r as Map<String, dynamic>)],
        stops: [for (final s in j['stops'] as List) Stop.fromJson(s as Map<String, dynamic>)],
        patterns: [for (final p in j['patterns'] as List) Pattern.fromJson(p as Map<String, dynamic>)],
      );

  /// Route numbers that stop here, e.g. ["500-D", "KIA-8"].
  List<String> routesAt(String stopId) {
    final set = <String>{
      for (final (p, i) in _byStop[stopId] ?? const <(Pattern, int)>[])
        if (i < p.stopIds.length - 1) routes[p.routeId]!.short,
    };
    return set.toList()..sort();
  }

  ScheduledArrival arrival(Pattern p, int tripIndex, int stopIndex, DateTime serviceDay) {
    final start = serviceDay.add(Duration(seconds: p.trips[tripIndex].$1));
    return ScheduledArrival(
      route: routes[p.routeId]!,
      pattern: p,
      tripIndex: tripIndex,
      stopIndex: stopIndex,
      tripStart: start,
      scheduled: start.add(Duration(seconds: p.offsetSec(tripIndex, stopIndex))),
    );
  }

  /// Buses scheduled at [stopId] from [from] - [lookBack] to [from] + [window],
  /// earliest first. Terminating buses (last stop) are skipped. Trips that run
  /// past midnight are handled by checking yesterday's and tomorrow's service.
  List<ScheduledArrival> arrivalsAt(
    String stopId,
    DateTime from, {
    Duration window = const Duration(hours: 2),
    Duration lookBack = const Duration(minutes: 5),
    int limit = 40,
  }) {
    final lo = from.subtract(lookBack);
    final hi = from.add(window);
    final day0 = istMidnight(from);
    final out = <ScheduledArrival>[];
    for (final (p, i) in _byStop[stopId] ?? const <(Pattern, int)>[]) {
      if (i == p.stopIds.length - 1) continue;
      for (var t = 0; t < p.trips.length; t++) {
        for (final dayShift in const [-1, 0, 1]) {
          final day = day0.add(Duration(days: dayShift));
          final at = day.add(Duration(seconds: p.trips[t].$1 + p.offsetSec(t, i)));
          if (!at.isBefore(lo) && !at.isAfter(hi)) out.add(arrival(p, t, i, day));
        }
      }
    }
    out.sort((a, b) => a.scheduled.compareTo(b.scheduled));
    return out.take(limit).toList();
  }

  /// Full stop-by-stop schedule of the trip that [a] belongs to.
  List<ScheduledArrival> tripTimeline(ScheduledArrival a) {
    final day = istMidnight(a.tripStart);
    return [
      for (var i = 0; i < a.pattern.stopIds.length; i++) arrival(a.pattern, a.tripIndex, i, day),
    ];
  }

  /// Stop search over English name, direction and Kannada name.
  /// Prefix matches rank first, then busiest stops (most routes).
  List<Stop> searchStops(String query, {int limit = 30}) {
    final q = query.trim().toLowerCase();
    final all = stops.values.where((s) => _byStop.containsKey(s.id));
    if (q.isEmpty) return const [];
    final hits = all.where((s) =>
        s.desc.toLowerCase().contains(q) || s.kn.contains(query.trim()));
    final ranked = hits.toList()
      ..sort((a, b) {
        final ap = a.name.toLowerCase().startsWith(q) ? 0 : 1;
        final bp = b.name.toLowerCase().startsWith(q) ? 0 : 1;
        if (ap != bp) return ap - bp;
        final byRoutes = routesAt(b.id).length.compareTo(routesAt(a.id).length);
        return byRoutes != 0 ? byRoutes : a.desc.compareTo(b.desc);
      });
    return ranked.take(limit).toList();
  }
}
