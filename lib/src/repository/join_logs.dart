import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:postgres/postgres.dart';
import 'package:running_on_dart/src/models/join_logs.dart';
import 'package:running_on_dart/src/services/db.dart';

class JoinLogsRepository {
  final _database = Injector.appInstance.get<DatabaseService>();

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
