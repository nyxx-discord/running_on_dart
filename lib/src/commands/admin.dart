import 'package:collection/collection.dart';
import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_extensions/nyxx_extensions.dart';
import 'package:running_on_dart/src/checks.dart';
import 'package:running_on_dart/src/modules/poop_name.dart';
import 'package:running_on_dart/src/modules/mod_log.dart';
import 'package:running_on_dart/src/init.dart';
import 'package:running_on_dart/src/util/util.dart';
import 'package:running_on_dart/src/services/db.dart';
import 'package:running_on_dart/src/util/sql_result_formatter.dart';

Stream<Member> searchMembers(String disallowedChar, int batchSize, Guild guild) {
  return (guild.manager.client as NyxxGateway).gateway.listGuildMembers(
    guild.id,
    query: disallowedChar,
    limit: batchSize,
  );
}

final poopUserCommand = UserCommand("poop-username", (UserContext context) async {
  final member = context.targetMember;
  if (member == null) {
    return context.respond(
      MessageBuilder(content: "This command can only be used on guild members."),
      level: ResponseLevel.private,
    );
  }

  final poopModule = Injector.appInstance.get<PoopNameModule>();

  final result = await poopModule.poopMember(member, dryRun: false);

  await context.respond(MessageBuilder(content: result ? 'Done...' : 'Not needed...'), level: ResponseLevel.private);
}, checks: [GuildCheck.all(), PermissionsCheck(Permissions.manageNicknames)]);

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
      'reason',
      'Update latest mod log entry with reason',
      id('admin-reason', (
        ChatContext context,
        @Description('Reason to set in latest mod log entry') String reason,
      ) async {
        final modLogsModule = Injector.appInstance.get<ModLogsModule>();
        final updated = await modLogsModule.updateLatestLogReason(context.guild!.id, reason, context.user.id);

        final response = updated
            ? 'Updated latest mod log entry with reason.'
            : 'Cannot update mod log entry. Ensure mod logs are enabled and a recent entry exists.';

        await context.respond(MessageBuilder(content: response), level: ResponseLevel.private);
      }),
      checks: [GuildCheck.all(), PermissionsCheck(Permissions.manageGuild)],
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
    ChatCommand(
      'ban',
      'Ban a user from the guild',
      id('admin-ban', (
        ChatContext context,
        @Description('The user to ban') User user,
        @Description('The reason for the ban') String reason, [
        @Description('Remove messages from x days. Default 3. 0 disables') int deleteMessagesDays = 3,
      ]) async {
        if (deleteMessagesDays > 7 || deleteMessagesDays < 0) {
          await context.respond(
            MessageBuilder(content: 'deleteMessagesDays must be between 1 and 7 days. 0 disables feature.'),
            level: ResponseLevel.private,
          );
          return;
        }

        Duration? deleteMessages;
        if (deleteMessagesDays > 0) {
          deleteMessages = Duration(days: deleteMessagesDays);
        }

        try {
          await context.guild!.createBan(user.id, deleteMessages: deleteMessages, auditLogReason: reason);
          await context.respond(
            MessageBuilder(content: 'Successfully banned ${user.mention} for: $reason'),
            level: ResponseLevel.private,
          );
        } catch (e) {
          await context.respond(MessageBuilder(content: 'Failed to ban user: $e'), level: ResponseLevel.private);
        }
      }),
      checks: [GuildCheck.all(), PermissionsCheck(Permissions.banMembers)],
      options: CommandsOptions(defaultResponseLevel: ResponseLevel.private),
    ),
    ChatCommand(
      'kick',
      'Kick a user from the guild',
      id('admin-kick', (
        ChatContext context,
        @Description('The user to kick') User user,
        @Description('The reason for the kick') String reason,
      ) async {
        try {
          await context.guild!.members.delete(user.id, auditLogReason: reason);
          await context.respond(
            MessageBuilder(content: 'Successfully kicked ${user.mention} for: $reason'),
            level: ResponseLevel.private,
          );
        } catch (e) {
          await context.respond(MessageBuilder(content: 'Failed to kick user: $e'), level: ResponseLevel.private);
        }
      }),
      checks: [GuildCheck.all(), PermissionsCheck(Permissions.kickMembers)],
      options: CommandsOptions(defaultResponseLevel: ResponseLevel.private),
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
        ChatCommand(
          'sql',
          'Execute a SQL query',
          id('admin-sql', (
            ChatContext context,
            @Description('SQL query to execute') String query, [
            @Description('Set to false to show response publicly') bool private = true,
          ]) async {
            final db = Injector.appInstance.get<DatabaseService>();
            final responseLevel = private ? ResponseLevel.private : ResponseLevel.public;

            try {
              final result = await db.getConnection().execute(query);

              final table = formatSqlResult(result);
              final truncated = table.length > 3900 ? '${table.substring(0, 3900)}... (truncated)' : table;

              await context.respond(MessageBuilder(content: '```\n$truncated\n```'), level: responseLevel);
            } catch (e) {
              await context.respond(MessageBuilder(content: 'Error executing query: $e'), level: responseLevel);
            }
          }),
        ),
      ],
    ),
  ],
);
