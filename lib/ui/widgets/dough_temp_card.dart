import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/spacing.dart';
import '../../data/settings_repository.dart';
import '../../domain/dough_temp.dart';
import '../../state/providers.dart';
import 'number_field.dart';
import 'panel.dart';
import 'style_toggle.dart';

/// Desired dough temperature. A separate little calculator rather than part of
/// the recipe, because bakers reach for it at mixing time — which is why it
/// lives on the bake plan, beside the steps it is used for. What it last
/// worked out is kept, so a bake's mixing step can say the same water temperature.
class DoughTempCard extends ConsumerStatefulWidget {
  const DoughTempCard({super.key});

  @override
  ConsumerState<DoughTempCard> createState() => _DoughTempCardState();
}

class _DoughTempCardState extends ConsumerState<DoughTempCard> {
  late final DoughTemps _saved = ref.read(doughTempsProvider);
  late double? _desired = _saved.desired;
  late double? _room = _saved.room;
  late double? _flour = _saved.flour;
  late double _friction = _saved.friction;
  late double? _preferment = _saved.preferment ?? 23;

  /// Kept separate from [_preferment] so clearing that box does not flip the
  /// switch off and take its own field away mid-edit.
  late bool _usePreferment = _saved.preferment != null;

  /// Saves the boxes once they make a whole answer. An emptied box is left
  /// out until it is filled again: it is not 0 °C.
  void _edit(VoidCallback change) {
    setState(change);
    if (_result == null) return;
    ref
        .read(doughTempsProvider.notifier)
        .set(
          DoughTemps(
            desired: _desired!,
            room: _room!,
            flour: _flour!,
            friction: _friction,
            preferment: _usePreferment ? _preferment : null,
          ),
        );
  }

  /// Null while any box in use is empty — an empty box is not 0 °C.
  ({double waterTemp, String? warning})? get _result =>
      (_desired == null ||
          _room == null ||
          _flour == null ||
          (_usePreferment && _preferment == null))
      ? null
      : waterTemperature(
          desiredDoughTemp: _desired!,
          roomTemp: _room!,
          flourTemp: _flour!,
          prefermentTemp: _usePreferment ? _preferment : null,
          frictionFactor: _friction,
        );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baking = theme.extension<BakingColors>()!;
    final result = _result;

    return Panel(
      title: 'Dough temperature',
      note:
          'Work out how warm the water needs to be to finish at your target '
          'dough temperature.',
      children: [
        NumberField(
          label: 'Desired dough temperature',
          suffix: '°C',
          value: _desired,
          onChanged: (v) => _edit(() => _desired = v),
        ),
        NumberField(
          label: 'Room temperature',
          suffix: '°C',
          value: _room,
          onChanged: (v) => _edit(() => _room = v),
        ),
        NumberField(
          label: 'Flour temperature',
          suffix: '°C',
          value: _flour,
          onChanged: (v) => _edit(() => _flour = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Using a levain or preferment'),
          subtitle: const Text('Adds it as a fourth temperature'),
          value: _usePreferment,
          onChanged: (on) => _edit(() => _usePreferment = on),
        ),
        if (_usePreferment)
          Padding(
            padding: const EdgeInsets.only(top: Insets.md),
            child: NumberField(
              label: 'Levain / preferment temperature',
              suffix: '°C',
              value: _preferment,
              onChanged: (v) => _edit(() => _preferment = v),
            ),
          ),
        const SizedBox(height: Insets.sm),
        const SectionLabel('Mixing'),
        const SizedBox(height: Insets.sm),
        StyleToggle<double>(
          options: const [
            ToggleOption(value: handMixFriction, label: 'By hand'),
            ToggleOption(value: standMixerFriction, label: 'Mixer'),
          ],
          selected: _friction,
          onChanged: (v) => _edit(() => _friction = v),
        ),
        const SizedBox(height: Insets.xl),
        DecoratedBox(
          decoration: BoxDecoration(
            color: baking.proofContainer,
            borderRadius: BorderRadius.circular(Radii.field),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Insets.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Use water at',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: baking.onProofContainerMuted,
                  ),
                ),
                const SizedBox(height: Insets.xs),
                Text(
                  result == null
                      ? '—'
                      : '${result.waterTemp.toStringAsFixed(1)} °C',
                  style: numeric(
                    theme.textTheme.displaySmall,
                  ).copyWith(color: baking.onProofContainer),
                ),
              ],
            ),
          ),
        ),
        // Outside the tonal block, deliberately: only the two `onProofContainer`
        // foregrounds are tuned against that warm fill, and advisory text reads
        // better beside the answer than inside it.
        if (result?.warning != null) ...[
          const SizedBox(height: Insets.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: baking.warn),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  result!.warning!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: baking.warn,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
