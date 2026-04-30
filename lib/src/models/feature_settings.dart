import 'dart:convert';

import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/util/util.dart';

abstract class SettingData {
  Map<String, dynamic> toJson();
}

class NoData implements SettingData {
  @override
  Map<String, dynamic> toJson() => throw Exception();
}

class GenericSnowflakeData implements SettingData {
  final Snowflake value;

  GenericSnowflakeData({required this.value});

  factory GenericSnowflakeData.fromJson(Map<String, dynamic> raw) {
    return GenericSnowflakeData(value: Snowflake.parse(raw['value']));
  }

  @override
  Map<String, dynamic> toJson() {
    return {'value': value.toString()};
  }
}

/// Example: {"create_instance_role":"419506523467939853"}
class GenericInstanceData implements SettingData {
  final Snowflake createInstanceRole;

  GenericInstanceData({required this.createInstanceRole});

  factory GenericInstanceData.fromJson(Map<String, dynamic> raw) {
    return GenericInstanceData(createInstanceRole: Snowflake.parse(raw['create_instance_role']));
  }

  @override
  Map<String, dynamic> toJson() {
    return {'create_instance_role': createInstanceRole.toString()};
  }
}

enum EmojiReactType {
  react('react'),
  message('message');

  final String name;

  const EmojiReactType(this.name);
}

/// Example: {"use_builtin": true|false, "mode": "react|message", "process_other_bots": true|false}
class EmojiReactData implements SettingData {
  final bool useBuiltin;
  final EmojiReactType mode;
  final bool processOtherBots;

  EmojiReactData({required this.useBuiltin, required this.mode, required this.processOtherBots});

  factory EmojiReactData.fromJson(Map<String, dynamic> raw) {
    return EmojiReactData(
      useBuiltin: boolValue(raw['use_builtin']),
      mode: EmojiReactType.values.byName(raw['mode']),
      processOtherBots: boolValue(raw['process_other_bots']),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {"use_builtin": useBuiltin, "mode": mode.name, "process_other_bots": processOtherBots};
  }
}

class BanRelayData implements SettingData {
  final Iterable<Snowflake> relayedGuilds;
  final bool unban;

  BanRelayData({required this.relayedGuilds, required this.unban});

  factory BanRelayData.fromConfiguration(Map<String, dynamic> raw) {
    return BanRelayData(
      relayedGuilds: (raw['relayed_guilds'] as String).split(',').map((s) => s.trim()).map((s) => Snowflake.parse(s)),
      unban: boolValue(raw['unban']),
    );
  }

  factory BanRelayData.fromJson(Map<String, dynamic> raw) {
    return BanRelayData(
      relayedGuilds: (raw['relayed_guilds'] as Iterable).map((e) => Snowflake.parse(e)),
      unban: boolValue(raw['unban']),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {'relayed_guilds': relayedGuilds.map((e) => e.toString()).toList()};
  }
}

/// Minecraft server configuration data
/// Example: {"host":"localhost", "port":25575, "password":"secret", "admin_users":["123456789","987654321"]}
class MinecraftData implements SettingData {
  final String host;
  final int port;
  final String password;
  final List<Snowflake> adminUsers;

  MinecraftData({required this.host, required this.port, required this.password, required this.adminUsers});

  factory MinecraftData.fromJson(Map<String, dynamic> raw) {
    return MinecraftData(
      host: raw['host'] as String,
      port: raw['port'] as int,
      password: raw['password'] as String,
      adminUsers: (raw['admin_users'] as Iterable).map((e) => Snowflake.parse(e)).toList(),
    );
  }

  factory MinecraftData.fromConfiguration(Map<String, dynamic> raw) {
    return MinecraftData(
      host: raw['host'] as String,
      port: int.parse(raw['port']),
      password: raw['password'] as String,
      adminUsers: (raw['admin_users'] as String)
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .map((s) => Snowflake.parse(s))
          .toList(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'host': host,
      'port': port,
      'password': password,
      'admin_users': adminUsers.map((e) => e.toString()).toList(),
    };
  }

  /// Check if a user is an admin for this Minecraft server
  bool isAdmin(Snowflake userId) {
    return adminUsers.contains(userId);
  }
}

enum Setting<T extends SettingData> {
  poopName<NoData>(
    'poop_name',
    'Replace nickname of a member with poop emoji if the member tries to hoist itself',
    false,
  ),
  joinLogs<GenericSnowflakeData>('join_logs', 'Logs member join events into specified channel', true),
  modLogs<GenericSnowflakeData>('mod_logs', 'Logs administration event into specified channel', true),
  jellyfin<GenericInstanceData>('jellyfin', 'Allows usage of jellyfin commands', true),
  mentions<NoData>('mentions', 'Monitors messages for mention abuse', false),
  kavita<GenericInstanceData>('kavita', 'Allows usage of jellyfin command', true),
  emojiReact<EmojiReactData>('emoji_react', 'React to predefined words with emojis', true),
  banRelay<BanRelayData>('ban_relay', 'Relay ban from other guilds to this', true),
  minecraft<MinecraftData>('minecraft', 'Minecraft server RCON integration', true);

