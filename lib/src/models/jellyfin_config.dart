import 'package:nyxx/nyxx.dart';

Snowflake? parseSnowflakeOrNull(dynamic value) => value != null ? Snowflake.parse(value) : null;

class JellyfinConfigUser {
  final Snowflake userId;
  final String token;
  final int jellyfinConfigId;

  int? id;
  JellyfinConfig? config;

  JellyfinConfigUser({required this.userId, required this.token, required this.jellyfinConfigId, this.id});

  factory JellyfinConfigUser.fromDatabaseRow(Map<String, dynamic> row) {
    return JellyfinConfigUser(
      userId: Snowflake.parse(row['user_id']),
      token: row['token'] as String,
      jellyfinConfigId: row['jellyfin_config_id'] as int,
      id: row['id'] as int,
    );
  }
}

class JellyfinConfig {
  final String name;
  final String basePath;
  final bool isDefault;
  final Snowflake parentId;

  final String? sonarrBasePath;
  final String? sonarrToken;

  final String? wizarrBasePath;
  final String? wizarrToken;

  /// The ID of this config, or `null` if this config has not yet been added to the database.
  int? id;

  JellyfinConfig({
    required this.name,
    required this.basePath,
    required this.isDefault,
    required this.parentId,
    this.sonarrBasePath,
    this.sonarrToken,
    this.wizarrBasePath,
    this.wizarrToken,
    this.id,
  });

  factory JellyfinConfig.fromDatabaseRow(Map<String, dynamic> row) {
    return JellyfinConfig(
      id: row['id'] as int?,
      name: row['name'],
      basePath: row['base_path'],
      isDefault: row['is_default'] as bool,
      parentId: Snowflake.parse(row['guild_id']),
      sonarrBasePath: row['sonarr_base_path'] as String?,
      sonarrToken: row['sonarr_token'] as String?,
      wizarrBasePath: row['wizarr_base_path'] as String?,
      wizarrToken: row['wizarr_token'] as String?,
    );
  }
}
