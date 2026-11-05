import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/delay_model.dart';

const delayModelAsset = 'assets/models/delay_model.json';

/// The MLP exported by ml/train_delay_model.py.
final delayModelProvider = FutureProvider<DelayModel>((ref) async {
  final text = await rootBundle.loadString(delayModelAsset);
  return DelayModel.fromJson(jsonDecode(text) as Map<String, dynamic>);
});
