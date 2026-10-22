import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/formatting.dart';
import '../domain/models/active_bake.dart';

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
  static const _bakeKey = 'activeBake';

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

  /// The bake in progress, if any. Lives beside the preferences because it is
  /// just as small, and just as disposable: an unreadable value reads as "no
  /// bake running" rather than stopping the app.
  ActiveBake? readActiveBake() {
    final raw = _prefs.getString(_bakeKey);
    if (raw == null) return null;
    try {
      return ActiveBake.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object catch (e) {
      debugPrint('Ignoring unreadable bake: $e');
      return null;
    }
  }

  Future<void> writeActiveBake(ActiveBake? bake) async {
    if (bake == null) {
      await _prefs.remove(_bakeKey);
    } else {
      await _prefs.setString(_bakeKey, jsonEncode(bake.toJson()));
    }
  }
}
