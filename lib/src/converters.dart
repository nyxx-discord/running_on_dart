import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/models/docs.dart';

Converter<DocEntry> docEntryConverter = Converter<DocEntry>(
  (view, context) => getByQuery(view.getQuotedWord()),
  autocompleteCallback: (context) => searchInDocs(context.currentValue).take(25).map((e) => ArgChoiceBuilder(e.displayName, e.qualifiedName)),
);
