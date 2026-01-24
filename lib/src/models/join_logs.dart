import 'package:nyxx/nyxx.dart';

class JoinLogEntry {
  final Snowflake userId;
  final Snowflake guildId;
  final Snowflake messageId;
  final DateTime createdAt;

  JoinLogEntry({required this.userId, required this.guildId, required this.messageId, required this.createdAt});

  factory JoinLogEntry.fromDatabaseRow(Map<String, dynamic> row) {
    return JoinLogEntry(
      userId: Snowflake.parse(row['user_id']),
      guildId: Snowflake.parse(row['guild_id']),
      messageId: Snowflake.parse(row['message_id']),
      createdAt: row['created_at'] as DateTime,
    );
  }
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
