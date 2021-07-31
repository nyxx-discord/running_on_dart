import "package:nyxx/nyxx.dart";
import "package:nyxx_commander/commander.dart";

import '../utils/db/db.dart' as db;

// Future<void> openDb() async {
//   await db.RodDb.openDatabase();
// }
//
// Future<void> processMessage(MessageReceivedEvent messageReceivedEvent) async {
//   final message = messageReceivedEvent.message;
//
//   if (message.author.bot) {
//     return;
//   }
//
//   final channelHasEnabledTags = await db.RodDb.channelStore.hasEnabledTags(message.channel.id.toString());
//   if (!channelHasEnabledTags) {
//     return;
//   }
//
//   final result = await db.RodDb.tagStore.matchInString(message.content);
//
//   if (result == null) {
//     return;
//   }
//
//   await message.channel.sendMessage(MessageBuilder.content(result));
// }
//
// Future<void> tagsEnableCommand(CommandContext ctx, String content) async {
//   final result = await db.RodDb.channelStore.insert(ctx.channel.id.toString());
//
//   await ctx.reply(MessageBuilder.content("result: $result"));
// }
//
// Future<void> addTagCommand(CommandContext ctx, String content) async {
//   final args = ctx.getArguments();
//
//   final name = args.first;
//   final content = args.last;
//
//   final result = await db.RodDb.tagStore.insert(name, content);
//
//   await ctx.reply(MessageBuilder.content("result: $result"));
// }
