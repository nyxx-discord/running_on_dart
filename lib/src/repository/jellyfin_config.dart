import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/models/jellyfin_config.dart';
import 'package:running_on_dart/src/services/db.dart';

class JellyfinConfigRepository {
  final _database = Injector.appInstance.get<DatabaseService>();

  Future<void> deleteConfig(int id) async {
    await _database
        .getConnection()
        .execute('DELETE FROM jellyfin_configs WHERE id = @id', parameters: {'id': id});
  }

  Future<Iterable<JellyfinConfig>> getDefaultConfigs() async {
    final result = await _database.getConnection().execute('SELECT * FROM jellyfin_configs WHERE is_default = 1::bool');

    return result.map((row) => row.toColumnMap()).map(JellyfinConfig.fromDatabaseRow);
  }

  Future<Iterable<JellyfinConfig>> getConfigsForGuild(Snowflake guildId) async {
    final result = await _database.getConnection().execute('SELECT * FROM jellyfin_configs WHERE guild_id = @guildId',
        parameters: {'guildId': guildId.toString()});

    return result.map((row) => row.toColumnMap()).map(JellyfinConfig.fromDatabaseRow);
  }

  Future<JellyfinConfig?> getByName(String name, String guildId) async {
    final result = await _database.getConnection().execute(
        'SELECT * FROM jellyfin_configs WHERE name = @name AND guild_id = @guildId',
        parameters: {'name': name, 'guildId': guildId});

    if (result.isEmpty) {
      return null;
    }

    return JellyfinConfig.fromDatabaseRow(result.first.toColumnMap());
  }

  Future<JellyfinConfig> createJellyfinConfig(
      String name, String basePath, String token, bool isDefault, Snowflake guildId) async {
    final config =
        JellyfinConfig(name: name, basePath: basePath, token: token, isDefault: isDefault, parentId: guildId);

    final result = await _database.getConnection().execute('''
    INSERT INTO jellyfin_configs (
      name,
      base_path,
      token,
      is_default,
      guild_id
    ) VALUES (
      @name,
      @base_path,
      @token,
      @is_default,
      @guild_id
    ) RETURNING id;
  ''', parameters: {
      'name': config.name,
      'base_path': config.basePath,
      'token': config.token,
      'is_default': config.isDefault,
      'guild_id': config.parentId.toString(),
    });

    config.id = result.first.first as int;
    return config;
  }
}
