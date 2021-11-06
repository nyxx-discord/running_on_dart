import "package:nyxx_commander/nyxx_commander.dart";
import "package:running_on_dart/src/commands/docs_common.dart" show docsGetMessageBuilder, docsLinksMessageBuilder, docsSearchMessageBuilder;

Future<void> docsGetCommand(ICommandContext ctx, String content) async {
  await ctx.sendMessage(await docsGetMessageBuilder(content));
}

Future<void> docsSearchCommand(ICommandContext ctx, String content) async {
  await ctx.sendMessage(await docsSearchMessageBuilder(content));
}

Future<void> docsCommand(ICommandContext ctx, String content) async {
  await ctx.sendMessage(await docsLinksMessageBuilder());
}
