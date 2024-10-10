import 'package:injector/injector.dart';
import 'package:logging/logging.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/models/reminder.dart';

class ReminderRepository {
  final Logger _logger = Logger('ROD.ReminderRepository');
  final _database = Injector.appInstance.get<DatabaseService>();

  Future<Reminder?> fetchReminder(int id) async {
    final result =
        await _database.getConnection().execute('SELECT * FROM reminders WHERE id = @id', parameters: {'id': id});
    if (result.isEmpty || result.length > 1) {
      throw Exception("Empty or multiple reminder with same id");
    }

    return Reminder.fromRow(result.first.toColumnMap());
  }

  /// Fetch all reminders currently in the database.
  Future<Iterable<Reminder>> fetchReminders() async {
    final result = await _database.getConnection().execute('SELECT * FROM reminders WHERE trigger_date > now()');

    return result.map((row) => row.toColumnMap()).map(Reminder.fromRow);
  }

  /// Delete a reminder from the database.
  Future<void> deleteReminder(Reminder reminder) async {
    final id = reminder.id;

    if (id == null) {
      return;
    }

    await _database.getConnection().execute('DELETE FROM reminders WHERE id = @id', parameters: {
      'id': id,
    });
  }

  /// Add a reminder to the database.
  Future<Reminder> addReminder(Reminder reminder) async {
    if (reminder.id != null) {
      _logger.warning('Attempting to add reminder with id ${reminder.id} twice, ignoring');
      return reminder;
    }

    final result = await _database.getConnection().execute('''
    INSERT INTO reminders (
      user_id,
      channel_id,
      message_id,
      trigger_date,
      add_date,
      message
    ) VALUES (
      @user_id,
      @channel_id,
      @message_id,
      @trigger_date,
      @add_date,
      @message
    ) RETURNING id;
  ''', parameters: {
      'user_id': reminder.userId.toString(),
      'channel_id': reminder.channelId.toString(),
      'message_id': reminder.messageId?.toString(),
      'trigger_date': reminder.triggerAt.toUtc(),
      'add_date': reminder.addedAt.toUtc(),
      'message': reminder.message,
    });

    reminder.id = result.first.first as int;
    return reminder;
  }
}
