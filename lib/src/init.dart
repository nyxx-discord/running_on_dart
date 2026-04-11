import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/modules/ban_relay.dart';
import 'package:running_on_dart/src/modules/bot_start_duration.dart';
import 'package:running_on_dart/src/modules/docs.dart';
import 'package:running_on_dart/src/modules/emoji_react_module.dart';
import 'package:running_on_dart/src/modules/jellyfin.dart';
import 'package:running_on_dart/src/modules/join_logs.dart';
import 'package:running_on_dart/src/modules/kavita.dart';
import 'package:running_on_dart/src/modules/mentions.dart';
import 'package:running_on_dart/src/modules/metrics.dart';
import 'package:running_on_dart/src/modules/mod_log.dart';
import 'package:running_on_dart/src/modules/poop_name.dart';
import 'package:running_on_dart/src/modules/reminder.dart';
import 'package:running_on_dart/src/modules/tag.dart';
import 'package:running_on_dart/src/repository/feature_settings.dart';
import 'package:running_on_dart/src/repository/jellyfin_config.dart';
import 'package:running_on_dart/src/repository/join_logs.dart';
import 'package:running_on_dart/src/repository/kavita.dart';
import 'package:running_on_dart/src/repository/mod_logs.dart';
import 'package:running_on_dart/src/repository/reminder.dart';
import 'package:running_on_dart/src/repository/tag.dart';
import 'package:running_on_dart/src/services/bot_info.dart';
import 'package:running_on_dart/src/services/db.dart';
import 'package:running_on_dart/src/modules/feature_settings.dart';

abstract class RequiresInitialization {
  Future<void> init();
}

abstract class Reloadable {
  Future<void> reload();
}

final reloadableModules = <String, Reloadable Function()>{
  'EmojiReactModule': () => Injector.appInstance.get<EmojiReactModule>(),
  'DocsModule': () => Injector.appInstance.get<DocsModule>(),
  'BanRelayModule': () => Injector.appInstance.get<BanRelayModule>(),
};

Future<void> setupContainer(NyxxGateway client) async {
  Injector.appInstance
    ..registerSingleton(() => client)
    ..registerSingleton(() => DatabaseService())
    ..registerSingleton(() => FeatureSettingsRepository())
    ..registerSingleton(() => JellyfinConfigRepository())
    ..registerSingleton(() => ReminderRepository())
    ..registerSingleton(() => TagRepository())
    ..registerSingleton(() => KavitaRepository())
    ..registerSingleton(() => JoinLogsRepository())
    ..registerSingleton(() => ModLogsRepository())
    ..registerSingleton(() => FeatureSettingsModule())
    ..registerSingleton(() => BotStartDuration())
    ..registerSingleton(() => PoopNameModule())
    ..registerSingleton(() => JoinLogsModule())
    ..registerSingleton(() => ReminderModule())
    ..registerSingleton(() => ModLogsModule())
    ..registerSingleton(() => TagModule())
    ..registerSingleton(() => DocsModule())
    ..registerSingleton(() => JellyfinModuleV2())
    ..registerSingleton(() => MentionsMonitoringModule())
    ..registerSingleton(() => KavitaModule())
    ..registerSingleton(() => EmojiReactModule())
    ..registerSingleton(() => BanRelayModule())
    ..registerSingleton(() => BotInfoService())
    ..registerSingleton(() => MetricsModule());

  await Injector.appInstance.get<DatabaseService>().init();
  await Injector.appInstance.get<FeatureSettingsModule>().init();
  await Injector.appInstance.get<JellyfinModuleV2>().init();
  await Injector.appInstance.get<DocsModule>().init();
  await Injector.appInstance.get<ModLogsModule>().init();
  await Injector.appInstance.get<ReminderModule>().init();
  await Injector.appInstance.get<JoinLogsModule>().init();
  await Injector.appInstance.get<PoopNameModule>().init();
  await Injector.appInstance.get<BotStartDuration>().init();
  await Injector.appInstance.get<MentionsMonitoringModule>().init();
  await Injector.appInstance.get<EmojiReactModule>().init();
  await Injector.appInstance.get<BanRelayModule>().init();
  await Injector.appInstance.get<MetricsModule>().init();
}
