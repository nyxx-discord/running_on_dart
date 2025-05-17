import 'dart:convert';

import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/repository/feature_settings.dart';
import 'package:running_on_dart/src/repository/jellyfin_config.dart';
import 'package:running_on_dart/src/repository/kavita.dart';
import 'package:running_on_dart/src/web_app/utils.dart';

Stream<JsonApiResponse> _mapJellyfinInstances(Snowflake guildId) async* {
  final jellyfinConfigRepository = Injector.appInstance.get<JellyfinConfigRepository>();

  for (final instance in await jellyfinConfigRepository.getConfigsForParent(guildId.toString())) {
    yield {
      'id': instance.id,
      'name': instance.name,
      'basePath': instance.basePath,
      'isDefault': instance.isDefault,
      'sonarrBasePath': instance.sonarrBasePath,
      'wizarrBasePath': instance.wizarrBasePath,
    };
  }
}

Stream<JsonApiResponse> _mapKavitaInstances(Snowflake guildId) async* {
  final kavitaConfigRepository = Injector.appInstance.get<KavitaRepository>();

  for (final instance in await kavitaConfigRepository.findAllForParent(guildId.toString())) {
    yield {'id': instance.id, 'name': instance.name, 'isDefault': instance.isDefault, 'basePath': instance.basePath};
  }
}

Future<JsonApiResponse> mapGuildFeaturesToData(Snowflake guildId) async {
  final featuresRepository = Injector.appInstance.get<FeatureSettingsRepository>();

  final features = await featuresRepository.fetchSettingsForGuild(guildId);

  final enabledFeaturesData =
      features
          .map(
            (f) => {
              'name': f.setting.name,
              'data': f.rawData != null ? jsonDecode(f.rawData!) : null,
              'enabledBy': f.whoEnabled.toString(),
              'enabledAt': f.addedAt.toIso8601String(),
            },
          )
          .toList();

  return {
    'enabledFeatures': enabledFeaturesData,
    'jellyfinInstances': await _mapJellyfinInstances(guildId).toList(),
    'kavitaInstances': await _mapKavitaInstances(guildId).toList(),
  };
}
