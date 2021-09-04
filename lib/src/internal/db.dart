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

/// Postgres connection
PostgreSQLConnection get connection => _connection!;

FutureOr<void> openDbAndRunMigrations() async {
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
        guild_id VARCHAR NOT NULL,
        author_id VARCHAR NOT NULL
      );
      CREATE INDEX name_index ON tags USING btree(name);
      CREATE INDEX guild_index ON tags USING btree(guild_id);
      ALTER TABLE tags ADD CONSTRAINT name_guild_id_unique UNIQUE (name, guild_id);
    """)
    ..enqueueMigration("1.1", """
      CREATE TABLE tag_usage (
        id SERIAL PRIMARY KEY,
        command_id SERIAL,
        use_date TIMESTAMP DEFAULT NOW(),
        hidden bool DEFAULT FALSE,
        FOREIGN KEY(command_id) REFERENCES tags(id)
      );
      CREATE INDEX command_id_index ON tag_usage USING btree(command_id);
    """)
    ..enqueueMigration("1.2", """
      CREATE TABLE feature_settings (
        id SERIAL PRIMARY KEY,
        name varchar(20) NOT NULL,
        guild_id VARCHAR NOT NULL,
        add_date TIMESTAMP DEFAULT NOW(),
        who_enabled VARCHAR NOT NULL
      );
      CREATE INDEX guild_id_name_index ON feature_settings USING btree(guild_id, name);
      CREATE TABLE feature_settings_additional_data (
        id SERIAL PRIMARY KEY,
        name VARCHAR(20) NOT NULL,
        
        data VARCHAR NOT NULL,
        feature_setting_id SERIAL,
        FOREIGN KEY(feature_setting_id) REFERENCES feature_settings(id)
      );
    """)
    ..enqueueMigration("1.3", """
      CREATE EXTENSION pg_trgm;
    """)
    ..runMigrations();
}

FutureOr<void> closeDb() async {
  await _connection?.close();
}
