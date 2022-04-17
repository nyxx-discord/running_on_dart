import 'dart:io';

import 'package:nyxx/nyxx.dart';

/// Get a [String] from an environment variable, throwing an exception if it is not set.
///
/// If [def] is provided and the environment variable [key] is not set, [def] will be returned
/// instead of throwing an exception.
String getEnv(String key, [String? def]) => Platform.environment[key] ?? def ?? (throw Exception('Missing `$key` environment variable'));

/// Get a [bool] from an environment variable, throwing an exception if it is not set.
///
/// If [def] is provided and the environment variable [key] is not set, [def] will be returned
/// instead of throwing an exception.
bool getEnvBool(String key, [bool? def]) => ['true', '1'].contains(getEnv(key, def?.toString()).toLowerCase());

/// The token to use for this instance.
final String token = getEnv('ROD_TOKEN');

/// Whether to enable features requiring privileged intents for this instance.
final bool intentFeaturesEnabled = getEnvBool('ROD_INTENT_FEATURES_ENABLE');

/// The prefix to use for text commands for this instance.
final String prefix = getEnv('ROD_PREFIX');

/// The IDs of the users that are allowed to use administrator commands
final List<Snowflake> adminIds = getEnv('ROD_ADMIN_IDS').split(RegExp(r'\s+')).map(Snowflake.new).toList();

/// Whether this instance should run in development mode.
final bool dev = getEnvBool('ROD_DEV');

/// If this instance is in development mode, the ID of the guild to register commands to, else
/// `null`.
late final Snowflake? devGuildId = dev ? Snowflake(getEnv('ROD_DEV_GUILD_ID')) : null;

/// The basic intents needed to run Running on Dart without privileged intents.
final int _baseIntents = GatewayIntents.directMessages | GatewayIntents.guilds | GatewayIntents.guildVoiceState;

/// Privileged intents that can be enabled to add addtional features to Running on Dart.
final int _privilegedIntents = _baseIntents | GatewayIntents.guildMessages | GatewayIntents.guildMembers;

/// The intents to use for this instance.
final int intents = intentFeaturesEnabled ? _privilegedIntents : _baseIntents;