  /// name of setting
  final String name;

  /// A description of this setting.
  final String description;

  /// Whether this setting requires extra data (beyond being enabled or not).
  final bool requiresData;

  const Setting(this.name, this.description, this.requiresData);

  T? parseData(Map<String, dynamic>? raw) {
    if (raw == null) {
      return null;
    }

    return switch (T) {
          const (GenericSnowflakeData) => GenericSnowflakeData.fromJson(raw),
          const (GenericInstanceData) => GenericInstanceData.fromJson(raw),
          const (EmojiReactData) => EmojiReactData.fromJson(raw),
          const (BanRelayData) => BanRelayData.fromJson(raw),
          const (MinecraftData) => MinecraftData.fromJson(raw),
          _ => null,
        }
        as T?;
  }

  T? parseFromConfiguration(Map<String, dynamic>? raw) {
    if (raw == null) {
      return null;
    }

    return switch (T) {
          const (GenericSnowflakeData) || const (GenericInstanceData) || const (EmojiReactData) => parseData(raw),
          const (BanRelayData) => BanRelayData.fromConfiguration(raw),
          const (MinecraftData) => MinecraftData.fromConfiguration(raw),
          _ => null,
        }
        as T?;
  }

  List<TextInputBuilder> getConfigurationFields() {
    return switch (T) {
      const (GenericSnowflakeData) => [
        TextInputBuilder(customId: 'value', style: TextInputStyle.short, label: "Target Snowflake"),
      ],
      const (GenericInstanceData) => [
        TextInputBuilder(customId: 'create_instance_role', style: TextInputStyle.short, label: "Target Role Snowflake"),
      ],
      const (EmojiReactData) => [
        TextInputBuilder(customId: 'use_builtin', style: TextInputStyle.short, label: "Use built in emotes (yes/no)"),
        TextInputBuilder(
          customId: 'mode',
          style: TextInputStyle.short,
          label: "Mode name (${EmojiReactType.values.map((e) => e.name).join(', ')})",
        ),
        TextInputBuilder(
          customId: 'process_other_bots',
          style: TextInputStyle.short,
          label: "Process messages of other bots (yes/no)",
        ),
      ],
      const (BanRelayData) => [
        TextInputBuilder(
          customId: 'relayed_guilds',
          style: TextInputStyle.paragraph,
          label: "List of guilds ids (comma separated)",
        ),
        TextInputBuilder(
          customId: 'unban',
          style: TextInputStyle.short,
          label: "Also unban when unbanned (yes/no)",
        ),
      ],
      const (MinecraftData) => [
        TextInputBuilder(
          customId: 'host',
          style: TextInputStyle.short,
          label: "Server host (e.g., localhost or example.com)",
        ),
        TextInputBuilder(customId: 'port', style: TextInputStyle.short, label: "RCON port (default: 25575)"),
        TextInputBuilder(customId: 'password', style: TextInputStyle.short, label: "RCON password"),
        TextInputBuilder(
          customId: 'admin_users',
          style: TextInputStyle.paragraph,
          label: "Admin Discord user IDs (comma separated)",
        ),
      ],
      _ => throw Error(),
    };
  }
}

/// The value of a setting within a guild.
class FeatureSetting {
  /// The setting being represented.
  final Setting setting;

  /// The data attached to this setting.
  final String? rawData;

  /// The ID of the guild this setting belongs to.
  final Snowflake guildId;

  /// The ID of the member who enabled or updated this feature.
  final Snowflake whoEnabled;

  /// The time this feature was enabled or updated.
  final DateTime addedAt;

  FeatureSetting({
    required this.setting,
    required this.guildId,
    required this.whoEnabled,
    required this.addedAt,
    required this.rawData,
  });

  factory FeatureSetting.create({
    required Setting setting,
    required Snowflake guildId,
    required Snowflake whoEnabled,
    SettingData? data,
  }) {
    return FeatureSetting(
      setting: setting,
      guildId: guildId,
      whoEnabled: whoEnabled,
      addedAt: DateTime.now(),
      rawData: data != null ? jsonEncode(data.toJson()) : null,
    );
  }

  T? parseData<T extends SettingData>() {
    if (rawData == null) {
      return null;
    }

    return setting.parseData(jsonDecode(rawData!)) as T?;
  }

  /// Create an instance of [GuildSetting] from a database row.
  factory FeatureSetting.fromRow(Map<String, dynamic> row) {
    return FeatureSetting(
      setting: Setting.values.singleWhere((setting) => setting.name == row['name']),
      guildId: Snowflake.parse(row['guild_id']),
      whoEnabled: Snowflake.parse(row['who_enabled']),
      addedAt: row['add_date'] as DateTime,
      rawData: row['additional_data'] as String?,
    );
  }
}
