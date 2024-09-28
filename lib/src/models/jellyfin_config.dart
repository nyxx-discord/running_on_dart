import 'package:nyxx/nyxx.dart';

class JellyfinConfig {
  final String name;
  final String basePath;
  final String token;
  final bool isDefault;
  final Snowflake guildId;

  /// The ID of this config, or `null` if this config has not yet been added to the database.
  int? id;

  JellyfinConfig({required this.name, required this.basePath, required this.token, required this.isDefault, required this.guildId});

  factory JellyfinConfig.fromDatabaseRow(Map<String, dynamic> row) {
    return JellyfinConfig(
        name: row['name'],
        basePath: row['base_path'],
        token: row['token'],
        isDefault: row['is_default'] as bool,
        guildId: Snowflake.parse(row['guild_id']));
  }
}
