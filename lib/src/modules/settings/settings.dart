import "dart:async" show Future, FutureOr, Stream;

import "package:nyxx/nyxx.dart";
import "package:nyxx_interactions/nyxx_interactions.dart";
import "package:running_on_dart/src/internal/db.dart" as db;
import "package:running_on_dart/src/internal/utils.dart" show enabledIntentFeatures, envPrefix, envToken;
import "package:running_on_dart/src/modules/settings/feature_settings.dart" show FeatureSettings;

const nickNamePoopingSettingName = "poop_name";
const memberJoinLogsSettingName = "join_logs";

const availableFeatureSettings = {
  nickNamePoopingSettingName: "$nickNamePoopingSettingName: Replace nickname of member with poop emoji if member tries to hoist",
  memberJoinLogsSettingName: "$memberJoinLogsSettingName: Logs member join events into specified channel",
};

const featureSettingsThatNeedsAdditionalData = {
  memberJoinLogsSettingName: true,
};

// TODO: Commander requires GatewayIntents.allUnprivileged but thats actually stupid because I cannot specify my intents
// const intents =
//   GatewayIntents.guilds
//   | GatewayIntents.guildBans
//   | GatewayIntents.guildEmojis
//   | GatewayIntents.guildIntegrations
//   | GatewayIntents.guildWebhooks
//   | GatewayIntents.guildInvites
//   | GatewayIntents.guildVoiceState
//   | GatewayIntents.guildMessages
//   | GatewayIntents.directMessages
//   | GatewayIntents.guildMembers;

const intentsMembers = GatewayIntents.allUnprivileged | GatewayIntents.guildMembers;

const intentsNoMembers = GatewayIntents.allUnprivileged;

int get setIntents {
  if (enabledIntentFeatures) {
    return intentsMembers;
  }

  return intentsNoMembers;
}

String get botToken => envToken!;

Iterable<ArgChoiceBuilder> getFeaturesAsChoices() sync* {
  for (final featureEntry in availableFeatureSettings.entries) {
    yield ArgChoiceBuilder(featureEntry.value, featureEntry.key);
  }
}

FutureOr<String?> prefixHandler(IMessage message) async => envPrefix;

final cacheOptions = CacheOptions()
  ..memberCachePolicyLocation = CachePolicyLocation.none()
  ..userCachePolicyLocation = CachePolicyLocation.none();

const privilegedAdminSnowflakes = [302359032612651009, 281314080923320321, 612653298532745217];

Future<void> deleteFeatureSettings(Snowflake guildId, String name) async {
  await db.connection.execute("""
      DELETE FROM feature_settings WHERE name = @name AND guild_id = @guildId;
    """, substitutionValues: {
    "name": name,
    "guildId": guildId.toString(),
  });
}

Future<void> addFeatureSettings(Snowflake guildId, String name, Snowflake whoEnabled, {String? additionalData}) async {
  const query = """
    INSERT INTO feature_settings(name, guild_id, add_date, who_enabled, additional_data)
    VALUES (@name, @guildId, CURRENT_TIMESTAMP, @whoEnabled, @additionalData) RETURNING id;
  """;

  final result = await db.connection
      .query(query, substitutionValues: {"name": name, "guildId": guildId.toString(), "whoEnabled": whoEnabled.toString(), "additionalData": additionalData});

  if (result.isEmpty) {
    throw CommandExecutionException("Unexpected error occurred during saving to database [0]");
  }
}

Future<FeatureSettings?> fetchFeatureSettings(Snowflake guildId, String name) async {
  const query = """
    SELECT s.id as id, s.name as name, s.guild_id as guild_id, s.additional_data as additional_data FROM feature_settings s 
    WHERE s.guild_id = @guildId AND s.name = @name;
  """;

  final result = await db.connection.query(query, substitutionValues: {"guildId": guildId.toString(), "name": name});

  if (result.isEmpty) {
    return null;
  }

  return FeatureSettings(result.first.toColumnMap());
}

Stream<FeatureSettings> fetchEnabledFeatureForGuild(Snowflake guildId) async* {
  const query = """
    SELECT s.id as id, s.name as name, s.guild_id as guild_id, s.additional_data as additional_data FROM feature_settings s 
    WHERE s.guild_id = @guildId;
  """;

  final result = await db.connection.query(query, substitutionValues: {"guildId": guildId.toString()});

  if (result.isEmpty) {
    yield* const Stream.empty();
  }

  for (final row in result) {
    FeatureSettings(row.toColumnMap());
  }
}

class CommandExecutionException implements Exception {
  final String message;

  CommandExecutionException(this.message);
}
