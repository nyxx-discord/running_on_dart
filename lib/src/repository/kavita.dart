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
}
