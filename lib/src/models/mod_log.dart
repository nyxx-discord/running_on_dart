import 'package:nyxx/nyxx.dart';

class ModLogEntry {
  final int id;
  final Snowflake guildId;
  final Snowflake messageId;
  final int actionType;
  final Snowflake targetUserId;
  final Snowflake moderatorUserId;
  final String? reason;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Snowflake? updatedBy;
  final Map<String, dynamic>? additionalData;

  ModLogEntry({
    required this.id,
    required this.guildId,
    required this.messageId,
    required this.actionType,
    required this.targetUserId,
    required this.moderatorUserId,
    required this.reason,
    required this.createdAt,
    required this.updatedAt,
    required this.updatedBy,
    required this.additionalData,
  });

  factory ModLogEntry.fromDatabaseRow(Map<String, dynamic> row) {
    return ModLogEntry(
      id: row['id'] as int,
      guildId: Snowflake.parse(row['guild_id']),
      messageId: Snowflake.parse(row['message_id']),
      actionType: row['action_type'] as int,
      targetUserId: Snowflake.parse(row['target_user_id']),
      moderatorUserId: Snowflake.parse(row['moderator_user_id']),
      reason: row['reason'] as String?,
      createdAt: row['created_at'] as DateTime,
      updatedAt: row['updated_at'] as DateTime?,
      updatedBy: row['updated_by'] == null ? null : Snowflake.parse(row['updated_by']),
      additionalData: row['additional_data'] as Map<String, dynamic>?,
    );
  }
}
