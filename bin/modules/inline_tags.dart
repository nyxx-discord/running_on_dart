import "dart:async";

import "package:nyxx/nyxx.dart";

import "../utils/db/db.dart" as db;
import "../utils/db/tags.dart";

Future<int> fetchPerDay() async {
  const query = """
    SELECT COUNT(t.id)::decimal FROM tag_usage t WHERE t.use_date BETWEEN NOW() - INTERVAL '3 days' AND NOW();
  """;

  final result = await db.connection.query(query);

  return int.parse(result[0][0].toString());
}

Future<Map<String, List<int>>> fetchUsageStats(Snowflake guildId) async {
  const query = """
    SELECT t.name, COUNT(u.id), COUNT(nullif(u.hidden, false)) FROM tags t JOIN tag_usage u ON t.id = u.command_id WHERE t.guild_id = @guildId GROUP BY t.name LIMIT 3;
  """;

  final result = await db.connection.query(query, substitutionValues: {
    "guildId": guildId.toString(),
  });

  final finalResult = <String, List<int>>{};
  for (final row in result) {
    final name = row[0] as String;
    final count = row[1] as int;
    final countHidden = row[2] as int;

    finalResult[name] = [count, countHidden];
  }
  return finalResult;
}

Future<void> updateUsageStats(int id, bool hidden) async {
  const query = """
    INSERT INTO tag_usage(command_id, hidden) VALUES (@id, @hidden);
  """;

  await db.connection.execute(query, substitutionValues: {
    "id": id,
    "hidden": hidden,
  });
}

Future<Tag?> findTagForGuild(String name, Snowflake guildId, {bool enabled = true}) async {
  const query = """
    SELECT t.* FROM tags t WHERE t.name = @name AND t.guild_id = @guildId AND t.enabled = @enabled;
  """;

  final result = await db.connection.query(query, substitutionValues: {
    "name": name,
    "guildId": guildId.toString(),
    "enabled": enabled,
  });

  if (result.isEmpty) {
    return null;
  }

  return Tag.fromDatabaseRecord(result.first.toColumnMap());
}

Future<bool> deleteTagForGuild(String name, Snowflake guildId, Snowflake authorId) async {
  const query = """
    DELETE FROM tags t WHERE t.name = @name AND t.guild_id = @guildId AND t.author_id = @authorId; 
  """;

  final affectedRows = await db.connection.execute(query, substitutionValues: {
    "name": name,
    "guildId": guildId.toString(),
    "author_id": authorId.toString(),
  });

  return affectedRows == 1;
}

Future<bool> createTagForGuild(String name, String content, Snowflake guildId, Snowflake authorId) async {
  const query = """
    INSERT INTO tags (name, content, enabled, guild_id, author_id)
    VALUES (@name, @content, true, @guildId, @authorId);
  """;

  final affectedRows = await db.connection.execute(query, substitutionValues: {
    "name": name,
    "content": content,
    "guildId": guildId.toString(),
    "authorId": authorId.toString(),
  });

  return affectedRows == 1;
}
