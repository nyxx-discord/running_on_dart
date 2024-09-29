import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:running_on_dart/src/models/feature_settings.dart';
import 'package:running_on_dart/src/repository/feature_settings.dart';
import 'package:running_on_dart/src/services/feature_settings.dart';
import 'package:running_on_dart/src/settings.dart';

final administratorCheck = UserCheck.anyId(adminIds, name: 'Administrator check');

final jellyfinFeatureEnabledCheck = Check(
  (CommandContext context) {
    if (context.guild == null) {
      return true;
    }

    return FeatureSettingsService.instance.isEnabled(Setting.jellyfin, context.guild!.id);
  },
);

Future<(bool?, FeatureSetting?)> fetchAndCheckSetting(CommandContext context) async {
  if (context.guild == null) {
    return (true, null);
  }

  final setting = await FeatureSettingsRepository.instance.fetchSetting(Setting.jellyfin, context.guild!.id);
  if (setting == null) {
    return (false, null);
  }

  if (setting.dataAsJson == null) {
    return (false, null);
  }

  return (null, setting);
}

final jellyfinFeatureUserCommandCheck = Check(
  (CommandContext context) async {
    final (checkResult, setting) = await fetchAndCheckSetting(context);
    if (checkResult != null) {
      return checkResult;
    }

    final roleId = Snowflake.parse(setting!.dataAsJson!['user_commands_role']);

    return context.member!.roleIds.contains(roleId);
  },
);

final jellyfinFeatureAdminCommandCheck = Check(
  (CommandContext context) async {
    final (checkResult, setting) = await fetchAndCheckSetting(context);
    if (checkResult != null) {
      return checkResult;
    }

    final roleId = Snowflake.parse(setting!.dataAsJson!['admin_commands_role']);

    return context.member!.roleIds.contains(roleId);
  },
);

final jellyfinFeatureCreateInstanceCommandCheck = Check(
  (CommandContext context) async {
    final (checkResult, setting) = await fetchAndCheckSetting(context);
    if (checkResult != null) {
      return checkResult;
    }

    final roleId = Snowflake.parse(setting!.dataAsJson!['create_instance_role']);

    return context.member!.roleIds.contains(roleId);
  },
);
