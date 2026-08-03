/// Sharing a recipe three ways: as readable text, as a link that reopens it in
/// the app, and as a JSON file for backup.
///
/// Everything here is pure string work so it can be unit tested; actually
/// handing bytes to the OS lives in the UI layer.
library;

import 'dart:convert';

import '../core/formatting.dart';
import '../domain/calculator.dart';
import '../domain/models/recipe.dart';
import '../domain/models/recipe_input.dart';
import '../domain/models/saved_recipe.dart';
import '../domain/validation.dart';

const shareScheme = 'bakerscalc';

/// A recipe formatted for a message or a notes app. Percentages are included
/// because that is what makes a shared recipe rescalable by whoever gets it.
String toPlainText(SavedRecipe saved, MassUnit unit) {
  final input = saved.input;
  if (validate(input).hasErrors) {
    return '${saved.name}\n(This recipe is missing some values.)';
  }
  final recipe = calculate(input);
  final buffer = StringBuffer()
    ..writeln(saved.name)
    ..writeln(
      '${input.style.label} · ${formatPercent(recipe.hydration)} hydration'
      '${input.loaves > 1 ? ' · ${input.loaves} loaves' : ''}',
    )
    ..writeln();

  for (final group in recipe.groups) {
    buffer.writeln('${group.name.toUpperCase()} — ${formatMass(group.grams, unit)}');
    for (final ingredient in group.ingredients) {
      buffer.writeln('  ${_line(ingredient, unit)}');
    }
    buffer.writeln();
  }

  buffer.writeln('Total dough ${formatMass(recipe.totalWeight, unit)}');
  if (saved.notes != null && saved.notes!.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln(saved.notes);
  }
  return buffer.toString();
}

String _line(Ingredient ingredient, MassUnit unit) {
  final amount = ingredient.count != null
      ? '${formatCount(ingredient.count!, 'egg', 'eggs')} (${formatMass(ingredient.grams, unit)})'
      : formatMass(ingredient.grams, unit);
  final percent = ingredient.bakersPercent == null
      ? ''
      : ' · ${formatPercent(ingredient.bakersPercent!)}';
  return '${ingredient.name}: $amount$percent';
}

/// The full recipe as a JSON document, for file export and backup.
String toJsonDocument(SavedRecipe recipe) =>
    const JsonEncoder.withIndent('  ').convert({
      'version': 1,
      'recipes': [recipe.toJson()],
    });

/// `bakerscalc://import?d=<base64url>` — opening it on a device with the app
/// installed adds the recipe.
///
/// Only the name and the input travel; timestamps, favourite state and the id
/// belong to whoever saves it, not to the sender.
Uri toShareLink(SavedRecipe recipe) {
  final payload = base64Url.encode(
    utf8.encode(jsonEncode({'n': recipe.name, 'i': recipe.input.toJson()})),
  );
  return Uri(scheme: shareScheme, host: 'import', queryParameters: {'d': payload});
}

class ImportedRecipe {
  const ImportedRecipe({required this.name, required this.input});

  final String name;
  final RecipeInput input;
}

/// Decodes a share payload. Throws [FormatException] on anything malformed —
/// this is untrusted input and the caller must handle failure.
ImportedRecipe decodeSharePayload(String payload) {
  late final Map<String, dynamic> decoded;
  try {
    decoded =
        jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(payload))))
            as Map<String, dynamic>;
  } on Object catch (e) {
    throw FormatException('That link is not a recipe: $e');
  }

  final input = RecipeInput.fromJson(decoded['i'] as Map<String, dynamic>);
  final issues = validate(input);
  if (issues.hasErrors) {
    throw FormatException(
      'That recipe has values this app cannot use: '
      '${issues.where((i) => i.severity == IssueSeverity.error).map((i) => i.message).join(', ')}',
    );
  }
  return ImportedRecipe(
    name: (decoded['n'] as String?)?.trim().isNotEmpty == true
        ? decoded['n'] as String
        : 'Imported recipe',
    input: input,
  );
}

/// Accepts a full share link or a bare payload pasted on its own, so someone
/// can paste whichever part of the message they happened to select.
ImportedRecipe decodeShareInput(String raw) {
  final trimmed = raw.trim();
  final uri = Uri.tryParse(trimmed);
  final payload = uri?.queryParameters['d'] ?? trimmed;
  return decodeSharePayload(payload);
}
