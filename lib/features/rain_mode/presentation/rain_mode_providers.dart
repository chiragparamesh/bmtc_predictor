import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/settings.dart';

/// "It's raining" switch. Feeds the model a heavy-rain intensity.
final rainModeProvider = AsyncNotifierProvider<BoolSetting, bool>(() => BoolSetting('rain_mode'));

/// Rain intensity used by the model: 10 mm/h (heavy rain) when rain mode is on.
/// Live Open-Meteo rainfall can replace this later.
const rainModeMmh = 10.0;

final rainMmhProvider = Provider<double>(
  (ref) => (ref.watch(rainModeProvider).value ?? false) ? rainModeMmh : 0,
);
