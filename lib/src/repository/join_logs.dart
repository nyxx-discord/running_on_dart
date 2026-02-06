import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:postgres/postgres.dart';
import 'package:running_on_dart/src/models/join_logs.dart';
import 'package:running_on_dart/src/services/db.dart';
import 'package:running_on_dart/src/util/query_builder.dart';

class JoinLogsRepository {
  final _database = Injector.appInstance.get<DatabaseService>();

  Future<void> save(JoinLogEntry joinLogEntry) async {
    final query = InsertQuery('join_logs')
      ..addNamedInsert('user_id')
      ..addNamedInsert('guild_id')
      ..addNamedInsert('message_id')
      ..addNamedInsert('created_at');

    await _database.executeQuery(
      query,
      parameters: {
        'user_id': joinLogEntry.userId.toString(),
        'guild_id': joinLogEntry.guildId.toString(),
        'message_id': joinLogEntry.messageId.toString(),
        'created_at': joinLogEntry.createdAt.toUtc(),
      },
    );
  }

  Future<JoinLogEntry?> findJoinLog(Snowflake userId, Snowflake guildId) async {
    final result = await _database.getConnection().execute(
      Sql.named('SELECT * FROM join_logs WHERE user_id = @userId AND guild_id = @guildId'),
      parameters: {'userId': userId.toString(), 'guildId': guildId.toString()},
    );

    if (result.isEmpty) {
      return null;
    }

    return JoinLogEntry.fromDatabaseRow(result.first.toColumnMap());
  }

  Future<void> removeOldLogs() async {
    await _database.getConnection().execute(
      Sql.named("DELETE FROM join_logs WHERE created_at < NOW() - INTERVAL '7 days'"),
    );
  }
}
