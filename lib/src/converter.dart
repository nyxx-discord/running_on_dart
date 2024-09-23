import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
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
