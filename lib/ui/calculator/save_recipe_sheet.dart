import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';
import '../../domain/models/recipe_input.dart';
import '../../state/providers.dart';

/// Names a recipe and adds it to the library. Deliberately one field and two
/// buttons — naming is the only thing the baker has to decide.
Future<void> showSaveRecipeSheet(
  BuildContext context,
  WidgetRef ref,
  RecipeInput input, {
  String? suggestedName,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final name = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _SaveSheet(
      suggestedName: suggestedName ?? '${input.style.label} loaf',
    ),
  );
  if (name == null) return;

  await ref.read(libraryProvider.notifier).add(name: name, input: input);
  messenger.showSnackBar(SnackBar(content: Text('Saved "$name"')));
}

class _SaveSheet extends StatefulWidget {
  const _SaveSheet({required this.suggestedName});

  final String suggestedName;

  @override
  State<_SaveSheet> createState() => _SaveSheetState();
}

class _SaveSheetState extends State<_SaveSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.suggestedName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Insets.xl,
        0,
        Insets.xl,
        Insets.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Save recipe', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Insets.lg),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: Insets.xl),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
