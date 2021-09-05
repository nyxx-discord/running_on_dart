import "dart:async";

import "package:nyxx/nyxx.dart";
import "package:nyxx_interactions/interactions.dart";
import "package:running_on_dart/src/internal/utils.dart";
import "package:running_on_dart/src/modules/settings/FeatureSettings.dart";

import "package:running_on_dart/src/internal/db.dart" as db;

const nickNamePoopingSettingName = "poop_name";
const memberJoinLogsSettingName = "join_logs";

const availableFeatureSettings = {
  nickNamePoopingSettingName: "Replace nicknames of members with poop emoji if member tries to hoist it's position with nickname",
  memberJoinLogsSettingName: "Logs member join events into specified channel",
};

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

const intentsMembers =
  GatewayIntents.allUnprivileged
  | GatewayIntents.guildMembers;

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
    yield ArgChoiceBuilder(featureEntry.key, featureEntry.value);
  }
}

FutureOr<String?> prefixHandler(Message message) async => envPrefix;

final cacheOptions = CacheOptions()
  ..memberCachePolicyLocation = CachePolicyLocation.none()
  ..userCachePolicyLocation = CachePolicyLocation.none();

const privilegedAdminSnowflakes = [
  302359032612651009,
  281314080923320321,
  612653298532745217
];

Future<void> deleteFeatureSettings(Snowflake guildId, String name) async {
  await db.connection.transaction((connection) async {
    await connection.execute("""
      DELETE FROM feature_settings_additional_data sd JOIN
      feature_settings s ON s.id = sd.feature_setting_id
      WHERE name = @name AND guild_id = @guild_id;
    """);

    await connection.execute("""
      DELETE FROM feature_settings WHERE name = @name AND guild_id = @guild_id;
    """);
  });
}

Future<void> addFeatureSettings(Snowflake guildId, String name, Snowflake whoEnabled, {Map<String, dynamic>? additionalData}) async {
  const query = """
    INSERT INTO feature_settings (name, guild_id, add_date, who_enabled)
    VALUES (@name, @guildId, NOW(), @whoEnabled) RETURNING id;
  """;

  await db.connection.transaction((connection) async {
    final result = await connection.query(query, substitutionValues: {
      "name": name,
      "guildId": guildId.toString(),
      "whoEnabled": whoEnabled.toString()
    });

    if (result.isEmpty) {
      connection.cancelTransaction(reason: "Unexpected error occurred during saving to database [0]");
      throw CommandExecutionException("Unexpected error occurred during saving to database [0]");
    }

    if (additionalData == null) {
      return;
    }

    final additionalDataQueryBuilder = StringBuffer()
      ..write("INSERT INTO feature_settings_additional_data(name, data, feature_setting_id) VALUES ");

    final buffer = <String>[];
    final substitutionValues = {
      "featureId": result.first[0]
    };

    final additionalDataEntries = additionalData.entries.toList();
    for (var i = 0; i < additionalData.entries.length; i++) {
      final entry = additionalDataEntries[i];

      buffer.add("(key$i, value$i, @featureId)");
      substitutionValues["key$i"] = entry.key;
      substitutionValues["value$i"] = entry.value;
    }

    additionalDataQueryBuilder.write(buffer.join(","));
    additionalDataQueryBuilder.write(";");

    final additionalDataResult = await connection.execute(
        additionalDataQueryBuilder.toString(),
        substitutionValues: substitutionValues
    );

    if (additionalDataResult == 0) {
      connection.cancelTransaction(reason: "Unexpected error occurred during saving to database [1]");
      throw CommandExecutionException("Unexpected error occurred during saving to database [1]");
    }
  });
}

Future<Map<String, dynamic>?> fetchAdditionalData(int featureSettingId) async {
  const query = """
    SELECT sad.data, sad.name as additionalData FROM feature_settings_additional_data sad
    WHERE sad.feature_setting_id = @id;
  """;

  final result = await db.connection.mappedResultsQuery(query, substitutionValues: {
    "id": featureSettingId
  });

  if (result.isEmpty) {
    return null;
  }

  final finalResult = <String, dynamic>{};
  for (final row in result) {
    finalResult[row["sad"]!["name"].toString()] = row["sad"]!["data"];
  }
  return finalResult;
}

Future<FeatureSettings?> fetchFeatureSettings(Snowflake guildId, String name) async {
  const query = """
    SELECT s.id as id, s.name as name, s.guild_id as guildId FROM feature_settings s 
    WHERE s.guild_id = @guildId AND s.name = @name;
  """;

  final result = await db.connection.query(query, substitutionValues: {
    "guildId": guildId.toString(),
    "name": name
  });

  if (result.isEmpty) {
    return null;
  }

  return FeatureSettings(result.first.toColumnMap());
}

class CommandExecutionException implements Exception {
  final String message;

  CommandExecutionException(this.message);
}
