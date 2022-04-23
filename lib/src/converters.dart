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

Converter<DocEntry> docEntryConverter = Converter<DocEntry>(
  (view, context) => DocsService.instance.getByQuery(view.getQuotedWord()),
  autocompleteCallback: (context) => DocsService.instance.search(context.currentValue).take(25).map((e) => ArgChoiceBuilder(e.displayName, e.qualifiedName)),
);

Converter<PackageDocs> packageDocsConverter = Converter<PackageDocs>(
  (view, context) => DocsService.instance.getPackageDocs(view.getQuotedWord()),
  choices: docsPackages.map((packageName) => ArgChoiceBuilder(packageName, packageName)),
);

Converter<Duration> durationConverter = Converter<Duration>(
  (view, context) {
    Duration d = parseStringToDuration(view.getQuotedWord());

    // [parseStringToDuration] returns Duration.zero on parsing failure
    if (d.inMilliseconds > 0) {
      return d;
    }

    return null;
  },
  autocompleteCallback: autocompleteDuration,
);

Iterable<ArgChoiceBuilder> autocompleteDuration(AutocompleteContext context) {
  Iterable<String> clustersSoFar = context.currentValue.split(RegExp(r'((?<=\s)(?=\d))'));

  List<String> options = ['seconds', 'minutes', 'hours', 'days', 'months', 'years'];

  Iterable<String> correct(String current, Iterable<String> nextParts) {
    current = current.trim();
    List<String> currentSplit = current.split(RegExp(r'\s+|(?<=\d)(?=\w)|(?<=\w)(?=\d)'));

    List<String> corrected = [];

    if (current.isEmpty) {
      // Populate the choices with examples.
      corrected.addAll(options.map((suffix) => '1 $suffix'));
    } else if (currentSplit.length >= 2) {
      // Try to fix the current input. If it is already valid, this code does nothing.
      Iterable<String> numbers = currentSplit.takeWhile((value) => RegExp(r'\d+').hasMatch(value));
      String rest = currentSplit.skip(numbers.length).join();

      String number = numbers.join();
      if (number.isEmpty) {
        number = '0';
      }

      String resolvedRest = Fuzzy(options).search(rest).map((result) => result.item).followedBy([rest]).first;

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

  Iterable<ArgChoiceBuilder> result = correct(clustersSoFar.first, clustersSoFar.skip(1)).take(25).map((e) => ArgChoiceBuilder(e, e));

  if (result.isNotEmpty) {
    return result;
  }

  return [ArgChoiceBuilder(context.currentValue, context.currentValue)];
}

Converter<Reminder> reminderConverter = Converter<Reminder>(
  (view, context) => ReminderService.instance.search(context.user.id, view.getQuotedWord()).cast<Reminder?>().followedBy([null]).first,
  autocompleteCallback: (context) => ReminderService.instance
      .search(context.user.id, context.currentValue)
      .take(25)
      .map((e) => '${reminderDateFormat.format(e.triggerAt)}: ${e.message.length > 50 ? e.message.substring(0, 50) + '...' : e.message}')
      .map((e) => ArgChoiceBuilder(e, e)),
);

Converter<Tag> tagConverter = Converter<Tag>(
  (view, context) => TagService.instance.search(view.getQuotedWord(), context.guild?.id ?? Snowflake.zero()).cast<Tag?>().followedBy([null]).first,
  autocompleteCallback: (context) =>
      TagService.instance.search(context.currentValue, context.guild?.id ?? Snowflake.zero()).take(25).map((e) => e.name).map((e) => ArgChoiceBuilder(e, e)),
);

// Needs to be const so we can use @UseConverter
const Converter<Tag> manageableTagConverter = Converter<Tag>(
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

final Converter<Setting<dynamic>> settingsConverter = Converter<Setting<dynamic>>(
  (view, context) {
    String word = view.getQuotedWord();

    return Setting.values.firstWhere((setting) => setting.value == word);
  },
  choices: Setting.values.map((setting) => ArgChoiceBuilder('${setting.value}: ${setting.description}', setting.value)),
);
