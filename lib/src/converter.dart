import 'package:fuzzy/fuzzy.dart';
import 'package:human_duration_parser/human_duration_parser.dart';
import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:running_on_dart/src/models/docs.dart';
import 'package:running_on_dart/src/models/feature_settings.dart';
import 'package:running_on_dart/src/models/jellyfin_config.dart';
import 'package:running_on_dart/src/models/reminder.dart';
import 'package:running_on_dart/src/modules/docs.dart';
import 'package:running_on_dart/src/modules/reminder.dart';
import 'package:running_on_dart/src/modules/tag.dart';
import 'package:running_on_dart/src/repository/jellyfin_config.dart';
import 'package:running_on_dart/src/settings.dart';

import 'models/tag.dart';

final packageDocsConverter = Converter<PackageDocs>(
  (view, context) => Injector.appInstance.get<DocsModule>().getPackageDocs(view.getQuotedWord()),
  choices: docsPackages.map((packageName) => CommandOptionChoiceBuilder(name: packageName, value: packageName)),
);

final reminderConverter = Converter<Reminder>(
  (view, context) =>
      Injector.appInstance.get<ReminderModule>().search(context.user.id, view.getQuotedWord()).firstOrNull,
  autocompleteCallback: (context) => Injector.appInstance
      .get<ReminderModule>()
      .search(context.user.id, context.currentValue)
      .take(25)
      .map((e) =>
          '${reminderDateFormat.format(e.triggerAt)}: ${e.message.length > 50 ? '${e.message.substring(0, 50)}...' : e.message}')
      .map((e) => CommandOptionChoiceBuilder(name: e, value: e)),
);

final durationConverter = Converter<Duration>(
  (view, context) {
    final duration = parseStringToDuration(view.getQuotedWord());
    if (duration == null) {
      return null;
    }

    if (duration.inSeconds <= 0) {
      return null;
    }

    return duration;
  },
  autocompleteCallback: autocompleteDuration,
);

String stringifySetting(Setting setting) => setting.name;
const settingsConverter = SimpleConverter.fixed(elements: Setting.values, stringify: stringifySetting);

Iterable<Tag> getManageableTags(ContextData context) =>
    Injector.appInstance.get<TagModule>().findAll(context.guild?.id ?? Snowflake.zero, context.user.id);
String stringifyTag(Tag tag) => tag.name;

const manageableTagConverter = SimpleConverter<Tag>(
  provider: getManageableTags,
  stringify: stringifyTag,
);

Future<Iterable<JellyfinConfig>> getJellyfinConfigs(ContextData context) =>
    Injector.appInstance.get<JellyfinConfigRepository>().getConfigsForGuild(context.guild!.id);

String stringifyJellyfinConfig(JellyfinConfig config) => config.name;

const jellyfinConfigConverter =
    SimpleConverter<JellyfinConfig>(provider: getJellyfinConfigs, stringify: stringifyJellyfinConfig);

/// Search autocomplete, but only include elements from a given package (if there is one selected).
Iterable<CommandOptionChoiceBuilder<dynamic>> autocompleteQueryWithPackage(AutocompleteContext context) {
  final selectedPackageName = context.arguments['package'];

  PackageDocs? selectedPackage;
  if (selectedPackageName != null) {
    selectedPackage = Injector.appInstance.get<DocsModule>().getPackageDocs(selectedPackageName);
  }

  return [
    // Allow the user to select their current value
    if (context.currentValue.isNotEmpty)
      CommandOptionChoiceBuilder(name: context.currentValue, value: context.currentValue),
    ...Injector.appInstance
        .get<DocsModule>()
        .search(context.currentValue, selectedPackage)
        .take(context.currentValue.isEmpty ? 25 : 24)
        .map((e) => CommandOptionChoiceBuilder(name: e.displayName, value: e.qualifiedName)),
  ];
}

Iterable<CommandOptionChoiceBuilder<dynamic>> autocompleteDuration(AutocompleteContext context) {
  final clustersSoFar = context.currentValue.split(RegExp(r'((?<=\s)(?=\d))'));
  final options = ['seconds', 'minutes', 'hours', 'days', 'months', 'years'];

  Iterable<String> correct(String current, Iterable<String> nextParts) {
    current = current.trim();
    final currentSplit = current.split(RegExp(r'\s+|(?<=\d)(?=\w)|(?<=\w)(?=\d)'));
    final corrected = <String>[];

    if (current.isEmpty) {
      // Populate the choices with examples.
      corrected.addAll(options.map((suffix) => '1 $suffix'));
    } else if (currentSplit.length >= 2) {
      // Try to fix the current input. If it is already valid, this code does nothing.
      final numbers = currentSplit.takeWhile((value) => RegExp(r'\d+').hasMatch(value));
      final rest = currentSplit.skip(numbers.length).join();

      var number = numbers.join();
      if (number.isEmpty) {
        number = '0';
      }

      final resolvedRest = Fuzzy(options).search(rest).map((result) => result.item).followedBy([rest]).first;

      corrected.add('$number $resolvedRest');
    } else if (RegExp(r'\d$').hasMatch(current)) {
      corrected.addAll(options.map((suffix) => '$current $suffix'));
    }

    if (nextParts.isEmpty) {
      return corrected;
    }

    return corrected
        // Expand each corrected part with all possible corrections to the following parts
        .expand((correctedStart) => correct(nextParts.first, nextParts.skip(1)).map(
              (correctedEnd) => '$correctedStart $correctedEnd'.trim(),
            ));
  }

  final result = correct(clustersSoFar.first, clustersSoFar.skip(1))
      .take(25)
      .map((e) => CommandOptionChoiceBuilder(name: e, value: e));

  if (result.isNotEmpty) {
    return result;
  }

  return [CommandOptionChoiceBuilder(name: context.currentValue, value: context.currentValue)];
}
