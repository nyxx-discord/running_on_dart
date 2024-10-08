import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/models/feature_settings.dart';
import 'package:running_on_dart/src/services/db.dart';

class FeatureSettingsRepository {
  final _database = Injector.appInstance.get<DatabaseService>();

  Future<bool> isEnabled(Setting setting, Snowflake guildId) async {
    final result = await _database.getConnection().query('''
      SELECT name FROM feature_settings WHERE name = @name AND guild_id = @guild_id
    ''', substitutionValues: {
      'name': setting.name,
      'guild_id': guildId.toString(),
    });

    return result.isNotEmpty;
  }

  Future<FeatureSetting?> fetchSetting(Setting setting, Snowflake guildId) async {
    final result = await _database.getConnection().query('''
      SELECT * FROM feature_settings WHERE name = @name AND guild_id = @guild_id
    ''', substitutionValues: {
      'name': setting.name,
      'guild_id': guildId.toString(),
    });

    if (result.isEmpty) {
      return null;
    }

    return FeatureSetting.fromRow(result.first.toColumnMap());
  }

  /// Fetch all settings for all guilds from the database.
  Future<Iterable<FeatureSetting>> fetchSettings() async {
    final result = await _database.getConnection().query('''
      SELECT * FROM feature_settings;
    ''');

    return result.map((row) => row.toColumnMap()).map(FeatureSetting.fromRow);
  }

  /// Fetch all settings for all guilds from the database.
  Future<Iterable<FeatureSetting>> fetchSettingsForGuild(Snowflake guild) async {
    final result = await _database.getConnection().query('''
      SELECT * FROM feature_settings WHERE guild_id = @guildId;
    ''', substitutionValues: {'guildId': guild.toString()});

    return result.map((row) => row.toColumnMap()).map(FeatureSetting.fromRow);
  }

  /// Enable or update a setting in the database.
  Future<void> enableSetting(FeatureSetting setting) async {
    await _database.getConnection().execute('''
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
      'name': setting.setting.name,
      'guild_id': setting.guildId.toString(),
      'add_date': setting.addedAt,
      'who_enabled': setting.whoEnabled.toString(),
      'additional_data': setting.data?.toString(),
    });
  }

  /// Disable a setting in (remove it from) the database.
  Future<void> disableSetting(FeatureSetting setting) async {
    await _database.getConnection().execute('''
      DELETE FROM feature_settings WHERE name = @name AND guild_id = @guild_id
    ''', substitutionValues: {
      'name': setting.setting.name,
      'guild_id': setting.guildId.toString(),
    });
  }
}
