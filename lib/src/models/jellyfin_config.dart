import 'package:nyxx/nyxx.dart';

Snowflake? parseSnowflakeOrNull(dynamic value) => value != null ? Snowflake.parse(value) : null;

class JellyfinConfig {
  final String name;
  final String basePath;
  final String token;
  final bool isDefault;
  final Snowflake parentId;

  /// The ID of this config, or `null` if this config has not yet been added to the database.
  int? id;

  JellyfinConfig(
      {required this.name,
      required this.basePath,
      required this.token,
      required this.isDefault,
      required this.parentId});

  factory JellyfinConfig.fromDatabaseRow(Map<String, dynamic> row) {
    return JellyfinConfig(
      name: row['name'],
      basePath: row['base_path'],
      token: row['token'],
      isDefault: row['is_default'] as bool,
      parentId: Snowflake.parse(row['guild_id']),
    );
  }
}
