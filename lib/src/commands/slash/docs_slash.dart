import "package:nyxx_interactions/nyxx_interactions.dart";
import "package:running_on_dart/src/commands/docs_common.dart" show docsGetMessageBuilder, docsLinksMessageBuilder, docsSearchMessageBuilder;

Future<void> docsGetSlashHandler(ISlashCommandInteractionEvent event) async {
  await event.acknowledge();

  await event.respond(await docsGetMessageBuilder(event.args.firstWhere((element) => element.name == "phrase").value.toString()));
}

Future<void> docsSearchHandler(ISlashCommandInteractionEvent event) async {
  await event.acknowledge();

  await event.respond(await docsSearchMessageBuilder(event.args.firstWhere((element) => element.name == "phrase").value.toString()));
}

Future<void> docsLinksHandler(ISlashCommandInteractionEvent event) async {
  await event.respond(await docsLinksMessageBuilder());
}
