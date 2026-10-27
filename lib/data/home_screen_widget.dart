/// The home-screen widget: the step under way in a bake, with its buttons, or
/// the recipe the baker pinned to it when no bake is running.
///
/// The widget draws itself from what is saved here, without the app. A bake
/// goes over as its whole forecast (`bakeSnapshot`), so the widget can tell
/// which step is under way at any moment; Android is woken at each step's end
/// to redraw, and iOS lays the same times out as its timeline.
///
/// Its buttons are links, `bakerscalc://widget/press?action=done&step=3`,
/// that reach Dart through `onWidgetAction` in the notification service and
/// are applied exactly like a reminder's buttons. Its taps are links too,
/// `bakerscalc://widget/recipe/<id>`, whose path is a route of the app.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../domain/models/active_bake.dart';
import '../domain/widget_snapshot.dart';

/// What the widget shows of a pinned recipe: [line] is already formatted in
/// the baker's units, because the widget has no way to format it.
typedef PinnedRecipe = ({String id, String name, String line});

class HomeScreenWidget {
  /// Shared with the iOS widget extension. Must match both targets'
  /// entitlements.
  static const appGroup = 'group.dev.bengid.bakersCalculator';
  static const _android = 'dev.bengid.bakersCalculator.BakeWidgetProvider';
  static const _iOS = 'BakeWidget';

  static const _bakeKey = 'bake';
  static const _pinnedKey = 'pinned';

  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Called at launch, with the function the widget's buttons run in the
  /// background. Asks for nothing.
  Future<void> initialise(FutureOr<void> Function(Uri?) onPress) =>
      _guard(() async {
        await HomeWidget.setAppGroupId(appGroup);
        await HomeWidget.registerInteractivityCallback(onPress);
      });

  /// Hands the widget [bake], or tells it none is running.
  Future<void> showBake(ActiveBake? bake) => _guard(() async {
    await HomeWidget.saveWidgetData<String>(
      _bakeKey,
      bake == null ? null : jsonEncode(bakeSnapshot(bake)),
      appGroupId: appGroup,
    );
    // Android only: wakes the widget as each step ends. iOS reads the same
    // times as its timeline.
    if (Platform.isAndroid) {
      await HomeWidget.scheduleWidgetUpdates([
        if (bake != null)
          for (final s in bake.schedule) s.endsAt,
      ], qualifiedAndroidName: _android);
    }
    await _redraw();
  });

  /// Shows [recipe] whenever no bake is running.
  Future<void> pin(PinnedRecipe recipe) => _guard(() async {
    await HomeWidget.saveWidgetData<String>(
      _pinnedKey,
      jsonEncode({'id': recipe.id, 'name': recipe.name, 'line': recipe.line}),
      appGroupId: appGroup,
    );
    await _redraw();
  });

  /// Clears the pin if it is [id]: a deleted recipe's widget would open onto
  /// "Recipe not found".
  Future<void> unpin(String id) => _guard(() async {
    final raw = await HomeWidget.getWidgetData<String>(
      _pinnedKey,
      appGroupId: appGroup,
    );
    if (raw == null || (jsonDecode(raw) as Map)['id'] != id) return;
    await HomeWidget.saveWidgetData<String>(
      _pinnedKey,
      null,
      appGroupId: appGroup,
    );
    await _redraw();
  });

  /// Whether [addToHomeScreen] can work: Android launchers that support
  /// pinning only. iOS has no way for an app to place a widget.
  Future<bool> canAddToHomeScreen() async {
    if (!_supported || !Platform.isAndroid) return false;
    try {
      return await HomeWidget.isRequestPinWidgetSupported() ?? false;
    } on Object {
      return false;
    }
  }

  /// Asks the launcher to place the widget; it shows its own confirmation.
  Future<void> addToHomeScreen() =>
      _guard(() => HomeWidget.requestPinWidget(qualifiedAndroidName: _android));

  Future<void> _redraw() =>
      HomeWidget.updateWidget(qualifiedAndroidName: _android, iOSName: _iOS);

  /// A widget that cannot be updated is never worth interrupting the baker
  /// over: the app and its reminders carry on regardless.
  Future<void> _guard(Future<void> Function() action) async {
    if (!_supported) return;
    try {
      await action();
    } on Object catch (e) {
      debugPrint('Home-screen widget not updated: $e');
    }
  }
}
