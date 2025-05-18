import 'dart:async';

import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/models/feature_settings.dart';
import 'package:running_on_dart/src/repository/feature_settings.dart';
import 'package:running_on_dart/src/init.dart';

class FeatureSettingsModule implements RequiresInitialization {
  final _featureSettingsRepository = Injector.appInstance.get<FeatureSettingsRepository>();

  final StreamController<FeatureSetting> _onFeatureEnabled = StreamController.broadcast();
  final StreamController<FeatureSetting> _onFeatureDisabled = StreamController.broadcast();

  late Stream<FeatureSetting> onFeatureEnabled;
  late Stream<FeatureSetting> onFeatureDisabled;

  @override
  Future<void> init() async {
    onFeatureDisabled = _onFeatureDisabled.stream;
    onFeatureEnabled = _onFeatureEnabled.stream;
  }

  Future<(bool, FeatureSetting?)> fetchSetting(Setting setting, Snowflake guildId) async {
    final result = await _featureSettingsRepository.fetchSetting(setting, guildId);

    return (result != null, result);
  }

  /// Returns whether a setting is enabled in a particular guild.
  Future<bool> isEnabled(Setting setting, Snowflake guildId) async =>
      await _featureSettingsRepository.isEnabled(setting, guildId);

  /// Enable a setting in a guild.
  Future<void> enable(FeatureSetting setting) async {
    await _featureSettingsRepository.enableSetting(setting);
    _onFeatureEnabled.add(setting);
  }

  /// Disable a setting in a guild.
  Future<void> disable(FeatureSetting setting) async {
    await _featureSettingsRepository.disableSetting(setting);
    _onFeatureDisabled.add(setting);
  }
}
