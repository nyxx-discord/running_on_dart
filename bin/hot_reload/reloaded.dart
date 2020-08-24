    import 'package:nyxx/nyxx.dart';
    import 'package:nyxx_commander/commander.dart';

    Future<dynamic> execute(CommandContext ctx) async {
       final message = await ctx.reply(content: "Cool stuff"); return message.createReaction(UnicodeEmoji('👍'));
    }
  