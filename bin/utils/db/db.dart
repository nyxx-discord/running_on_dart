import "dart:async";
import "dart:io";

import "package:postgres/postgres.dart";
import "package:migent/migent.dart";

String get _dbHost => Platform.environment["DB_HOST"]!;
int get _dbPort => int.parse(Platform.environment["DB_PORT"]!);
String get _dbPassword => Platform.environment["POSTGRES_PASSWORD"]!;
String get _dbUser => Platform.environment["POSTGRES_USER"]!;
String get _dbName => Platform.environment["POSTGRES_DB"]!;

PostgreSQLConnection? _connection;

FutureOr<void> openDb() async {
  await Future.delayed(const Duration(seconds: 5)); // hack for postgres

  _connection = PostgreSQLConnection(_dbHost, _dbPort, _dbName, username: _dbUser, password: _dbPassword);
  await _connection!.open();

  Migent(_connection!, _dbName)
    ..enqueueMigration("1", """
      CREATE TABLE tags (
        id SERIAL PRIMARY KEY,
        name VARCHAR NOT NULL,
        content VARCHAR NOT NULL,
        enabled BOOLEAN NOT NULL DEFAULT TRUE,
        guild_id INT NOT NULL
      );
    """)
    ..enqueueMigration("1.1", """
      CREATE INDEX name_index ON tags USING btree(name);
      CREATE INDEX guild_index ON tags USING btree(guild_id);
      ALTER TABLE tags ADD CONSTRAINT name_guild_id_unique UNIQUE (name, guild_id);
    """)
    ..runMigrations();
}

FutureOr<void> closeDb() async {
  await _connection?.close();
}
