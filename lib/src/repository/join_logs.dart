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
      ..addNamedInsert('username')
      ..addNamedInsert('guild_id')
      ..addNamedInsert('message_id')
      ..addNamedInsert('created_at')
      ..addNamedInsert('left_at')
      ..addNamedInsert('flags');

    await _database.executeQuery(
      query,
      parameters: {
        'user_id': joinLogEntry.userId.toString(),
        'username': joinLogEntry.username,
        'guild_id': joinLogEntry.guildId.toString(),
        'message_id': joinLogEntry.messageId?.toString(),
        'created_at': joinLogEntry.createdAt.toUtc(),
        'left_at': joinLogEntry.leftAt?.toUtc(),
        'flags': joinLogEntry.flags,
      },
    );
  }

  Future<void> updateLeftAtAndFlags(int id, DateTime leftAt, int flags) async {
    await _database.getConnection().execute(
      Sql.named('UPDATE join_logs SET left_at = @leftAt, flags = @flags WHERE id = @id'),
      parameters: {'id': id, 'leftAt': leftAt.toUtc(), 'flags': flags},
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
