import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/arrival_report.dart';

/// "Bus arrived" reports, stored on the device (newest first).
class ReportsController extends AsyncNotifier<List<ArrivalReport>> {
  static const _key = 'arrival_reports';

  @override
  Future<List<ArrivalReport>> build() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return const [];
    return [
      for (final j in jsonDecode(raw) as List) ArrivalReport.fromJson(j as Map<String, dynamic>),
    ];
  }

  bool hasReported(String tripKey, String stopId) =>
      (state.value ?? const []).any((r) => r.tripKey == tripKey && r.stopId == stopId);

  Future<void> add(ArrivalReport report) => _save([report, ...?state.value]);

  Future<void> remove(ArrivalReport report) =>
      _save([for (final r in state.value ?? const <ArrivalReport>[]) if (!identical(r, report)) r]);

  Future<void> clear() => _save(const []);

  Future<void> _save(List<ArrivalReport> reports) async {
    state = AsyncData(reports);
    await (await SharedPreferences.getInstance())
        .setString(_key, jsonEncode([for (final r in reports) r.toJson()]));
  }
}

final reportsProvider =
    AsyncNotifierProvider<ReportsController, List<ArrivalReport>>(ReportsController.new);
