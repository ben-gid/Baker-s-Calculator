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
    final use24Hour = ref.watch(
      settingsProvider.select((s) => s.use24HourClock),
    );

    return MaterialApp.router(
      title: "Baker's Calculator",
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: themeMode,
      // The clock setting rides on MediaQuery, so the time pickers follow it
      // and every `formatClock` reads it from the context it is drawn in.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: use24Hour),
        child: child!,
      ),
    );
  }
}
