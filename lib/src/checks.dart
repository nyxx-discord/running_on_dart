import 'dart:async';

import 'package:injector/injector.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:running_on_dart/src/models/feature_settings.dart';
import 'package:running_on_dart/src/repository/feature_settings.dart';
import 'package:running_on_dart/src/modules/feature_settings.dart';
import 'package:running_on_dart/src/settings.dart';

const jellyfinFeatureEnabledCheckName = 'jellyfinFeatureEnabledCheck';
const minecraftFeatureEnabledCheckName = 'minecraftFeatureEnabledCheck';

final administratorCheck = UserCheck.anyId(adminIds, name: 'Administrator check');
final administratorGuildCheck = GuildCheck.id(adminGuildId, name: 'Administrator Guild check');

FutureOr<bool> _checkForSetting(Setting setting, CommandContext context) {
  if (context.guild == null) {
    return true;
  }

  return Injector.appInstance.get<FeatureSettingsModule>().isEnabled(setting, context.guild!.id);
}

final kavitaJellyfinCheck = Check(
  (CommandContext context) => _checkForSetting(Setting.kavita, context),
  name: jellyfinFeatureEnabledCheckName,
);

final jellyfinFeatureEnabledCheck = Check(
  (CommandContext context) => _checkForSetting(Setting.jellyfin, context),
  name: jellyfinFeatureEnabledCheckName,
);

final minecraftFeatureEnabledCheck = Check(
  (CommandContext context) => _checkForSetting(Setting.minecraft, context),
  name: minecraftFeatureEnabledCheckName,
);

Future<(bool?, FeatureSetting?)> fetchAndCheckSetting(CommandContext context, Setting settingToCheck) async {
  if (context.guild == null) {
    return (true, null);
  }

  final setting = await Injector.appInstance.get<FeatureSettingsRepository>().fetchSetting(
    settingToCheck,
    context.guild!.id,
  );
  if (setting == null) {
    return (false, null);
  }

  if (setting.rawData == null) {
    return (false, null);
  }

  return (null, setting);
}

final jellyfinFeatureCreateInstanceCommandCheck = Check((CommandContext context) async {
  final (checkResult, setting) = await fetchAndCheckSetting(context, Setting.jellyfin);
  if (checkResult != null) {
    return checkResult;
  }

  if (context.member?.permissions?.isAdministrator ?? false) {
    return true;
  }

  final data = setting?.parseData<GenericInstanceData>();
  return context.member!.roleIds.contains(data?.createInstanceRole);
});

final kavitaFeatureCreateInstanceCommandCheck = Check((CommandContext context) async {
  final (checkResult, setting) = await fetchAndCheckSetting(context, Setting.kavita);
  if (checkResult != null) {
    return checkResult;
  }

  if (context.member?.permissions?.isAdministrator ?? false) {
    return true;
  }

  final data = setting?.parseData<GenericInstanceData>();
  return context.member!.roleIds.contains(data?.createInstanceRole);
});
