import 'package:collection/collection.dart';
import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_extensions/nyxx_extensions.dart';
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
        final messagesToDelete = await context.channel.messages
            .stream()
            .where((m) => user == null || user.id == m.author.id)
            .take(count)
            .toList();

        await Future.wait(
          messagesToDelete
              .where((m) => m.id.isBefore(Snowflake.firstBulk()))
              .map((m) => m.id)
              .slices(200)
              .map((m) => context.channel.messages.bulkDelete(m)),
        );

        await Future.wait(
          messagesToDelete.where((m) => !m.id.isBefore(Snowflake.firstBulk())).map((m) => m.delete()),
        );

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
          final poopModule = Injector.appInstance.get<PoopNameModule>();

          var nickNamesToRemove = <String>[];
          for (final disallowedChar in poopCharacters) {
            await for (final member in searchMembers(disallowedChar, batchSize, context.guild!)) {
              final (performed, nick) = await poopModule.poopMember(member, dryRun: dryRun);
              if (performed && (nick ?? '').isNotEmpty) {
                nickNamesToRemove.add(nick!);
              }
            }
          }

          final outPutMessageHeader = "Pooping nicknames ${dryRun ? "[DRY RUN]" : ""}";
          final messageBuilder = await createMessageBuilder(nickNamesToRemove.join(","), outPutMessageHeader);

          await context.respond(messageBuilder);
        }),
        checks: [
          GuildCheck.all(),
          PermissionsCheck(Permissions.manageNicknames),
        ])
  ],
);

Future<MessageBuilder> createMessageBuilder(String messageString, String messageHeader) async {
  if (messageString.isEmpty) {
    return MessageBuilder(content: "-/-");
  }

  return pagination.split(messageString, buildChunk: (String chunk) => MessageBuilder(content: """
$messageHeader:
```
$chunk
```
"""));
}

Stream<Member> searchMembers(String disallowedChar, int batchSize, Guild guild) {
  return (guild.manager.client as NyxxGateway)
      .gateway
      .listGuildMembers(guild.id, query: disallowedChar, limit: batchSize);
}
