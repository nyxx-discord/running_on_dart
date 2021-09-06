import "package:nyxx/nyxx.dart";
import "package:nyxx_commander/commander.dart";
import "package:running_on_dart/src/commands/infoCommon.dart";

Future<void> infoCommand(CommandContext ctx, String content) async {
  await ctx.reply(MessageBuilder.embed(await infoGenericCommand(ctx.client, ctx.shardId)));
}
