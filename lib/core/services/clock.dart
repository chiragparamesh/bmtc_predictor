import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/ist_time.dart';

/// Current IST wall-clock time. Overridden in tests for deterministic timetables.
final clockProvider = Provider<DateTime Function()>((ref) => nowIst);
