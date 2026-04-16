import 'package:nyxx/nyxx.dart';

class JoinLogFlags {
  static const int none = 0;
  static const int newUser = 1 << 0;
  static const int suspicious = 1 << 1;
}

class JoinLogEntry {
  final int id;
  final Snowflake userId;
  final String username;
  final Snowflake guildId;
  final Snowflake? messageId;
  final DateTime createdAt;
  final DateTime? leftAt;
  final int flags;

  JoinLogEntry({
    required this.id,
    required this.userId,
    required this.username,
    required this.guildId,
    required this.messageId,
    required this.createdAt,
    required this.leftAt,
    required this.flags,
  });

  factory JoinLogEntry.fromDatabaseRow(Map<String, dynamic> row) {
    return JoinLogEntry(
      id: row['id'] as int,
      userId: Snowflake.parse(row['user_id']),
      username: row['username'] as String,
      guildId: Snowflake.parse(row['guild_id']),
      messageId: row['message_id'] == null ? null : Snowflake.parse(row['message_id']),
      createdAt: row['created_at'] as DateTime,
      leftAt: row['left_at'] as DateTime?,
      flags: row['flags'] as int,
    );
  }

  bool hasFlag(int flag) => (flags & flag) != 0;
}

class JellyfinConfigUserData {
  final String instanceName;
  final String instanceBaseBath;
  final bool instanceIsDefault;
  final String? userId;

  JellyfinConfigUserData({
    required this.instanceName,
    required this.instanceBaseBath,
    required this.instanceIsDefault,
    this.userId,
  });

  factory JellyfinConfigUserData.fromDatabaseRow(Map<String, dynamic> row) {
    return JellyfinConfigUserData(
      instanceName: row['instance_name'],
      instanceBaseBath: row['instance_base_path'],
      instanceIsDefault: row['instance_is_default'] as bool,
      userId: row['user_id'],
    );
  }
}
