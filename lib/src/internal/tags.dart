import "package:nyxx/nyxx.dart" show Snowflake;

class Tag {
  late final int id;
  late final String name;
  late final String content;
  late final bool enabled;
  late final Snowflake guildId;
  late final Snowflake authorId;

  Tag.fromDatabaseRecord(Map<String, dynamic> row) {
    id = row["id"] as int;
    name = row["name"] as String;
    content = row["content"] as String;
    enabled = row["enabled"] as bool;
    guildId = Snowflake(row["guild_id"]);
    authorId = Snowflake(row["author_id"]);
  }
}
