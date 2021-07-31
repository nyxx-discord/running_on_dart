import "dart:async";

import "package:logging/logging.dart";
import "package:postgres/postgres.dart";

const _migrationsTableName = "run_migrations";

class RODMigrations {
  final PostgreSQLConnection connection;
  final String dbName;

  final _logger = Logger("Migrations");

  final Map<String, String> enqueuedMigrations = {};

  RODMigrations(this.connection, this.dbName);

  void enqueueMigration(String version, String migrationString) =>
    this.enqueuedMigrations[version] = migrationString;

  FutureOr<void> runMigrations() async {
    for (final queueEntry in enqueuedMigrations.entries) {
      try {
        await _runMigration(queueEntry.key, queueEntry.value);

        await connection.execute(
            "INSERT INTO run_migrations(version) VALUES (@version)",
            substitutionValues: {"version": queueEntry.key}
        );

        _logger.info("Migration with version: `${queueEntry.key}` executed successfully");
      } on PostgreSQLException catch (e) {
        _logger.severe("Exception occurred when executing migrations: [${e.message}]");
        break;
      }
    }

    _logger.info("Migrations done!");
  }

  FutureOr<void> _runMigration(String version, String migrationString) async {
    final shouldRunMigration = await this._checkIfMigrationShouldBeExecuted(version);

    if (!shouldRunMigration) {
      return;
    }

    _logger.info("Migration with version: `$version` not present in migration log. Running migration");

    await connection.execute(migrationString);
  }

  /// Returns if this version should be execute
  Future<bool> _checkIfMigrationShouldBeExecuted(String version) async {
    try {
      final query = """
        SELECT EXISTS (
          SELECT 1
          FROM information_schema.tables 
          WHERE table_schema = '$dbName' AND
          table_name = '$_migrationsTableName'
        );
      """;

      final tableExistsResult = await connection.query(query);

      print(tableExistsResult.first);

      if (tableExistsResult.first[0] == false) {
        const createQuery = """
          CREATE TABLE $_migrationsTableName (
            id SERIAL PRIMARY KEY,
            version VARCHAR(100) NOT NULL
          );
        """;
        await connection.execute(createQuery);

        return true;
      }

      const checkQuery = """
        SELECT version FROM $_migrationsTableName ORDER BY id DESC LIMIT 1; 
      """;

      final lastVersionResult = await connection.query(checkQuery);

      return lastVersionResult.first[0] != version;
    } on Error catch (e) {
      print(e);
    }

    return false;
  }
}
