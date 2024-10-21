import 'package:injector/injector.dart';
import 'package:postgres/postgres.dart';
import 'package:running_on_dart/src/models/jellyfin_config.dart';
import 'package:running_on_dart/src/services/db.dart';

class JellyfinConfigRepository {
  final _database = Injector.appInstance.get<DatabaseService>();

  Future<Iterable<JellyfinConfig>> getConfigsForParent(String parentId) async {
    final result = await _database.getConnection().execute(
        Sql.named('SELECT * FROM jellyfin_configs WHERE guild_id = @parentId'),
        parameters: {'parentId': parentId});

    return result.map((row) => row.toColumnMap()).map(JellyfinConfig.fromDatabaseRow);
  }

  Future<JellyfinConfig?> getDefaultForParent(String parentId) async {
    final result = await _database.getConnection().execute(
        Sql.named('SELECT * FROM jellyfin_configs WHERE is_default = 1::bool AND guild_id = @parentId LIMIT 1'),
        parameters: {'parentId': parentId});

    if (result.isEmpty) {
      return null;
    }

    return JellyfinConfig.fromDatabaseRow(result.first.toColumnMap());
  }

  Future<JellyfinConfig?> getJellyfinConfigById(int id) async {
    final result = await _database
        .getConnection()
        .execute(Sql.named('SELECT * FROM jellyfin_configs WHERE id = @id'), parameters: {'id': id});

    if (result.isEmpty) {
      return null;
    }

    return JellyfinConfig.fromDatabaseRow(result.first.toColumnMap());
  }

  Future<JellyfinConfig?> getByNameAndGuild(String name, String guildId) async {
    final result = await _database.getConnection().execute(
        Sql.named('SELECT * FROM jellyfin_configs WHERE name = @name AND guild_id = @guildId'),
        parameters: {'name': name, 'guildId': guildId});

    if (result.isEmpty) {
      return null;
    }

    return JellyfinConfig.fromDatabaseRow(result.first.toColumnMap());
  }

  Future<JellyfinConfigUser> saveJellyfinConfigUser(JellyfinConfigUser configUser) async {
    final result = await _database.getConnection().execute(Sql.named('''
      INSERT INTO jellyfin_user_configs (
        user_id,
        token,
        jellyfin_config_id
      ) VALUES (
        @user_id,
        @token,
        @jellyfin_config_id
      ) ON CONFLICT ON CONSTRAINT jellyfin_configs_user_id_unique DO UPDATE SET
        token = @token
      WHERE
        jellyfin_user_configs.user_id = @user_id AND jellyfin_user_configs.jellyfin_config_id = @jellyfin_config_id
      RETURNING id;
    '''), parameters: {
      'user_id': configUser.userId.toString(),
      'token': configUser.token,
      'jellyfin_config_id': configUser.jellyfinConfigId,
    });

    configUser.id = result.first.first as int;
    return configUser;
  }

  Future<JellyfinConfigUser?> getUserConfig(String userId, int configId) async {
    final result = await _database.getConnection().execute(
        Sql.named('SELECT * FROM jellyfin_user_configs WHERE user_id = @userId AND jellyfin_config_id = @configId'),
        parameters: {'userId': userId, 'configId': configId});

    if (result.isEmpty) {
      return null;
    }

    return JellyfinConfigUser.fromDatabaseRow(result.first.toColumnMap());
  }

  Future<void> updateJellyfinConfig(JellyfinConfig config) async {
    await _database.getConnection().execute(Sql.named('''
      UPDATE jellyfin_configs
      SET
        base_path = @base_path,
        sonarr_base_path = @sonarr_base_path,
        sonarr_token = @sonarr_token,
        wizarr_base_path = @wizarr_base_path,
        wizarr_token = @wizarr_token
      WHERE id = @id
    '''), parameters: {
      'base_path': config.basePath,
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
      is_default,
      guild_id,
      sonarr_base_path,
      sonarr_token,
      wizarr_base_path,
      wizarr_token
    ) VALUES (
      @name,
      @basePath,
      @isDefault,
      @parentId,
      @sonarrBasePath,
      @sonarrToken,
      @wizarrBasePath,
      @wizarrToken
    ) RETURNING id;
  '''), parameters: {
      'name': config.name,
      'basePath': config.basePath,
      'isDefault': config.isDefault,
      'parentId': config.parentId.toString(),
      'sonarrBasePath': config.sonarrBasePath,
      'sonarrToken': config.sonarrToken,
      'wizarrBasePath': config.wizarrBasePath,
      'wizarrToken': config.wizarrToken,
    });

    config.id = result.first.first as int;
    return config;
  }

  Future<List<JellyfinConfigUser>> getJellyfinConfigBasedOnPreviousLogin(
      String userId, String guildId, String host) async {
    final result = await _database.getConnection().execute(
        Sql.named(
            "SELECT juc.* FROM jellyfin_user_configs juc JOIN jellyfin_configs jc ON jc.id = juc.jellyfin_config_id WHERE juc.user_id = @userId AND jc.guild_id = @guildId AND jc.base_path LIKE @requestHost"),
        parameters: {'userId': userId, 'guildId': guildId, 'requestHost': '%$host%'});

    return result.map((row) => JellyfinConfigUser.fromDatabaseRow(row.toColumnMap())).toList();
  }
}
