import "package:nyxx/nyxx.dart" show MessageBuilder;
import "package:nyxx_commander/commander.dart" show CommandContext;
import "package:running_on_dart/src/commands/info_common.dart" show infoGenericCommand;

Future<void> infoCommand(CommandContext ctx, String content) async {
  await ctx.reply(MessageBuilder.embed(await infoGenericCommand(ctx.client, ctx.shardId)));
}
