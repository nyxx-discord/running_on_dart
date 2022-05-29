import 'package:fuzzy/fuzzy.dart';
import 'package:human_duration_parser/human_duration_parser.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/models/docs.dart';
import 'package:running_on_dart/src/models/guild_settings.dart';
import 'package:running_on_dart/src/models/reminder.dart';
import 'package:running_on_dart/src/models/tag.dart';
import 'package:running_on_dart/src/services/reminder.dart';

final docEntryConverter = Converter<DocEntry>(
  (view, context) => DocsService.instance.getByQuery(view.getQuotedWord()),
  autocompleteCallback: (context) => DocsService.instance.search(context.currentValue).take(25).map((e) => ArgChoiceBuilder(e.displayName, e.qualifiedName)),
);

final packageDocsConverter = Converter<PackageDocs>(
  (view, context) => DocsService.instance.getPackageDocs(view.getQuotedWord()),
  choices: docsPackages.map((packageName) => ArgChoiceBuilder(packageName, packageName)),
);

final durationConverter = Converter<Duration>(
  (view, context) {
    final duration = parseStringToDuration(view.getQuotedWord());

    // [parseStringToDuration] returns Duration.zero on parsing failure
    if (duration.inMilliseconds > 0) {
      return duration;
    }

    return null;
  },
  autocompleteCallback: autocompleteDuration,
);

Iterable<ArgChoiceBuilder> autocompleteDuration(AutocompleteContext context) {
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

  final result = correct(clustersSoFar.first, clustersSoFar.skip(1)).take(25).map((e) => ArgChoiceBuilder(e, e));

  if (result.isNotEmpty) {
    return result;
  }

  return [ArgChoiceBuilder(context.currentValue, context.currentValue)];
}

final reminderConverter = Converter<Reminder>(
  (view, context) => ReminderService.instance.search(context.user.id, view.getQuotedWord()).cast<Reminder?>().followedBy([null]).first,
  autocompleteCallback: (context) => ReminderService.instance
      .search(context.user.id, context.currentValue)
      .take(25)
      .map((e) => '${reminderDateFormat.format(e.triggerAt)}: ${e.message.length > 50 ? e.message.substring(0, 50) + '...' : e.message}')
      .map((e) => ArgChoiceBuilder(e, e)),
);

final tagConverter = Converter<Tag>(
  (view, context) => TagService.instance.search(view.getQuotedWord(), context.guild?.id ?? Snowflake.zero()).cast<Tag?>().followedBy([null]).first,
  autocompleteCallback: (context) =>
      TagService.instance.search(context.currentValue, context.guild?.id ?? Snowflake.zero()).take(25).map((e) => e.name).map((e) => ArgChoiceBuilder(e, e)),
);

// Needs to be const so we can use @UseConverter
const manageableTagConverter = Converter<Tag>(
  getManageableTag,
  autocompleteCallback: autocompleteManageableTag,
);

Tag? getManageableTag(StringView view, IChatContext context) => TagService.instance
    .search(
      view.getQuotedWord(),
      context.guild?.id ?? Snowflake.zero(),
      context.user.id,
    )
    .cast<Tag?>()
    .followedBy([null]).first;

Iterable<ArgChoiceBuilder> autocompleteManageableTag(AutocompleteContext context) => TagService.instance
    .search(
      context.currentValue,
      context.guild?.id ?? Snowflake.zero(),
      context.user.id,
    )
    .take(25)
    .map((e) => e.name)
    .map((e) => ArgChoiceBuilder(e, e));

final settingsConverter = Converter<Setting<dynamic>>(
  (view, context) {
    final word = view.getQuotedWord();

    return Setting.values.cast<Setting<dynamic>?>().firstWhere((setting) => setting!.value == word, orElse: () => null);
  },
  choices: Setting.values.map((setting) => ArgChoiceBuilder('${setting.value}: ${setting.description}', setting.value)),
);
