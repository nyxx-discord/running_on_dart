import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:running_on_dart/src/modules/poop_name.dart';

final admin = ChatGroup(
  'admin',
  'Administrative commands',
  children: [
    ChatCommand(
      'cleanup',
      'Bulk deletes messages in a channel',
      id('admin-cleanup', (
        ChatContext context,
        @UseConverter(IntConverter(min: 1)) @Description('The number of messages to delete') int count, [
        @Description('The user from whom to delete messages') User? user,
      ]) async {
        List<Message>? channelMessages;
        Snowflake? last;

        while (count > 0 && (channelMessages == null || channelMessages.isNotEmpty)) {
          channelMessages = await context.channel.messages.fetchMany(
            limit: 100,
            after: last,
          );

          last = channelMessages.last.id;

          Iterable<Message> toRemove;

          if (user == null) {
            toRemove = channelMessages.take(count);
          } else {
            toRemove = channelMessages.where((message) => message.author.id == user.id);
          }

          if (toRemove.length == 1) {
            await toRemove.first.delete();
          } else {
            await context.channel.messages.bulkDelete(toRemove.map((m) => m.id));
          }

          count -= toRemove.length;
        }

        await context.respond(MessageBuilder(content: 'Successfully deleted messages!'));
      }),
      checks: [PermissionsCheck(Permissions.manageMessages)],
      options: CommandsOptions(
        defaultResponseLevel: ResponseLevel.private,
      ),
    ),
    ChatCommand(
        "perform-nickname-pooping",
        "Perform pooping of usernames in current guild",
        id('perform-nickname-pooping', (ChatContext context, [bool dryRun = true, int batchSize = 100]) async {
          var nickNamesToRemove = <String>[];
          for (final disallowedChar in poopCharacters) {
            await for (final member in searchMembers(disallowedChar, batchSize, context.guild!)) {
              final (performed, nick) = await PoopNameModule.instance.poopMember(member, dryRun: dryRun);
              if (performed && (nick ?? '').isNotEmpty) {
                nickNamesToRemove.add(nick!);
              }
            }
          }

          final outPutMessageHeader = "Pooping nicknames ${dryRun ? "[DRY RUN]" : ""}";
          var nickString = nickNamesToRemove.join(",");
          nickString = trimMessageString(nickString);

          var outputMessage = """
$outPutMessageHeader:
```
$nickString
```
""";

          await context.respond(MessageBuilder(content: outputMessage.trim()));
        }),
        checks: [
          GuildCheck.all(),
          PermissionsCheck(Permissions.manageNicknames),
        ],
        options: CommandOptions(autoAcknowledgeInteractions: true))
  ],
);

String trimMessageString(String messageString) {
  if (messageString.isEmpty) {
    return "-/-";
  }

  if (messageString.length > 1950) {
    messageString = "${messageString.substring(0, 1950)} ...";
  }

  return messageString;
}

Stream<Member> searchMembers(String disallowedChar, int batchSize, Guild guild) {
  return (guild.manager.client as NyxxGateway)
      .gateway
      .listGuildMembers(guild.id, query: disallowedChar, limit: batchSize);
}
