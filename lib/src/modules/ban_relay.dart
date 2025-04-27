import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';

import 'package:running_on_dart/src/init.dart';
import 'package:running_on_dart/src/models/feature_settings.dart';
import 'package:running_on_dart/src/repository/feature_settings.dart';

class BanAssociation {
  final Snowflake guildId;
  final bool unban;
  final bool ensureBan;

  BanAssociation(this.guildId, this.unban, this.ensureBan);
}

class BanRelayModule implements RequiresInitialization {
  final NyxxGateway _client = Injector.appInstance.get();

  late final Map<Snowflake, List<BanAssociation>> banRelayAssociations = {};

  @override
  Future<void> init() async {
    final settingRepository = Injector.appInstance.get<FeatureSettingsRepository>();

    final settings = await settingRepository.fetchSettingsForType(Setting.banRelay);
    for (final setting in settings) {
      final data = setting.parseData<BanRelayData>();
      if (data == null) {
        throw StateError("ban_relay setting cannot have null data");
      }

      for (final targetGuild in data.relayedGuilds) {
        final banAssociation = BanAssociation(setting.guildId, data.unban, data.ensureBan);

        if (!banRelayAssociations.containsKey(targetGuild)) {
          banRelayAssociations[targetGuild] = [banAssociation];

          continue;
        }

        banRelayAssociations[targetGuild]!.add(banAssociation);
      }
    }

    _client.onGuildBanAdd.listen((event) => _handleGuildBan(event));
  }

  Future<void> _handleGuildBan(GuildBanAddEvent event) async {
    final banRelayDetails = banRelayAssociations[event.guildId];
    if (banRelayDetails == null) {
      return;
    }

    for (final banAssociation in banRelayDetails) {
      _banUser(event.user.id, banAssociation, event.guildId);
    }
  }

  Future<void> _banUser(Snowflake userId, BanAssociation banAssociation, Snowflake originalBanGuild) async {
    final guild = await _client.guilds.get(banAssociation.guildId);

    var memberToBan = guild.members.cache[userId];
    if (memberToBan == null && banAssociation.ensureBan) {
      memberToBan = await guild.members.fetch(userId);
    }

    if (memberToBan == null) {
      return;
    }

    return memberToBan.ban(auditLogReason: "Ban relayed from: $originalBanGuild");
  }
}
