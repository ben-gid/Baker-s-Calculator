import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'state/providers.dart';
import 'ui/router.dart';

class BakersCalculatorApp extends ConsumerStatefulWidget {
  const BakersCalculatorApp({super.key});

  @override
  ConsumerState<BakersCalculatorApp> createState() => _AppState();
}

class _AppState extends ConsumerState<BakersCalculatorApp> {
  // Built once. Rebuilding the router on a theme change would reset every
  // navigation stack underneath it.
  late final _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));

    return MaterialApp.router(
      title: "Baker's Calculator",
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: themeMode,
    );
  }
}
