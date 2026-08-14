import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../core/theme/spacing.dart';
import '../../state/providers.dart';
import '../widgets/panel.dart';
import '../widgets/style_toggle.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: pagePadding(context, bottom: Insets.xl),
          children: [
            Panel(
              title: 'Units',
              children: [
                StyleToggle<MassUnit>(
                  options: [
                    for (final unit in MassUnit.values)
                      ToggleOption(value: unit, label: unit.label),
                  ],
                  selected: settings.unit,
                  onChanged: controller.setUnit,
                ),
                const SizedBox(height: Insets.md),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Show baker's percentages"),
                  subtitle: const Text(
                    'Each ingredient as a percentage of total flour',
                  ),
                  value: settings.showBakersPercent,
                  onChanged: (_) => controller.toggleBakersPercent(),
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
            Panel(
              title: 'Appearance',
              children: [
                StyleToggle<ThemeMode>(
                  options: const [
                    ToggleOption(value: ThemeMode.light, label: 'Light'),
                    ToggleOption(value: ThemeMode.system, label: 'Auto'),
                    ToggleOption(value: ThemeMode.dark, label: 'Dark'),
                  ],
                  selected: settings.themeMode,
                  onChanged: controller.setThemeMode,
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
            const Panel(
              title: 'About',
              children: [
                Text(
                  "Baker's Calculator works out ingredient weights from baker's "
                  'percentages. Everything stays on this device — no account, '
                  'no network, no analytics.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
