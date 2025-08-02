import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/modules/bot_start_duration.dart';
import 'package:running_on_dart/src/modules/docs.dart';
import 'package:running_on_dart/src/modules/reminder.dart';
import 'package:running_on_dart/src/modules/tag.dart';

import 'package:running_on_dart/src/settings.dart' as settings;
import 'package:running_on_dart/src/util/util.dart';

class BotInfo {
  String get nyxxVersion => ApiOptions.nyxxVersion;
  String get version => settings.version;
  String get frontendVersion => settings.frontendVersion;
  String get dartPlatform => getDartPlatform();
  String get memoryUserString => getCurrentMemoryString();

  final int cachedGuilds;
  final int cachedUsers;
  final int cachedChannels;
  final int cachedVoiceStates;
  final int shardCount;
  final int cachedMessages;
  final int totalTagsCount;
  final int totalRemainderCount;
  final DateTime uptime;
  final DateTime? docsUpdate;

  BotInfo({
    required this.cachedGuilds,
    required this.cachedUsers,
    required this.cachedChannels,
    required this.cachedVoiceStates,
    required this.shardCount,
    required this.cachedMessages,
    required this.totalTagsCount,
    required this.totalRemainderCount,
    required this.uptime,
    required this.docsUpdate,
  });

  Map<String, dynamic> toJson() => {
    'nyxxVersion': nyxxVersion,
    'version': version,
    'platform': dartPlatform,
    'memoryUsageString': memoryUserString,
    'cachedChannels': cachedChannels,
    'cachedMessages': cachedMessages,
    'cachedGuilds': cachedGuilds,
    'cachedUsers': cachedUsers,
    'cachedVoiceStates': cachedVoiceStates,
    'shardCount': shardCount,
    'totalTagsCount': totalTagsCount,
    'totalReminderCount': totalRemainderCount,
    'uptime': uptime.toIso8601String(),
    'docsUpdate': docsUpdate?.toIso8601String(),
  };
}

class BotInfoService {
  final NyxxGateway client = Injector.appInstance.get();
  final TagModule tagModule = Injector.appInstance.get();
  final ReminderModule reminderModule = Injector.appInstance.get();
  final BotStartDuration startDurationModule = Injector.appInstance.get();
  final DocsModule docsModule = Injector.appInstance.get();

  Future<BotInfo> getCurrentBotInfo() async {
    final cachedGuilds = client.guilds.cache.length;
    final cachedUsers = client.users.cache.length;
    final cachedChannels = client.channels.cache.length;
    final cachedVoiceStates = client.guilds.cache.values
        .map((g) => g.voiceStates.length)
        .fold<num>(0, (value, element) => value + element)
        .ceil();
    final shardCount = client.gateway.shards.length;
    final cachedMessages = client.channels.cache.values
        .whereType<TextChannel>()
        .map((c) => c.messages.cache.length)
        .fold<num>(0, (value, element) => value + element)
        .ceil();
    final totalTags = await tagModule.countTags();
    final totalReminders = reminderModule.reminders.length;
    final botStartDateTime = startDurationModule.startDate;
    final docsUpdateDateTime = docsModule.lastUpdate;

    return BotInfo(
      cachedGuilds: cachedGuilds,
      cachedUsers: cachedUsers,
      cachedChannels: cachedChannels,
      cachedVoiceStates: cachedVoiceStates,
      shardCount: shardCount,
      cachedMessages: cachedMessages,
      totalTagsCount: totalTags,
      totalRemainderCount: totalReminders,
      uptime: botStartDateTime,
      docsUpdate: docsUpdateDateTime,
    );
  }
}
