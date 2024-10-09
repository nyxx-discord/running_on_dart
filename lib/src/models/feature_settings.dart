import 'dart:convert';

import 'package:nyxx/nyxx.dart';

enum DataType {
  channelMention,
  json,
}

enum Setting {
  poopName('poop_name', 'Replace nickname of a member with poop emoji if the member tries to hoist itself', false),
  joinLogs('join_logs', 'Logs member join events into specified channel', true, DataType.channelMention),
  modLogs('mod_logs', 'Logs administration event into specified channel', true, DataType.channelMention),
  jellyfin('jellyfin', 'Allows usage of jellyfin commands', true, DataType.json);

  /// name of setting
  final String name;

  /// A description of this setting.
  final String description;

  /// Whether this setting requires extra data (beyond being enabled or not).
  final bool requiresData;

  /// Type of data
  final DataType? type;

  const Setting(this.name, this.description, this.requiresData, [this.type]);
}

/// The value of a setting within a guild.
class FeatureSetting {
  /// The setting being represented.
  final Setting setting;

  /// The data attached to this setting.
  final String? data;

  /// The ID of the guild this setting belongs to.
  final Snowflake guildId;

  /// The ID of the member who enabled or updated this feature.
  final Snowflake whoEnabled;

  /// The time this feature was enabled or updated.
  final DateTime addedAt;

  Map<String, dynamic>? get dataAsJson => data != null ? jsonDecode(data!) : null;

  FeatureSetting({
    required this.setting,
    required this.guildId,
    required this.whoEnabled,
    required this.addedAt,
    required this.data,
  });

  /// Create an instance of [GuildSetting] from a database row.
  factory FeatureSetting.fromRow(Map<String, dynamic> row) {
    return FeatureSetting(
      setting: Setting.values.singleWhere((setting) => setting.name == row['name']),
      guildId: Snowflake.parse(row['guild_id']),
      whoEnabled: Snowflake.parse(row['who_enabled']),
      addedAt: row['add_date'] as DateTime,
      data: row['additional_data'] as String?,
    );
  }
}
