import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/models/reminder.dart';
import 'package:running_on_dart/src/modules/reminder.dart';
import 'package:running_on_dart/src/web_app/mapper/pagination_mapper.dart';
import 'package:running_on_dart/src/web_app/utils.dart';

JsonApiResponse _mapReminder(Reminder reminder) {
  return {
    'id': reminder.id,
    'channelId': reminder.channelId,
    'userId': reminder.userId,
    'messageId': reminder.userId,
    'triggerAt': reminder.triggerAt.toIso8601String(),
    'addedAt': reminder.addedAt.toIso8601String(),
    'message': reminder.message,
  };
}

Future<JsonApiResponse> mapRemindersToData(Snowflake guildId, int limit,
    {String? searchQuery, int page = 1, String? createdBy}) async {
  final reminderModule = Injector.appInstance.get<ReminderModule>();

  var reminders = reminderModule.getRemindersForGuild(guildId);
  if (searchQuery != null) {
    reminders = reminders.where((r) => r.message.contains(searchQuery));
  }

  return createPaginationResponse(
    data: reminders.skip(limit * (page - 1)).take(limit).map(_mapReminder).toList(),
    total: reminders.length,
    perPage: limit,
    page: page,
  );
}
