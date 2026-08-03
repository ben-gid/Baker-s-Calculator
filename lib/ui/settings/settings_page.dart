import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../core/theme/spacing.dart';
import '../../state/providers.dart';
import '../widgets/section_card.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            pageMargin(width),
            Insets.lg,
            pageMargin(width),
            Insets.xl,
          ),
          children: [
            SectionCard(
              title: 'Units',
              children: [
                SegmentedButton<MassUnit>(
                  segments: [
                    for (final unit in MassUnit.values)
                      ButtonSegment(value: unit, label: Text(unit.label)),
                  ],
                  selected: {settings.unit},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => controller.setUnit(s.first),
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
            SectionCard(
              title: 'Appearance',
              children: [
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                    ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                  ],
                  selected: {settings.themeMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => controller.setThemeMode(s.first),
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
            const SectionCard(
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
