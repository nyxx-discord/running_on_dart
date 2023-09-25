import 'package:intl/intl.dart';
import 'package:nyxx/nyxx.dart';
import 'package:postgres/postgres.dart';

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
  factory Reminder.fromRow(PostgreSQLResultRow row) {
    final mappedRow = row.toColumnMap();

    return Reminder(
      userId: Snowflake(mappedRow['user_id'] as String),
      channelId: Snowflake(mappedRow['channel_id'] as String),
      messageId: mappedRow['message_id'] != null
          ? Snowflake(mappedRow['message_id'] as String)
          : null,
      triggerAt: mappedRow['trigger_date'] as DateTime,
      addedAt: mappedRow['add_date'] as DateTime,
      message: mappedRow['message'] as String,
      id: mappedRow['id'] as int,
    );
  }
}

/// A [DateFormat] used to format the trigger times of reminders
DateFormat reminderDateFormat = DateFormat.yMd()..add_Hm();
