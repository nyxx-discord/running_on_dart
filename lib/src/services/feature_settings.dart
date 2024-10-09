import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/models/feature_settings.dart';
import 'package:running_on_dart/src/repository/feature_settings.dart';

class FeatureSettingsService {
  final _featureSettingsRepository = Injector.appInstance.get<FeatureSettingsRepository>();

  /// Returns whether a setting is enabled in a particular guild.
  Future<bool> isEnabled(Setting setting, Snowflake guildId) async =>
      await _featureSettingsRepository.isEnabled(setting, guildId);

  /// Enable a setting in a guild.
  Future<void> enable(FeatureSetting setting) async {
    await _featureSettingsRepository.enableSetting(setting);
  }

  /// Disable a setting in a guild.
  Future<void> disable(FeatureSetting setting) async {
    await _featureSettingsRepository.disableSetting(setting);
  }
}
