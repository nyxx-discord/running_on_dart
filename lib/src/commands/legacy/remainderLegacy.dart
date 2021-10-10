import "package:human_duration_parser/human_duration_parser.dart";
import "package:nyxx/nyxx.dart";
import "package:nyxx_commander/commander.dart";
import "package:running_on_dart/src/modules/reminder/reminder.dart";

Future<void> remainderCommand(CommandContext ctx, String content) async {
  final argString = ctx.getArguments().join(" ");

  if (argString.isEmpty) {
    await ctx.reply(MessageBuilder.content("Provide duration when remainder should be triggered"));
    return;
  }

  final triggerDate = DateTime.now().add(parseStringToDuration(argString));
  final replyMessage = ctx.message.referencedMessage?.message?.url;

  if (replyMessage == null) {
    await ctx.reply(MessageBuilder.content("Reply to message to create remainder"));
    return;
  }

  final result = await createReminder(ctx.author.id, ctx.channel.id, triggerDate, replyMessage);

  if (result) {
    await ctx.reply(MessageBuilder.content("All right, <t:${triggerDate.millisecondsSinceEpoch ~/ 1000}:R> will remind about: $replyMessage"));
    return;
  }

  await ctx.reply(MessageBuilder.content("Internal server error. Report to developer"));
}
