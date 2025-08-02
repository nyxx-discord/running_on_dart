import 'dart:async';

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

class BanRelayModule implements RequiresInitialization, Reloadable {
  final NyxxGateway _client = Injector.appInstance.get();

  final Map<Snowflake, List<BanAssociation>> banRelayAssociations = {};

  @override
  Future<void> init() async {
    await _loadAssociations();

    _client.onGuildBanAdd.listen((event) => _handleBanAction(event.guildId, event.user.id));
    _client.onGuildBanRemove.listen((event) => _handleBanAction(event.guildId, event.user.id));
  }

  @override
  Future<void> reload() async {
    await _loadAssociations();
  }

  Future<void> _loadAssociations() async {
    banRelayAssociations.clear();

    final settingRepository = Injector.appInstance.get<FeatureSettingsRepository>();
    final settings = await settingRepository.fetchSettingsForType(Setting.banRelay);
    for (final setting in settings) {
      final data = setting.parseData<BanRelayData>();
      if (data == null) {
        throw StateError("ban_relay setting data cannot be null");
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
  }

  Future<void> _handleBanAction(Snowflake guildId, Snowflake userId) async {
    final banRelayDetails = banRelayAssociations[guildId];
    if (banRelayDetails == null) {
      return;
    }

    for (final banAssociation in banRelayDetails) {
      final guild = await _client.guilds.get(banAssociation.guildId);

      if (banAssociation.unban) {
        return guild.deleteBan(userId, auditLogReason: "Unban relayed from: $guildId");
      }

      return guild.createBan(userId, auditLogReason: "Ban relayed from: $guildId");
    }
  }
}
