import "dart:io" show Platform, ProcessInfo;

import "package:nyxx/nyxx.dart";
import "package:nyxx_interactions/nyxx_interactions.dart";

String? get envPrefix => Platform.environment["ROD_PREFIX"];
String? get envHotReload => Platform.environment["ROD_HOT_RELOAD"];
String? get envToken => Platform.environment["ROD_TOKEN"];
bool get enabledIntentFeatures => isBool(Platform.environment["ROD_INTENT_FEATURES_ENABLE"]);
bool get syncCommands => isBool(Platform.environment["SYNC_COMMANDS"]);
bool get debug => isBool(Platform.environment["ROD_DEBUG"]);
bool get isTest => isBool(Platform.environment["ROD_TEST"]);

Snowflake? get testGuildSnowflake => isTest ? Snowflake(302360552993456135) : null;

bool getSyncCommandsOrOverride([bool? overrideSync]) => overrideSync ?? syncCommands;

bool isBool(String? value) {
  return value != null && (value == "true" || value == "1");
}

String get dartVersion {
  final platformVersion = Platform.version;
  return platformVersion.split("(").first;
}

String getMemoryUsageString() {
  final current = (ProcessInfo.currentRss / 1024 / 1024).toStringAsFixed(2);
  final rss = (ProcessInfo.maxRss / 1024 / 1024).toStringAsFixed(2);
  return "$current/${rss}MB";
}

Snowflake getAuthorId(IInteractionEvent event) => event.interaction.guild?.id != null ? event.interaction.memberAuthor!.id : event.interaction.userAuthor!.id;
