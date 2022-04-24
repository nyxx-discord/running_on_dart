import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/models/guild_settings.dart';

class GuildSettingsService {
  static final GuildSettingsService instance = GuildSettingsService._();

  late final Future<List<GuildSetting<dynamic>>> settings = DatabaseService.instance.fetchSettings().then((value) => value.toList());

  GuildSettingsService._();

  /// Get the data for a setting in a specific guild, if any.
  Future<GuildSetting<T>?> getSetting<T>(Setting<T> setting, Snowflake guildId) async {
    Iterable<GuildSetting<dynamic>> result = (await settings).where((s) => s.setting == setting && s.guildId == guildId);

    if (result.isNotEmpty) {
      return result.first.cast<T>();
    }

    return null;
  }

  /// Returns whether a setting is enabled in a particular guild.
  Future<bool> isEnabled<T>(Setting<T> setting, Snowflake guildId) async => await getSetting(setting, guildId) != null;

  /// Enable a setting in a guild.
  Future<void> enable<T>(GuildSetting<T> setting) async {
    await DatabaseService.instance.enableSetting(setting);

    (await settings).removeWhere((s) => s.setting == setting.setting && s.guildId == setting.guildId);
    (await settings).add(setting);
  }

  /// Disable a setting in a guild.
  Future<void> disable<T>(GuildSetting<T> setting) async {
    await DatabaseService.instance.disableSetting(setting);

    (await settings).removeWhere((s) => s.setting == setting.setting && s.guildId == setting.guildId);
  }
}
