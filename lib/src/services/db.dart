import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:migent/migent.dart';
import 'package:postgres/postgres.dart';

import 'package:running_on_dart/src/settings.dart';
import 'package:running_on_dart/src/util/util.dart';

/// The user to use when connecting to the database.
String user = getEnv('POSTGRES_USER');

/// The password to use when connecting to the database.
// Don't use [getEnv] so we can have password be optional
String? password = Platform.environment['POSTGRES_PASSWORD'];

/// The name of the database to connect to.
String databaseName = getEnv('POSTGRES_DB');

/// The host name of the database to connect to.
String host = getEnv('DB_HOST', 'db');

/// The port to connect to the database on.
int port = int.parse(getEnv('DB_PORT', '5432'));

class DatabaseService implements RequiresInitialization {
  late PostgreSQLConnection _connection;
  final Logger _logger = Logger('ROD.Database');

  @override
  Future<void> init() async {
    await _connect();
  }

  /// Connect to the database and ensure the schema is up to date.
  Future<void> _connect() async {
    _logger.info('Connecting to database');

    _connection = PostgreSQLConnection(
      host,
      port,
      databaseName,
      username: user,
      password: password,
    );

    await _connection.open();

    _logger.info('Running database migrations');

    final migrator = MigentMigrationRunner(_connection, databaseName, MemoryMigrationAccess())
      ..enqueueMigration('1', '''
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
    ''')
      ..enqueueMigration('1.1', '''
      CREATE TABLE tag_usage (
        id SERIAL PRIMARY KEY,
        command_id SERIAL,
        use_date TIMESTAMP DEFAULT NOW(),
        hidden bool DEFAULT FALSE,
        FOREIGN KEY(command_id) REFERENCES tags(id)
      );
      CREATE INDEX command_id_index ON tag_usage USING btree(command_id);
    ''')
      ..enqueueMigration('1.2', '''
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
    ''')
      ..enqueueMigration('1.3', '''
      CREATE EXTENSION pg_trgm;
    ''')
      ..enqueueMigration('1.4', '''
      DROP TABLE feature_settings_additional_data;
    ''')
      ..enqueueMigration('1.5', '''
      ALTER TABLE feature_settings ADD COLUMN additional_data VARCHAR NULL;
    ''')
      ..enqueueMigration('1.6', '''
      CREATE TABLE reminders (
        id SERIAL PRIMARY KEY,
        user_id VARCHAR NOT NULL,
        channel_id VARCHAR NOT NULL,
        message_id VARCHAR NULL,
        add_date TIMESTAMP NOT NULL,
        trigger_date TIMESTAMP NOT NULL,
        message VARCHAR(50) NOT NULL
      );
      CREATE INDEX reminder_trigger_date_idx ON reminders USING btree(trigger_date);
    ''')
      ..enqueueMigration('1.7', '''
      ALTER TABLE reminders ALTER COLUMN message TYPE VARCHAR(200)
    ''')
      ..enqueueMigration('1.8', '''
      ALTER TABLE reminders ADD COLUMN active BOOLEAN NOT NULL; 
    ''')
      ..enqueueMigration('1.9', '''
      CREATE INDEX name_trgm_idx ON tags USING gin (name gin_trgm_ops);
    ''')
      ..enqueueMigration('2.0', '''
      ALTER TABLE reminders DROP COLUMN active;
      ALTER TABLE reminders ALTER COLUMN message TYPE TEXT;
    ''')
      ..enqueueMigration('2.1', '''
      ALTER TABLE feature_settings ADD CONSTRAINT settings_name_guild_id_unique UNIQUE (name, guild_id);
    ''')
      ..enqueueMigration('2.2', '''
      TRUNCATE TABLE reminders;
      ''')
      ..enqueueMigration("2.3", '''
      CREATE TABLE jellyfin_configs (
        id SERIAL PRIMARY KEY,
        name VARCHAR NOT NULL,
        base_path VARCHAR NOT NULL,
        token VARCHAR NOT NULL,
        is_default BOOLEAN NOT NULL DEFAULT FALSE,
        guild_id VARCHAR NOT NULL
      );
      CREATE UNIQUE INDEX idx_jellyfin_configs_unique_name ON jellyfin_configs(name, guild_id);
      CREATE UNIQUE INDEX idx_jellyfin_configs_unique_default ON jellyfin_configs(guild_id, is_default) WHERE is_default = TRUE;
      ''');

    await migrator.runMigrations();

    _logger.info('Connected to database');
  }

  PostgreSQLConnection getConnection() => _connection;
}
