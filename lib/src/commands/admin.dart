import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:running_on_dart/src/checks.dart';
import 'package:running_on_dart/src/exception.dart';

ChatGroup admin = ChatGroup(
  'admin',
  'Administrative commands',
  checks: [
    administratorCheck,
  ],
  options: CommandsOptions(
    hideOriginalResponse: true,
  ),
  children: [
    ChatCommand(
      'cleanup',
      'Bulk deletes messages in a channel',
      id('admin-cleanup', (
        IChatContext context,
        @UseConverter(IntConverter(min: 1)) @Description('The number of messages to delete') int count, [
        @Description('The user from whom to delete messages') IUser? user,
      ]) async {
        List<IMessage>? channelMessages;
        Snowflake? last;

        while (count > 0 && (channelMessages == null || channelMessages.isNotEmpty)) {
          channelMessages = await context.channel
              .downloadMessages(
                limit: 100,
                after: last,
              )
              .toList();
          last = channelMessages.last.id;

          Iterable<IMessage> toRemove;

          if (user == null) {
            toRemove = channelMessages.take(count);
          } else {
            toRemove = channelMessages.where((message) => message.author.id == user.id);
          }

          try {
            if (toRemove.length == 1) {
              await toRemove.first.delete();
            } else {
              await context.channel.bulkRemoveMessages(toRemove);
            }
          } on IHttpResponseError catch (e) {
            throw CheckedBotException(e.message);
          }

          count -= toRemove.length;
        }

        if (context is InteractionChatContext) {
          await context.respond(MessageBuilder.content('Successfully deleted messages!'), hidden: true);
        } else {
          await context.respond(MessageBuilder.content('Successfully deleted messages!'));
        }
      }),
    ),
  ],
);
