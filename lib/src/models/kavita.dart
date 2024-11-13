import 'package:nyxx/nyxx.dart';

class KavitaUserConfig {
  static String tableName = 'kavita_user_configs';

  final Snowflake userId;
  final String authToken;
  final String apiKey;
  final int kavitaConfigId;

  KavitaConfig? config;
  int? id;

  KavitaUserConfig(
      {required this.userId, required this.authToken, required this.apiKey, required this.kavitaConfigId, this.id});

  factory KavitaUserConfig.fromDatabaseRow(Map<String, dynamic> row) {
    return KavitaUserConfig(
      userId: Snowflake.parse(row['user_id']),
      authToken: row['auth_token'],
      apiKey: row['api_key'],
      kavitaConfigId: row['kavita_config_id'],
      id: row['id'],
    );
  }

  factory KavitaUserConfig.fromDatabaseRowWithConfig(Map<String, dynamic> row) {
    return KavitaUserConfig.fromDatabaseRow(row)..config = KavitaConfig.fromDatabaseRow(row);
  }
}

class KavitaConfig {
  static String tableName = 'kavita_configs';

  final String name;
  final String basePath;
  final bool isDefault;
  final Snowflake parentId;

  /// The ID of this config, or `null` if this config has not yet been added to the database.
  int? id;

  KavitaConfig({
    required this.name,
    required this.basePath,
    required this.isDefault,
    required this.parentId,
    this.id,
  });

  factory KavitaConfig.fromDatabaseRow(Map<String, dynamic> row) {
    return KavitaConfig(
      id: row['id'] as int?,
      name: row['name'],
      basePath: row['base_path'],
      isDefault: row['is_default'] as bool,
      parentId: Snowflake.parse(row['parent_id']),
    );
  }
}
