import 'dart:convert';

import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/util/util.dart';

enum DataType { channelMention, json, string }

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
  emojiReact<EmojiReactData>('emoji_react', 'React to predefined words with emojis', true);

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
