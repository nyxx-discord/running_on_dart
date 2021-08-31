import "package:nyxx_commander/commander.dart";
import "package:running_on_dart/src/commands/docsCommon.dart";

Future<void> docsGetCommand(CommandContext ctx, String content) async {
  await ctx.sendMessage(await docsGetMessageBuilder(content));
}

Future<void> docsSearchCommand(CommandContext ctx, String content) async {
  await ctx.sendMessage(await docsSearchMessageBuilder(content));
}

Future<void> docsCommand(CommandContext ctx, String content) async {
  await ctx.sendMessage(await docsLinksMessageBuilder());
}
