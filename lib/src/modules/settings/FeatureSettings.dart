import "package:nyxx/nyxx.dart";
import "package:running_on_dart/src/modules/settings/settings.dart";

class FeatureSettings {
  late final int id;
  late final String name;
  late final Snowflake guildId;

  FeatureSettings(Map<String, dynamic> rawRow) {
    this.id = rawRow["id"] as int;
    this.name = rawRow["name"] as String;
    this.guildId = Snowflake(rawRow["guild_id"].toString());
  }

  Future<Map<String, dynamic>?> fetchAddtionalData() =>
      fetchAdditionalData(this.id);
}
