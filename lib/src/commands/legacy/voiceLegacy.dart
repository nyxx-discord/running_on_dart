import "package:nyxx/nyxx.dart";
import "package:nyxx_commander/commander.dart";
import "package:running_on_dart/src/commands/voiceCommon.dart";

Future<void> leaveChannelCommand(CommandContext ctx, String content) async {
  await leaveChannel(ctx.guild!.id, ctx.client);
  await ctx.sendMessage(MessageBuilder.content("Left channel!"));
}

Future<void> joinChannelCommand(CommandContext ctx, String content) async {
  await joinChannel(ctx.guild!.id, Snowflake(content.split(" ").last), ctx.client);
  await ctx.sendMessage(MessageBuilder.content("Joined to channel!"));
}
