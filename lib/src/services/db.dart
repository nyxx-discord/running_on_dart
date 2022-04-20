import 'dart:io';

import 'package:logging/logging.dart';
import 'package:migent/migent.dart';
import 'package:postgres/postgres.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/models/reminder.dart';

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

/// The connection to the database.
late PostgreSQLConnection connection;

final Logger _logger = Logger('ROD.Database');

/// Connect to the database and ensure the schema is up to date.
Future<PostgreSQLConnection> connectToDatabase() async {
  _logger.info('Connecting to database');

  PostgreSQLConnection connection = PostgreSQLConnection(
    host,
    port,
    databaseName,
    username: user,
    password: password,
  );

  await connection.open();

  _logger.info('Running database migrations');

  MigentMigrationRunner migrator = MigentMigrationRunner(connection, databaseName, MemoryMigrationAccess())
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
      ALTER TABLE reminders ALTER COLUMN message TYPE TEXT NOT NULL;
    ''');

  await migrator.runMigrations();

  _logger.info('Connected to database');

  return connection;
}

/// Initialise the database service.
Future<void> initDatabase() async {
  connection = await connectToDatabase();
}

/// Fetch all reminders currrently in the database.
Future<Iterable<Reminder>> fetchReminders() async {
  PostgreSQLResult result = await connection.query('SELECT * FROM reminders');

  return result.map(Reminder.fromRow);
}

/// Delete a reminder from the database.
Future<void> deleteReminder(Reminder reminder) async {
  final int? id = reminder.id;

  if (id == null) {
    return;
  }

  await connection.execute('DELETE FROM reminders WHERE id = @id', substitutionValues: {
    'id': id,
  });
}

/// Add a reminder to the database.
Future<void> addReminder(Reminder reminder) async {
  if (reminder.id != null) {
    _logger.warning('Attempting to add reminder with id ${reminder.id} twice, ignoring');
    return;
  }

  PostgreSQLResult result = await connection.query('''
    INSERT INTO reminders (
      user_id,
      channel_id,
      message_id,
      trigger_date,
      add_date,
      message
    ) VALUES (
      @user_id,
      @channel_id,
      @message_id,
      @trigger_date,
      @add_date,
      @message
    ) RETURNING id;
  ''', substitutionValues: {
    'user_id': reminder.userId.toString(),
    'channel_id': reminder.channelId.toString(),
    'message_id': reminder.messageId?.toString(),
    'trigger_date': reminder.triggerAt.toUtc(),
    'add_date': reminder.addedAt.toUtc(),
    'message': reminder.message,
  });

  reminder.id = result.first.first as int;
}
