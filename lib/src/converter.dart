import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:running_on_dart/src/models/feature_settings.dart';

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
