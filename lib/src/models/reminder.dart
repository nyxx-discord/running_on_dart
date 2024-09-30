import 'package:intl/intl.dart';
import 'package:nyxx/nyxx.dart';

/// A [DateFormat] used to format the trigger times of reminders
final reminderDateFormat = DateFormat.yMd()..add_Hm();

/// A reminder created by a user.
class Reminder {
  /// The ID of the user that created this reminder.
  final Snowflake userId;

  /// The ID of the channel in which this reminder was created.
  final Snowflake channelId;

  /// The ID of the message used to create this reminder, if any.
  final Snowflake? messageId;

  /// The time at which this reminder should trigger.
  final DateTime triggerAt;

  /// The time at which this reminder was created.
  final DateTime addedAt;

  /// The message attached to this reminder.
  final String message;

  /// The ID of this reminder, or `null` if this reminder has not yet been added to the database.
  int? id;

  /// Create a new [Reminder].
  Reminder({
    required this.userId,
    required this.channelId,
    required this.messageId,
    required this.triggerAt,
    required this.addedAt,
    required this.message,
    this.id,
  });

  /// Create a [Reminder] from a database row.
  factory Reminder.fromRow(Map<String, dynamic> row) {
    return Reminder(
      userId: Snowflake.parse(row['user_id'] as String),
      channelId: Snowflake.parse(row['channel_id'] as String),
      messageId: row['message_id'] != null ? Snowflake.parse(row['message_id'] as String) : null,
      triggerAt: row['trigger_date'] as DateTime,
      addedAt: row['add_date'] as DateTime,
      message: row['message'] as String,
      id: row['id'] as int,
    );
  }
}
