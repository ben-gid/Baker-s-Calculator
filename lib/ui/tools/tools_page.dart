import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/spacing.dart';
import '../../domain/dough_temp.dart';
import '../widgets/number_field.dart';
import '../widgets/section_card.dart';

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      appBar: AppBar(title: const Text('Tools')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            pageMargin(width),
            Insets.lg,
            pageMargin(width),
            Insets.scrollBottom,
          ),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.auto_awesome_outlined),
                title: const Text('Suggest a recipe'),
                subtitle: const Text('Answer four questions, get a recipe'),
                onTap: () => context.push('/suggest'),
              ),
            ),
            const SizedBox(height: Insets.md),
            Card(
              child: ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: const Text('Import a recipe'),
                subtitle: const Text('Paste a shared link or code'),
                onTap: () => context.push('/import'),
              ),
            ),
            const SizedBox(height: Insets.md),
            const _DoughTempCard(),
          ],
        ),
      ),
    );
  }
}

/// Desired dough temperature. A separate little calculator rather than part of
/// the recipe, because bakers reach for it at mixing time, not planning time.
class _DoughTempCard extends StatefulWidget {
  const _DoughTempCard();

  @override
  State<_DoughTempCard> createState() => _DoughTempCardState();
}

class _DoughTempCardState extends State<_DoughTempCard> {
  double _desired = 25;
  double _room = 21;
  double _flour = 20;
  double _friction = handMixFriction;
  double? _preferment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baking = theme.extension<BakingColors>()!;

    final result = waterTemperature(
      DoughTempInputs(
        desiredDoughTemp: _desired,
        roomTemp: _room,
        flourTemp: _flour,
        prefermentTemp: _preferment,
        frictionFactor: _friction,
      ),
    );

    return SectionCard(
      title: 'Dough temperature',
      note: 'Work out how warm the water needs to be to finish at your target '
          'dough temperature.',
      children: [
        NumberField(
          label: 'Desired dough temperature',
          suffix: '°C',
          value: _desired,
          onChanged: (v) => setState(() => _desired = v ?? 0),
        ),
        NumberField(
          label: 'Room temperature',
          suffix: '°C',
          value: _room,
          onChanged: (v) => setState(() => _room = v ?? 0),
        ),
        NumberField(
          label: 'Flour temperature',
          suffix: '°C',
          value: _flour,
          onChanged: (v) => setState(() => _flour = v ?? 0),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Using a levain or preferment'),
          subtitle: const Text('Adds it as a fourth temperature'),
          value: _preferment != null,
          onChanged: (on) => setState(() => _preferment = on ? 23 : null),
        ),
        if (_preferment != null)
          Padding(
            padding: const EdgeInsets.only(top: Insets.md),
            child: NumberField(
              label: 'Levain / preferment temperature',
              suffix: '°C',
              value: _preferment,
              onChanged: (v) => setState(() => _preferment = v ?? 0),
            ),
          ),
        const SizedBox(height: Insets.sm),
        Text('Mixing', style: theme.textTheme.labelMedium),
        const SizedBox(height: Insets.sm),
        SegmentedButton<double>(
          segments: const [
            ButtonSegment(value: handMixFriction, label: Text('By hand')),
            ButtonSegment(value: standMixerFriction, label: Text('Mixer')),
          ],
          selected: {_friction},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _friction = s.first),
        ),
        const SizedBox(height: Insets.xl),
        Container(
          padding: const EdgeInsets.all(Insets.lg),
          decoration: BoxDecoration(
            color: baking.proofContainer,
            borderRadius: BorderRadius.circular(Radii.field),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Use water at', style: theme.textTheme.bodyMedium),
              const SizedBox(height: Insets.xs),
              Text(
                '${result.waterTemp.toStringAsFixed(1)} °C',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontFeatures: tabularFigures,
                ),
              ),
              if (result.warning != null) ...[
                const SizedBox(height: Insets.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 18, color: baking.warn),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: Text(
                        result.warning!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: baking.warn,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
