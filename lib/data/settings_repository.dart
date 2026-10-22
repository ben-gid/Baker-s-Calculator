import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/formatting.dart';
import '../domain/dough_temp.dart';
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

/// The dough-temperature card's inputs, kept so the bake's mixing step can say
/// how warm the water should be without the baker typing them again.
class DoughTemps {
  const DoughTemps({
    this.desired = 25,
    this.room = 21,
    this.flour = 20,
    this.friction = handMixFriction,
    this.preferment,
  });

  final double desired;
  final double room;
  final double flour;
  final double friction;

  /// Null when the dough has no levain or preferment to count.
  final double? preferment;

  ({double waterTemp, String? warning}) get water => waterTemperature(
    desiredDoughTemp: desired,
    roomTemp: room,
    flourTemp: flour,
    prefermentTemp: preferment,
    frictionFactor: friction,
  );
}

class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _unitKey = 'unit';
  static const _themeKey = 'themeMode';
  static const _percentKey = 'showBakersPercent';
  static const _bakeKey = 'activeBake';
  static const _tempKey = 'doughTemp';

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

  DoughTemps readDoughTemps() {
    double? at(String name) => _prefs.getDouble('$_tempKey.$name');
    const fallback = DoughTemps();
    return DoughTemps(
      desired: at('desired') ?? fallback.desired,
      room: at('room') ?? fallback.room,
      flour: at('flour') ?? fallback.flour,
      friction: at('friction') ?? fallback.friction,
      preferment: at('preferment'),
    );
  }

  Future<void> writeDoughTemps(DoughTemps temps) async {
    await _prefs.setDouble('$_tempKey.desired', temps.desired);
    await _prefs.setDouble('$_tempKey.room', temps.room);
    await _prefs.setDouble('$_tempKey.flour', temps.flour);
    await _prefs.setDouble('$_tempKey.friction', temps.friction);
    if (temps.preferment == null) {
      await _prefs.remove('$_tempKey.preferment');
    } else {
      await _prefs.setDouble('$_tempKey.preferment', temps.preferment!);
    }
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
