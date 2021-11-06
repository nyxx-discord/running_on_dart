import "package:nyxx/nyxx.dart" show Snowflake;

class FeatureSettings {
  late final int id;
  late final String name;
  late final Snowflake guildId;
  late final String? additionalData;

  FeatureSettings(Map<String, dynamic> rawRow) {
    this.id = rawRow["id"] as int;
    this.name = rawRow["name"] as String;
    this.additionalData = rawRow["additional_data"] as String?;
    this.guildId = Snowflake(rawRow["guild_id"].toString());
  }
}
