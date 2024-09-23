
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/models/feature_settings.dart';
import 'package:running_on_dart/src/repository/feature_settings.dart';

class FeatureSettingsService {
  static final FeatureSettingsService instance = FeatureSettingsService._();

  FeatureSettingsService._();

  /// Returns whether a setting is enabled in a particular guild.
  Future<bool> isEnabled(Setting setting, Snowflake guildId) async =>
      await FeatureSettingsRepository.instance.isEnabled(setting, guildId);

  /// Enable a setting in a guild.
  Future<void> enable(FeatureSetting setting) async {
    await FeatureSettingsRepository.instance.enableSetting(setting);
  }

  /// Disable a setting in a guild.
  Future<void> disable(FeatureSetting setting) async {
    await FeatureSettingsRepository.instance.disableSetting(setting);
  }
}