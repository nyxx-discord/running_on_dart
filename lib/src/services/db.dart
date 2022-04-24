import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:migent/migent.dart';
import 'package:postgres/postgres.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/models/guild_settings.dart';
import 'package:running_on_dart/src/models/reminder.dart';
import 'package:running_on_dart/src/models/tag.dart';

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

class DatabaseService {
  /// The connection to the database.
  late PostgreSQLConnection _connection;

  final Logger _logger = Logger('ROD.Database');

  final Completer<void> _readyCompleter = Completer();
  late final Future<void> _ready = _readyCompleter.future;

  static final DatabaseService instance = DatabaseService._();

  DatabaseService._() {
    _connect();
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

    MigentMigrationRunner migrator = MigentMigrationRunner(_connection, databaseName, MemoryMigrationAccess())
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
    ''');

    await migrator.runMigrations();

    _logger.info('Connected to database');

    _readyCompleter.complete();
  }

  /// Fetch all reminders currrently in the database.
  Future<Iterable<Reminder>> fetchReminders() async {
    await _ready;

    PostgreSQLResult result = await _connection.query('SELECT * FROM reminders');

    return result.map(Reminder.fromRow);
  }

  /// Delete a reminder from the database.
  Future<void> deleteReminder(Reminder reminder) async {
    int? id = reminder.id;

    if (id == null) {
      return;
    }

    await _ready;

    await _connection.execute('DELETE FROM reminders WHERE id = @id', substitutionValues: {
      'id': id,
    });
  }

  /// Add a reminder to the database.
  Future<void> addReminder(Reminder reminder) async {
    if (reminder.id != null) {
      _logger.warning('Attempting to add reminder with id ${reminder.id} twice, ignoring');
      return;
    }

    await _ready;

    PostgreSQLResult result = await _connection.query('''
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

  /// Fetch all existing tags from the database.
  Future<Iterable<Tag>> fetchTags() async {
    await _ready;

    PostgreSQLResult result = await _connection.query('''
      SELECT * FROM tags;
    ''');

    return result.map(Tag.fromRow);
  }

  /// Delete a tag from the database.
  Future<void> deleteTag(Tag tag) async {
    int? id = tag.id;

    if (id == null) {
      return;
    }

    await _ready;

    await _connection.execute('''
      DELETE FROM tags WHERE id = @id;
    ''', substitutionValues: {
      'id': id,
    });
  }

  /// Add a tag to the database.
  Future<void> addTag(Tag tag) async {
    if (tag.id != null) {
      _logger.warning('Attempting to add tag with id ${tag.id} twice, ignoring');
      return;
    }

    await _ready;

    PostgreSQLResult result = await _connection.query('''
    INSERT INTO tags (
      name,
      content,
      enabled,
      guild_id,
      author_id
    ) VALUES (
      @name,
      @content,
      @enabled,
      @guild_id,
      @author_id
    ) RETURNING id;
  ''', substitutionValues: {
      'name': tag.name,
      'content': tag.content,
      'enabled': tag.enabled,
      'guild_id': tag.guildId.toString(),
      'author_id': tag.authorId.toString(),
    });

    tag.id = result.first.first as int;
  }

  /// Update a tag in the database.
  Future<void> updateTag(Tag tag) async {
    if (tag.id == null) {
      return addTag(tag);
    }

    await _ready;

    await _connection.query('''
      UPDATE tags SET
        name = @name,
        content = @content,
        enabled = @enabled,
        guild_id = @guild_id,
        author_id = @author_id
      WHERE
        id = @id
    ''', substitutionValues: {
      'id': tag.id,
      'name': tag.name,
      'content': tag.content,
      'enabled': tag.enabled,
      'guild_id': tag.guildId.toString(),
      'author_id': tag.authorId.toString(),
    });
  }

  Future<Iterable<TagUsedEvent>> fetchTagUsage() async {
    await _ready;

    PostgreSQLResult result = await _connection.query('''
      SELECT * FROM tag_usage;
    ''');

    return result.map(TagUsedEvent.fromRow);
  }

  Future<void> registerTagUsedEvent(TagUsedEvent event) async {
    await _ready;

    await _connection.query('''
      INSERT INTO tag_usage (
        command_id,
        use_date,
        hidden
      ) VALUES (
        @tag_id,
        @use_date,
        @hidden
      )
    ''', substitutionValues: {
      'tag_id': event.tagId,
      'use_date': event.usedAt,
      'hidden': event.hidden,
    });
  }

  /// Fetch all settings for all guilds from the database.
  Future<Iterable<GuildSetting<dynamic>>> fetchSettings() async {
    await _ready;

    PostgreSQLResult result = await _connection.query('''
      SELECT * FROM feature_settings;
    ''');

    return result.map(GuildSetting.fromRow);
  }

  /// Enable or update a setting in the database.
  Future<void> enableSetting<T>(GuildSetting<T> setting) async {
    await _ready;

    await _connection.execute('''
      INSERT INTO feature_settings (
        name,
        guild_id,
        add_date,
        who_enabled,
        additional_data
      ) VALUES (
        @name,
        @guild_id,
        @add_date,
        @who_enabled,
        @additional_data
      ) ON CONFLICT ON CONSTRAINT settings_name_guild_id_unique DO UPDATE SET
        add_date = @add_date,
        who_enabled = @who_enabled,
        additional_data = @additional_data
      WHERE
        feature_settings.guild_id = @guild_id AND feature_settings.name = @name
    ''', substitutionValues: {
      'name': setting.setting.value,
      'guild_id': setting.guildId.toString(),
      'add_date': setting.addedAt,
      'who_enabled': setting.whoEnabled.toString(),
      'additional_data': setting.data?.toString(),
    });
  }

  /// Disable a setting in (remove it from) the database.
  Future<void> disableSetting<T>(GuildSetting<T> setting) async {
    await _ready;

    await _connection.execute('''
      DELETE FROM feature_settings WHERE name = @name AND guild_id = @guild_id
    ''', substitutionValues: {
      'name': setting.setting.value,
      'guild_id': setting.guildId.toString(),
    });
  }
}
