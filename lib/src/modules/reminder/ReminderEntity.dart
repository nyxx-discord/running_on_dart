import "package:nyxx/nyxx.dart";

class ReminderEntity {
  late final int id;
  late final Snowflake userId;
  late final Snowflake channelId;
  late final Snowflake messageId;
  late final DateTime addDate;
  late final DateTime triggerDate;
  late final String message;

  ReminderEntity(Map<String, dynamic> raw) {
    this.id = raw["id"] as int;
    this.userId = Snowflake(raw["user_id"]);
    this.channelId = Snowflake(raw["channel_id"]);
    this.messageId = Snowflake(raw["message_id"]);
    this.addDate = DateTime.parse(raw["add_date"].toString());
    this.triggerDate = DateTime.parse(raw["trigger_date"].toString());
    this.message = raw["message"] as String;
  }
}
