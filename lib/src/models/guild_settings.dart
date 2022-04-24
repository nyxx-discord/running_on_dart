import 'package:nyxx/nyxx.dart';
import 'package:postgres/postgres.dart';

/// A setting identifier, used outside of a guild.
class Setting<T> extends IEnum<String> {
  /// The poop_name feature flag.
  static const Setting<void> poopName = Setting._('poop_name', 'Replace nickname of a member with poop emoji if the member tries to hoist', false);

  /// The join_logs feature flag.
  static const Setting<Snowflake> joinLogs = Setting._('join_logs', 'Logs member join events into specified channel');

  /// A list of all available settings.
  static const List<Setting<dynamic>> values = [poopName, joinLogs];

  /// A description of this setting.
  final String description;

  /// Whether this setting requires extra data (beyond being enabled or not).
  final bool requiresData;

  const Setting._(String value, this.description, [this.requiresData = true]) : super(value);
}

/// The value of a setting within a guild.
class GuildSetting<T> {
  /// The setting being represented.
  final Setting<T> setting;

  /// The data attached to this setting.
  final T data;

  /// The ID of the guild this setting belongs to.
  final Snowflake guildId;

  /// The ID of the member who enabled or updated this feature.
  final Snowflake whoEnabled;

  /// The time this feature was enabled or updated.
  final DateTime addedAt;

  /// Create an instance of a [GuildSetting].
  ///
  /// If `T` is not `void` or [Null], [data] is required.
  GuildSetting({
    required this.setting,
    required this.guildId,
    required this.whoEnabled,
    required this.addedAt,
    T? data,
  }) : data = data as T;

  /// Create an instance of [GuildSetting], parsing [data] to the appropriate type for the chosen setting.
  factory GuildSetting.withData({
    required Setting<T> setting,
    required Snowflake guildId,
    required Snowflake whoEnabled,
    required DateTime addedAt,
    String? data,
  }) {
    dynamic resolvedData;

    if (setting == Setting.poopName) {
      resolvedData = null;
    } else if (setting == Setting.joinLogs) {
      resolvedData = Snowflake(data);
    }

    return GuildSetting(
      setting: setting,
      guildId: guildId,
      whoEnabled: whoEnabled,
      addedAt: addedAt,
      data: resolvedData as T,
    );
  }

  /// Create an instance of [GuildSetting] from a database row.
  factory GuildSetting.fromRow(PostgreSQLResultRow row) {
    Map<String, dynamic> mappedRow = row.toColumnMap();

    return GuildSetting.withData(
      setting: Setting.values.singleWhere((setting) => setting.value == mappedRow['name']) as Setting<T>,
      guildId: Snowflake(mappedRow['guild_id']),
      whoEnabled: Snowflake(mappedRow['who_enabled']),
      addedAt: mappedRow['add_date'] as DateTime,
      data: mappedRow['additional_data'] as String?,
    );
  }

  GuildSetting<E> cast<E>() => GuildSetting(
        setting: setting as Setting<E>,
        guildId: guildId,
        whoEnabled: whoEnabled,
        addedAt: addedAt,
        data: data as E,
      );
}
