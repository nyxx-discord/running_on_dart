import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:postgres/postgres.dart';
import 'package:running_on_dart/src/models/mod_log.dart';
import 'package:running_on_dart/src/services/db.dart';
import 'package:running_on_dart/src/util/query_builder.dart';

class ModLogsRepository {
  final _database = Injector.appInstance.get<DatabaseService>();

  Future<void> save(ModLogEntry entry) async {
    final query = InsertQuery('mod_logs')
      ..addNamedInsert('guild_id')
      ..addNamedInsert('message_id')
      ..addNamedInsert('action_type')
      ..addNamedInsert('target_user_id')
      ..addNamedInsert('moderator_user_id')
      ..addNamedInsert('reason')
      ..addNamedInsert('created_at')
      ..addNamedInsert('updated_at')
      ..addNamedInsert('updated_by')
      ..addNamedInsert('additional_data');

    await _database.executeQuery(
      query,
      parameters: {
        'guild_id': entry.guildId.toString(),
        'message_id': entry.messageId.toString(),
        'action_type': entry.actionType,
        'target_user_id': entry.targetUserId.toString(),
        'moderator_user_id': entry.moderatorUserId.toString(),
        'reason': entry.reason,
        'created_at': entry.createdAt.toUtc(),
        'updated_at': entry.updatedAt?.toUtc(),
        'updated_by': entry.updatedBy?.toString(),
        'additional_data': entry.additionalData,
      },
    );
  }

  Future<ModLogEntry?> findLatestForGuild(Snowflake guildId) async {
    final result = await _database.getConnection().execute(
      Sql.named('SELECT * FROM mod_logs WHERE guild_id = @guildId ORDER BY created_at DESC LIMIT 1'),
      parameters: {'guildId': guildId.toString()},
    );

    if (result.isEmpty) {
      return null;
    }

    return ModLogEntry.fromDatabaseRow(result.first.toColumnMap());
  }

  Future<void> updateReason(int id, String reason, Snowflake updatedBy) async {
    await _database.getConnection().execute(
      Sql.named('UPDATE mod_logs SET reason = @reason, updated_at = NOW(), updated_by = @updatedBy WHERE id = @id'),
      parameters: {'id': id, 'reason': reason, 'updatedBy': updatedBy.toString()},
    );
  }
}
