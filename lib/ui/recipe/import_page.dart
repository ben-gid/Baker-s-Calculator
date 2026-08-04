import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/spacing.dart';
import '../../data/recipe_share.dart';
import '../../domain/calculator.dart';
import '../../state/providers.dart';
import '../widgets/recipe_view.dart';
import '../widgets/section_card.dart';

/// Takes a shared link or code and previews it before anything is saved.
///
/// Everything pasted here is untrusted, so it is decoded and validated first
/// and only offered for saving once it produces a real recipe.
class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key, this.payload});

  /// Supplied when the app was opened from a share link rather than by paste.
  final String? payload;

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.payload ?? '',
  );
  ImportedRecipe? _preview;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.payload != null) _decode();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _decode() {
    if (_controller.text.trim().isEmpty) {
      setState(() {
        _preview = null;
        _error = null;
      });
      return;
    }
    try {
      setState(() {
        _preview = decodeShareInput(_controller.text);
        _error = null;
      });
    } on FormatException catch (e) {
      setState(() {
        _preview = null;
        _error = e.message;
      });
    }
  }

  Future<void> _save() async {
    final preview = _preview;
    if (preview == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final saved = await ref
        .read(libraryProvider.notifier)
        .add(name: preview.name, input: preview.input);
    messenger.showSnackBar(
      SnackBar(content: Text('Saved "${saved.name}" to your recipes')),
    );
    router.go('/recipe/${saved.id}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final preview = _preview;

    return Scaffold(
      appBar: AppBar(title: const Text('Import a recipe')),
      floatingActionButton: preview == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _save,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('Save to my recipes'),
            ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: pagePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionCard(
                title: 'Paste the link',
                note:
                    'A shared recipe link, or just the code from the end of it.',
                children: [
                  TextField(
                    controller: _controller,
                    minLines: 2,
                    maxLines: 4,
                    autofocus: widget.payload == null,
                    onChanged: (_) => _decode(),
                    decoration: InputDecoration(
                      hintText: '$shareScheme://import?d=…',
                      errorText: _error,
                    ),
                  ),
                ],
              ),
              if (preview != null) ...[
                const SizedBox(height: Insets.xl),
                Text(preview.name, style: theme.textTheme.headlineSmall),
                const SizedBox(height: Insets.md),
                RecipeView(
                  recipe: calculate(preview.input),
                  unit: settings.unit,
                  showBakersPercent: settings.showBakersPercent,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
