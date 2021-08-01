import "dart:async";

import "package:nyxx/nyxx.dart";

import "../utils/db/db.dart" as db;
import "../utils/db/tags.dart";

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
