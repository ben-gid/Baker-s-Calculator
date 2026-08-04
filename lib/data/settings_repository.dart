import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/formatting.dart';

/// User preferences. Small, flat and non-critical — if a read fails the app
/// falls back to defaults rather than refusing to start.
class Settings {
  const Settings({
    this.unit = MassUnit.grams,
    this.themeMode = ThemeMode.system,
    this.showBakersPercent = true,
  });

  final MassUnit unit;
  final ThemeMode themeMode;
  final bool showBakersPercent;

  Settings copyWith({
    MassUnit? unit,
    ThemeMode? themeMode,
    bool? showBakersPercent,
  }) => Settings(
    unit: unit ?? this.unit,
    themeMode: themeMode ?? this.themeMode,
    showBakersPercent: showBakersPercent ?? this.showBakersPercent,
  );
}

class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _unitKey = 'unit';
  static const _themeKey = 'themeMode';
  static const _percentKey = 'showBakersPercent';

  Settings read() => Settings(
    unit: MassUnit.fromName(_prefs.getString(_unitKey)),
    themeMode:
        ThemeMode.values.asNameMap()[_prefs.getString(_themeKey)] ??
        ThemeMode.system,
    showBakersPercent: _prefs.getBool(_percentKey) ?? true,
  );

  Future<void> write(Settings settings) async {
    await _prefs.setString(_unitKey, settings.unit.name);
    await _prefs.setString(_themeKey, settings.themeMode.name);
    await _prefs.setBool(_percentKey, settings.showBakersPercent);
  }
}
