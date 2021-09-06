import "package:nyxx/nyxx.dart" show Snowflake;

class Tag {
  late final int id;
  late final String name;
  late final String content;
  late final bool enabled;
  late final Snowflake guildId;
  late final Snowflake authorId;

  Tag.fromDatabaseRecord(Map<String, dynamic> row) {
    this.id = row["id"] as int;
    this.name = row["name"] as String;
    this.content = row["content"] as String;
    this.enabled = row["enabled"] as bool;
    this.guildId = Snowflake(row["guild_id"]);
    this.authorId = Snowflake(row["author_id"]);
  }
}
