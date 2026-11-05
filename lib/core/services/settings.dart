import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A boolean setting saved on the device.
class BoolSetting extends AsyncNotifier<bool> {
  BoolSetting(this.key);

  final String key;

  @override
  Future<bool> build() async => (await SharedPreferences.getInstance()).getBool(key) ?? false;

  Future<void> set(bool value) async {
    state = AsyncData(value);
    await (await SharedPreferences.getInstance()).setBool(key, value);
  }

  Future<void> toggle() => set(!(state.value ?? false));
}

/// Show stop names in Kannada (ಕನ್ನಡ) instead of English.
final kannadaNamesProvider = AsyncNotifierProvider<BoolSetting, bool>(() => BoolSetting('kannada_names'));
