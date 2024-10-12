import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:postgres/postgres.dart';
import 'package:running_on_dart/src/models/jellyfin_config.dart';
import 'package:running_on_dart/src/services/db.dart';

class JellyfinConfigRepository {
  final _database = Injector.appInstance.get<DatabaseService>();

  Future<void> deleteConfig(int id) async {
    await _database.getConnection().execute('DELETE FROM jellyfin_configs WHERE id = @id', parameters: {'id': id});
  }

  Future<Iterable<JellyfinConfig>> getDefaultConfigs() async {
    final result = await _database.getConnection().execute('SELECT * FROM jellyfin_configs WHERE is_default = 1::bool');

    return result.map((row) => row.toColumnMap()).map(JellyfinConfig.fromDatabaseRow);
  }

  Future<Iterable<JellyfinConfig>> getConfigsForGuild(Snowflake guildId) async {
    final result = await _database.getConnection().execute(
        Sql.named('SELECT * FROM jellyfin_configs WHERE guild_id = @guildId'),
        parameters: {'guildId': guildId.toString()});

    return result.map((row) => row.toColumnMap()).map(JellyfinConfig.fromDatabaseRow);
  }

  Future<JellyfinConfig?> getByName(String name, String guildId) async {
    final result = await _database.getConnection().execute(
        Sql.named('SELECT * FROM jellyfin_configs WHERE name = @name AND guild_id = @guildId'),
        parameters: {'name': name, 'guildId': guildId});

    if (result.isEmpty) {
      return null;
    }

    return JellyfinConfig.fromDatabaseRow(result.first.toColumnMap());
  }

  Future<void> updateJellyfinConfig(JellyfinConfig config) async {
    await _database.getConnection().execute(Sql.named('''
      UPDATE jellyfin_configs
      SET
        base_path = @base_path,
        token = @token,
        sonarr_base_path = @sonarr_base_path,
        sonarr_token = @sonarr_token,
        wizarr_base_path = @wizarr_base_path,
        wizarr_token = @wizarr_token
      WHERE id = @id
    '''), parameters: {
      'base_path': config.basePath,
      'token': config.token,
      'sonarr_base_path': config.sonarrBasePath,
      'sonarr_token': config.sonarrToken,
      'wizarr_base_path': config.wizarrBasePath,
      'wizarr_token': config.wizarrToken,
      'id': config.id,
    });
  }

  Future<JellyfinConfig> createJellyfinConfig(JellyfinConfig config) async {
    final result = await _database.getConnection().execute(Sql.named('''
    INSERT INTO jellyfin_configs (
      name,
      base_path,
      token,
      is_default,
      guild_id,
      sonarr_base_path,
      sonarr_token,
      wizarr_base_path,
      wizarr_token
    ) VALUES (
      @name,
      @base_path,
      @token,
      @is_default,
      @guild_id,
      @sonarr_base_path,
      @sonarr_token,
      @wizarr_base_path,
      @wizarr_token
    ) RETURNING id;
  '''), parameters: {
      'name': config.name,
      'base_path': config.basePath,
      'token': config.token,
      'is_default': config.isDefault,
      'guild_id': config.parentId.toString(),
      'sonarr_base_path': config.sonarrBasePath,
      'sonarr_token': config.sonarrToken,
      'wizarr_base_path': config.wizarrBasePath,
      'wizarr_token': config.wizarrToken,
    });

    config.id = result.first.first as int;
    return config;
  }
}
