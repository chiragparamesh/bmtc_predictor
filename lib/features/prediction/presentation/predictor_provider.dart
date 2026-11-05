import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../arrival_report/data/report_store.dart';
import '../data/model_repository.dart';
import '../domain/delay_predictor.dart';

/// Model + per-route correction from the rider's reports. Rebuilds when a report is added.
final predictorProvider = FutureProvider<DelayPredictor>((ref) async {
  final model = await ref.watch(delayModelProvider.future);
  final reports = await ref.watch(reportsProvider.future);
  return ModelDelayPredictor(model, reports: reports);
});
