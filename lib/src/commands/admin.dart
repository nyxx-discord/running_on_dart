import 'package:collection/collection.dart';
import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_extensions/nyxx_extensions.dart';
import 'package:running_on_dart/src/checks.dart';
import 'package:running_on_dart/src/modules/poop_name.dart';
import 'package:running_on_dart/src/init.dart';
import 'package:running_on_dart/src/util/util.dart';

Stream<Member> searchMembers(String disallowedChar, int batchSize, Guild guild) {
  return (guild.manager.client as NyxxGateway).gateway.listGuildMembers(
    guild.id,
    query: disallowedChar,
    limit: batchSize,
  );
}

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

        await Future.wait(messagesToDelete.where((m) => !m.id.isBefore(Snowflake.firstBulk())).map((m) => m.delete()));

        await context.respond(MessageBuilder(content: 'Successfully deleted messages!'));
      }),
      checks: [PermissionsCheck(Permissions.manageMessages)],
      options: CommandsOptions(defaultResponseLevel: ResponseLevel.private),
    ),
    ChatCommand(
      "perform-nickname-pooping",
      "Perform pooping of usernames in current guild",
      id('perform-nickname-pooping', (ChatContext context, [int batchSize = 10]) async {
        final poopModule = Injector.appInstance.get<PoopNameModule>();

        final membersToPoop = <Member>[];
        for (final disallowedChar in minimalPoopCharacters) {
          await for (final member in searchMembers(disallowedChar, batchSize, context.guild!)) {
            final shouldBePooped = await poopModule.poopMember(member, dryRun: true);
            if (shouldBePooped) {
              membersToPoop.add(member);
            }
          }
        }

        if (membersToPoop.isEmpty) {
          return context.respond(MessageBuilder(content: 'No members to poop...'));
        }

        final multiSelectResult = await context.getMultiSelection(
          membersToPoop,
          MessageBuilder(content: 'Performing members pooping...'),
          toSelectMenuOption: (value) =>
              SelectMenuOptionBuilder(label: poopModule.getMemberNameForPooping(value)!, value: value.id.toString()),
        );

        for (final member in multiSelectResult) {
          poopModule.poopMember(member, dryRun: false);
        }

        await context.respond(
          MessageBuilder(
            content:
                'Pooped members: ${multiSelectResult.map((value) => poopModule.getMemberNameForPooping(value)).map((v) => '`$v`').join(', ')}',
          ),
        );
      }),
      checks: [GuildCheck.all(), PermissionsCheck(Permissions.manageNicknames)],
    ),
    ChatGroup(
      "system",
      "System administration commands",
      checks: [administratorCheck, administratorGuildCheck],
      children: [
        ChatCommand(
          'reload-modules',
          'Reload modules',
          id('admin-reload-modules', (InteractionChatContext context) async {
            final modulesToReload = await context.getMultiSelection(
              reloadableModules.keys.toList(),
              MessageBuilder(content: 'Select modules to reload'),
              toSelectMenuOption: (value) => SelectMenuOptionBuilder(label: value, value: value),
            );

            final stopwatch = Stopwatch()..start();
            final reloadFunctions = modulesToReload
                .map((m) => reloadableModules[m])
                .nonNulls
                .map((m) => m())
                .map((r) => r.reload());
            await Future.wait(reloadFunctions);

            return context.respond(
              MessageBuilder(
                content: 'Reloaded ${reloadFunctions.length} modules. Took ${stopwatch.elapsed.formatShort()}',
              ),
            );
          }),
        ),
      ],
    ),
  ],
);
