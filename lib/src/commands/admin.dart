import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/exception.dart';

ChatGroup admin = ChatGroup(
  'admin',
  'Administrative commands',
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
      checks: [PermissionsCheck(PermissionsConstants.manageMessages)],
      options: CommandsOptions(
        hideOriginalResponse: true,
      ),
    ),
    ChatCommand(
        "perform-nickname-pooping",
        "Perform pooping of usernames in current guild",
        id('perform-nickname-pooping', (IChatContext context, [bool dryRun = true, int batchSize = 100]) async {
          if (context is InteractionChatContext) {
            await context.acknowledge();
          }

          var nickNamesToRemove = <String>[];
          for(final disallowedChar in poopCharacters) {
            await for(final member in context.guild!.searchMembersGateway(disallowedChar, limit: batchSize)) {
              nickNamesToRemove.add(member.nickname ?? member.user.getFromCache()?.username ?? "");

              if (!dryRun) {
                await member.edit(builder: MemberBuilder()..nick = poopEmoji);
              }
            }
          }

          var outputMessage = "Pooping nicknames" + (dryRun ? "[DRY RUN]" : "") + ":\n";
          outputMessage += "```";
          if (nickNamesToRemove.isNotEmpty) {
            for(final nick in nickNamesToRemove) {
              outputMessage += "$nick,";

              if (outputMessage.length > 1950) {
                outputMessage += " ...";
                break;
              }
            }
            outputMessage.replaceRange(outputMessage.length, null, "");
          } else {
            outputMessage += "-/-";
          }
          outputMessage += "```";

          context.respond(MessageBuilder.content(outputMessage));
        }),
        checks: [
          GuildCheck.all(),
          PermissionsCheck(PermissionsConstants.manageNicknames),
        ]
    )
  ],
);
