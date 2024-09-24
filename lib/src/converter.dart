import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/models/docs.dart';
import 'package:running_on_dart/src/models/feature_settings.dart';
import 'package:running_on_dart/src/services/tag.dart';

import 'models/tag.dart';

final settingsConverter = Converter<Setting>(
  (view, context) {
    final word = view.getQuotedWord();

    try {
      return Setting.values.firstWhere((setting) => setting.name == word);
    } on StateError {
      return null;
    }
  },
  choices: Setting.values.map((setting) => CommandOptionChoiceBuilder(name: setting.name, value: setting.name)),
);

// Needs to be const so we can use @UseConverter
const manageableTagConverter = Converter<Tag>(
  getManageableTag,
  autocompleteCallback: autocompleteManageableTag,
);

Tag? getManageableTag(StringView view, ContextData context) => TagService.instance
    .search(
      view.getQuotedWord(),
      context.guild?.id ?? Snowflake.zero,
      context.user.id,
    )
    .cast<Tag?>()
    .followedBy([null]).first;

Iterable<CommandOptionChoiceBuilder<dynamic>> autocompleteManageableTag(AutocompleteContext context) =>
    TagService.instance
        .search(
          context.currentValue,
          context.guild?.id ?? Snowflake.zero,
          context.user.id,
        )
        .take(25)
        .map((e) => e.name)
        .map((e) => CommandOptionChoiceBuilder(name: e, value: e));

/// Search autocomplete, but only include elements from a given package (if there is one selected).
Iterable<CommandOptionChoiceBuilder<dynamic>> autocompleteQueryWithPackage(AutocompleteContext context) {
  final selectedPackageName = (context.option.options ?? [])
      .cast<InteractionOption?>() // Cast to IInteractionOption? so we can return `null` in orElse
      .firstWhere((element) => element?.name == 'package', orElse: () => null)
      ?.value
      ?.toString();

  PackageDocs? selectedPackage;
  if (selectedPackageName != null) {
    selectedPackage = DocsModule.instance.getPackageDocs(selectedPackageName);
  }

  return [
    // Allow the user to select their current value
    if (context.currentValue.isNotEmpty)
      CommandOptionChoiceBuilder(name: context.currentValue, value: context.currentValue),
    ...DocsModule.instance
        .search(context.currentValue, selectedPackage)
        .take(context.currentValue.isEmpty ? 25 : 24)
        .map((e) => CommandOptionChoiceBuilder(name: e.displayName, value: e.qualifiedName)),
  ];
}
