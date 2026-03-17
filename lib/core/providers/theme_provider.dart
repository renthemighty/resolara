import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kThemeModeKey = 'theme_mode';

class ThemeNotifier extends AsyncNotifier<ThemeMode> {
  static const _storage = FlutterSecureStorage();

  @override
  Future<ThemeMode> build() async {
    final value = await _storage.read(key: _kThemeModeKey);
    return _fromString(value);
  }

  Future<void> setMode(ThemeMode mode) async {
    await _storage.write(key: _kThemeModeKey, value: _toString(mode));
    state = AsyncData(mode);
  }

  static ThemeMode _fromString(String? value) => switch (value) {
        'light'  => ThemeMode.light,
        'dark'   => ThemeMode.dark,
        _        => ThemeMode.system,
      };

  static String _toString(ThemeMode mode) => switch (mode) {
        ThemeMode.light  => 'light',
        ThemeMode.dark   => 'dark',
        ThemeMode.system => 'system',
      };
}

final themeModeProvider = AsyncNotifierProvider<ThemeNotifier, ThemeMode>(
  ThemeNotifier.new,
);
