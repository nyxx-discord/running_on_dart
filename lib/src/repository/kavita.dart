import 'package:injector/injector.dart';
import 'package:running_on_dart/src/models/kavita.dart';
import 'package:running_on_dart/src/services/db.dart';
import 'package:running_on_dart/src/util/query_builder.dart';

class KavitaRepository {
  final DatabaseService _database = Injector.appInstance.get();

  Future<Iterable<KavitaConfig>> findAllForParent(String parentId) async {
    final query = SelectQuery.selectAll(KavitaConfig.tableName)..andWhere("parent_id = @parent_id");
    final result = await _database.executeQuery(query, parameters: {'parent_id': parentId});

    return result.map((row) => KavitaConfig.fromDatabaseRow(row.toColumnMap()));
  }

  Future<KavitaConfig?> find(String name, String parentId) async {
    final query = SelectQuery.selectAll(KavitaConfig.tableName)
      ..andWhere("parent_id = @parent_id")
      ..andWhere("name = @name");

    final result = await _database.executeQuery(query, parameters: {'parent_id': parentId, 'name': name});
    if (result.isEmpty) {
      return null;
    }

    return KavitaConfig.fromDatabaseRow(result.first.toColumnMap());
  }

  Future<KavitaConfig?> findDefault(String parentId) async {
    final query = SelectQuery.selectAll(KavitaConfig.tableName)
      ..andWhere("parent_id = @parent_id")
      ..andWhere("is_default = 1::bool");

    final result = await _database.executeQuery(query, parameters: {'parent_id': parentId});
    if (result.isEmpty) {
      return null;
    }

    return KavitaConfig.fromDatabaseRow(result.first.toColumnMap());
  }

  Future<KavitaUserConfig?> findUserConfigForConfig(String userId, int configId) async {
    final query = SelectQuery.selectAll(KavitaUserConfig.tableName)
      ..andWhere("kavita_config_id = @config_id")
      ..andWhere('user_id = @user_id');

    final result = await _database.executeQuery(query, parameters: {'config_id': configId, 'user_id': userId});
    if (result.isEmpty) {
      return null;
    }

    return KavitaUserConfig.fromDatabaseRow(result.first.toColumnMap());
  }

  Future<KavitaUserConfig?> findUserConfig(String configName, String parentId, String userId) async {
    final query = SelectQuery.selectAll(KavitaConfig.tableName, alias: "c")
      ..select("uc.*")
      ..addJoin(KavitaUserConfig.tableName, "uc", ["uc.kavita_config_id = c.id", "uc.user_id = @userId"])
      ..andWhere("c.name = @configName")
      ..andWhere("c.parent_id = @parentId");

    final result = await _database.executeQuery(query, parameters: {
      'configName': configName,
      'parentId': parentId,
      'userId': userId,
    });

    if (result.isEmpty) {
      return null;
    }

    return KavitaUserConfig.fromDatabaseRowWithConfig(result.first.toColumnMap());
  }

  Future<KavitaConfig> saveConfig(KavitaConfig config) async {
    final query = InsertQuery(KavitaConfig.tableName)
      ..addNamedInsert('name')
      ..addNamedInsert('base_path')
      ..addNamedInsert('is_default')
      ..addNamedInsert('parent_id')
      ..addReturning('id');

    final result = await _database.executeQuery(query, parameters: {
      'name': config.name,
      'base_path': config.basePath,
      'is_default': config.isDefault,
      'parent_id': config.parentId.toString(),
    });

    config.id = result.first.first as int;
    return config;
  }

  Future<KavitaUserConfig> saveUserConfig(KavitaUserConfig userConfig) async {
    final query = InsertQuery(KavitaUserConfig.tableName)
      ..addNamedInsert("user_id")
      ..addNamedInsert("auth_token")
      ..addNamedInsert("api_key")
      ..addNamedInsert("kavita_config_id")
      ..onConflict('kavita_user_configs_user_id_unique', {
        'auth_token': '@auth_token',
        'api_key': '@api_key',
      }, [
        '${KavitaUserConfig.tableName}.user_id = @user_id',
        '${KavitaUserConfig.tableName}.kavita_config_id = @kavita_config_id'
      ])
      ..addReturning('id');

    final result = await _database.executeQuery(query, parameters: {
      'user_id': userConfig.userId.toString(),
      'auth_token': userConfig.authToken,
      'api_key': userConfig.apiKey,
      'kavita_config_id': userConfig.kavitaConfigId,
    });

    userConfig.id = result.first.first as int;
    return userConfig;
  }
}
