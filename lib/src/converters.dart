import 'package:fuzzy/fuzzy.dart';
import 'package:human_duration_parser/human_duration_parser.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/models/docs.dart';

Converter<DocEntry> docEntryConverter = Converter<DocEntry>(
  (view, context) => getByQuery(view.getQuotedWord()),
  autocompleteCallback: (context) => searchInDocs(context.currentValue).take(25).map((e) => ArgChoiceBuilder(e.displayName, e.qualifiedName)),
);

Converter<PackageDocs> packageDocsConverter = Converter<PackageDocs>(
  (view, context) => getPackageDocs(view.getQuotedWord()),
  choices: docsPackages.map((packageName) => ArgChoiceBuilder(packageName, packageName)),
);

Converter<Duration> durationConverter = Converter<Duration>(
  (view, context) => parseStringToDuration(view.getQuotedWord()),
  autocompleteCallback: autocompleteDuration,
);

Iterable<ArgChoiceBuilder> autocompleteDuration(AutocompleteContext context) {
  Iterable<String> clustersSoFar = context.currentValue.split(RegExp(r'((?<=\s)(?=\d))'));

  List<String> options = ['seconds', 'minutes', 'hours', 'days', 'months', 'years'];

  Iterable<String> correct(String current, Iterable<String> nextParts) {
    current = current.trim();
    List<String> currentSplit = current.split(RegExp(r'\s+'));

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
