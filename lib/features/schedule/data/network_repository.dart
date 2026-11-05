import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/network.dart';

const networkAsset = 'assets/data/network.json';

/// Bundled BMTC subset (ODbL, from github.com/Vonter/bmtc-gtfs).
final networkProvider = FutureProvider<Network>((ref) async {
  final text = await rootBundle.loadString(networkAsset);
  return Network.fromJson(jsonDecode(text) as Map<String, dynamic>);
});
