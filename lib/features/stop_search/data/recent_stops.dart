import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Recently opened stop ids (most recent first, max 6).
class RecentStopsController extends AsyncNotifier<List<String>> {
  static const _key = 'recent_stops';

  @override
  Future<List<String>> build() async =>
      (await SharedPreferences.getInstance()).getStringList(_key) ?? const [];

  Future<void> visit(String stopId) async {
    final next = [stopId, ...?state.value?.where((s) => s != stopId)].take(6).toList();
    state = AsyncData(next);
    await (await SharedPreferences.getInstance()).setStringList(_key, next);
  }
}

final recentStopsProvider =
    AsyncNotifierProvider<RecentStopsController, List<String>>(RecentStopsController.new);
