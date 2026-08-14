import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/spacing.dart';
import '../../domain/calculator.dart';
import '../../domain/models/dough_style.dart';
import '../../domain/wizard.dart';
import '../../state/providers.dart';
import '../widgets/action_bar.dart';
import '../widgets/panel.dart';
import '../widgets/recipe_view.dart';
import '../widgets/style_toggle.dart';

/// "Make me a recipe" in four choices.
///
/// The result updates live underneath, so this is a browsing tool rather than a
/// form to complete — and because it composes from presets it can only ever
/// produce a recipe that works.
class WizardPage extends ConsumerStatefulWidget {
  const WizardPage({super.key});

  @override
  ConsumerState<WizardPage> createState() => _WizardPageState();
}

class _WizardPageState extends ConsumerState<WizardPage> {
  WizardChoices _choices = const WizardChoices();

  void _update(WizardChoices next) => setState(() => _choices = next);

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final input = composeRecipe(_choices);

    return Scaffold(
      appBar: AppBar(title: const Text('Suggest a recipe')),
      bottomNavigationBar: ActionBar(
        label: 'Save this recipe',
        icon: Icons.bookmark_add_outlined,
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          final router = GoRouter.of(context);
          final saved = await ref
              .read(libraryProvider.notifier)
              .add(name: _choices.suggestedName, input: input);
          messenger.showSnackBar(
            SnackBar(content: Text('Saved "${saved.name}"')),
          );
          router.go('/recipe/${saved.id}');
        },
      ),
      body: SafeArea(
        child: ListView(
          padding: pagePadding(context),
          children: [
            Panel(
              title: 'What are you baking?',
              children: [
                RadioGroup<BreadCharacter>(
                  groupValue: _choices.character,
                  onChanged: (value) =>
                      _update(_choices.copyWith(character: value)),
                  child: Column(
                    children: [
                      for (final character in BreadCharacter.values)
                        RadioListTile<BreadCharacter>(
                          contentPadding: EdgeInsets.zero,
                          value: character,
                          title: Text(character.label),
                          subtitle: Text(character.blurb),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
            Panel(
              title: 'How is it leavened?',
              children: [
                StyleToggle<DoughStyle>(
                  options: [
                    for (final style in DoughStyle.values)
                      ToggleOption(value: style, label: style.label),
                  ],
                  selected: _choices.style,
                  onChanged: (style) =>
                      _update(_choices.copyWith(style: style)),
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
            Panel(
              title: 'Flour',
              children: [
                Wrap(
                  spacing: Insets.sm,
                  runSpacing: Insets.sm,
                  children: [
                    for (final flour in FlourChoice.values)
                      ChoiceChip(
                        label: Text(flour.label),
                        selected: _choices.flour == flour,
                        onSelected: (_) =>
                            _update(_choices.copyWith(flour: flour)),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
            Panel(
              title: 'Anything in it?',
              children: [
                Wrap(
                  spacing: Insets.sm,
                  runSpacing: Insets.sm,
                  children: [
                    for (final addIn in AddIn.values)
                      FilterChip(
                        label: Text(addIn.label),
                        selected: _choices.addIns.contains(addIn),
                        onSelected: (on) => _update(
                          _choices.copyWith(
                            addIns: {
                              for (final existing in _choices.addIns)
                                if (existing != addIn) existing,
                              if (on) addIn,
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: Insets.xl),
            Text(
              _choices.suggestedName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: Insets.md),
            RecipeView(
              recipe: calculate(input),
              unit: settings.unit,
              showBakersPercent: settings.showBakersPercent,
            ),
          ],
        ),
      ),
    );
  }
}
