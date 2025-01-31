import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/modules/tag.dart';
import 'package:running_on_dart/src/repository/feature_settings.dart';
import 'package:running_on_dart/src/web_app/mapper/features_mapper.dart';
import 'package:running_on_dart/src/web_app/utils.dart';

JsonApiResponse mapChannelToData(Channel channel) {
  final data = <String, dynamic>{
    'id': channel.id.toString(),
    'type': channel.type.value,
  };

  if (channel is GuildChannel) {
    data.addAll({
      'position': channel.position,
      'isNsfw': channel.isNsfw,
      'parentId': channel.parentId.toString(),
      'name': channel.name,
    });
  }

  if (channel is TextChannel) {
    data.addAll({
      'rateLimitPerUser': channel.rateLimitPerUser?.inSeconds,
      'lastPinTimestamp': channel.lastPinTimestamp?.toIso8601String(),
      'cachedMessages': channel.messages.cache.length,
    });
  }

  if (channel is VoiceChannel) {
    data.addAll({
      'bitrate': channel.bitrate,
      'userLimit': channel.userLimit,
      'rtcRegion': channel.rtcRegion,
      'videoQualityMode': channel.videoQualityMode.value,
    });
  }

  if (channel is Thread) {
    data.addAll({
      'approximateMemberCount': channel.approximateMemberCount,
      'isArchived': channel.isArchived,
      'isLocked': channel.isLocked,
      'createdAt': channel.createdAt.toIso8601String(),
      'totalMessagesSent': channel.totalMessagesSent,
      'appliedTags': channel.appliedTags?.map((s) => s.toString()),
      'owner': {
        "id": channel.owner.id,
      },
    });
  }

  if (channel is ThreadsOnlyChannel) {
    data.addAll({
      'topic': channel.topic,
      'lastThreadId': channel.lastThreadId?.toString(),
    });
  }

  return data;
}

Stream<JsonApiResponse> mapGuildsToGuildReducedData(Iterable<Guild> guilds) async* {
  final client = Injector.appInstance.get<NyxxGateway>();
  final tagModule = Injector.appInstance.get<TagModule>();
  final featureSettingsRepository = Injector.appInstance.get<FeatureSettingsRepository>();

  for (final guild in guilds) {
    final guildChannels = client.channels.cache.values.whereType<GuildChannel>().where((c) => c.guildId == guild.id);

    final guildCachedMessages =
        guildChannels.whereType<TextChannel>().fold(0, (previous, channel) => previous + channel.messages.cache.length);

    final enabledFeatures =
        (await featureSettingsRepository.fetchSettingsForGuild(guild.id)).map((s) => s.setting.name);

    final tagsCount = tagModule.getGuildTags(guild.id).length;

    yield {
      'id': guild.id.toString(),
      'name': guild.name,
      'banner': guild.bannerHash,
      'icon': guild.iconHash,
      'cachedMembers': guild.members.cache.length,
      'cachedChannels': guildChannels.length,
      'cachedMessages': guildCachedMessages,
      'cachedRoles': guild.roles.cache.length,
      'enabledFeatures': enabledFeatures.toList(),
      'tagsCount': tagsCount,
    };
  }
}

Future<JsonApiResponse> mapGuildToDetailsData(Guild guild, int channelsLimit, int rolesLimit, int tagsLimit) async {
  final client = Injector.appInstance.get<NyxxGateway>();

  final roles = rolesLimit > 0
      ? guild.roles.cache.values
          .take(rolesLimit)
          .map((r) => {
                "id": r.id.toString(),
                "name": r.name.toString(),
                "position": r.position,
                "isHoisted": r.isHoisted,
                "color": r.color.toHexString(),
                "icon": r.iconHash,
                "flags": r.flags.value,
                "permission": r.permissions.value
              })
          .toList()
      : [];

  final channels = channelsLimit > 0
      ? client.channels.cache.values
          .whereType<GuildChannel>()
          .where((c) => c.guildId == guild.id)
          .take(channelsLimit)
          .map((c) => mapChannelToData(c))
          .toList()
      : [];

  return {
    'id': guild.id.toString(),
    'name': guild.name,
    'banner': guild.bannerHash,
    'icon': guild.iconHash,
    'roles': roles,
    'channels': channels,
    'features': await mapGuildFeaturesToData(guild.id),
  };
}

JsonApiResponse mapMemberToData(Guild guild, Member member) {
  return {
    'id': member.id.toString(),
    'nick': member.nick,
    'avatar': member.avatarHash,
    'user': {
      'avatar': member.user?.avatarHash,
      'username': member.user?.globalName ?? member.user?.username,
    }
  };
}
