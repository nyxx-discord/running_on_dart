import 'dart:io';

import 'package:nyxx/nyxx.dart';

String get version => '3.3.1';

/// Get a [String] from an environment variable, throwing an exception if it is not set.
///
/// If [def] is provided and the environment variable [key] is not set, [def] will be returned
/// instead of throwing an exception.
String getEnv(String key, [String? def]) =>
    Platform.environment[key] ??
    def ??
    (throw Exception('Missing `$key` environment variable'));

/// Get a [bool] from an environment variable, throwing an exception if it is not set.
///
/// If [def] is provided and the environment variable [key] is not set, [def] will be returned
/// instead of throwing an exception.
bool getEnvBool(String key, [bool? def]) =>
    ['true', '1'].contains(getEnv(key, def?.toString()).toLowerCase());

/// The token to use for this instance.
final String token = getEnv('ROD_TOKEN');

/// Whether to enable features requiring privileged intents for this instance.
final bool intentFeaturesEnabled = getEnvBool('ROD_INTENT_FEATURES_ENABLE');

/// The prefix to use for text commands for this instance.
final String prefix = getEnv('ROD_PREFIX');

final Snowflake adminGuildId = Snowflake(getEnv('ROD_ADMIN_GUILD'));

/// The IDs of the users that are allowed to use administrator commands
final List<Snowflake> adminIds =
    getEnv('ROD_ADMIN_IDS').split(RegExp(r'\s+')).map(Snowflake.new).toList();

/// The interval at which to update the docs cache.
final Duration docsUpdateInterval =
    Duration(seconds: int.parse(getEnv('ROD_DOCS_UPDATE_INTERVAL', '900')));

/// The packages to cache documentation for.
final List<String> docsPackages = getEnv('ROD_DOCS_PACKAGES',
        'nyxx nyxx_interactions nyxx_commands nyxx_lavalink nyxx_extensions')
    .split(RegExp(r'\s+'));

/// The default response for the docs command.
final String defaultDocsResponse = getEnv('ROD_DEFAULT_DOCS_RESPONSE', '''
__Guides, documentation and development documentation__:
<https://nyxx.l7ssha.xyz>

__Package documentation__:
${docsPackages.map((packageName) => '- $packageName: <https://pub.dev/documentation/$packageName/latest>').join('\n')}

__Dart documentation__:
- Main documentation: <https://dart.dev/guides>
- API reference: <https://api.dart.dev>
- Codelabs: <https://dart.dev/codelabs>
''');

/// The default response for the github command.
final String defaultGithubResponse = getEnv('ROD_DEFAULT_GITHUB_RESPONSE', '''
nyxx is an open source project hosted on GitHub.

__Roadmap__:
<https://github.com/orgs/nyxx-discord/projects/2>

__Package repositories__:
${docsPackages.map((packageName) => '- $packageName: <https://github.com/nyxx-discord/$packageName>').join('\n')}
''');

/// The GitHub account to use when no other account is specified.
final String githubAccount = getEnv('ROD_GITHUB_ACCOUNT', 'nyxx-discord');

/// The GitHub Personal Access Token to use when authenticating with the GitHub API.
final String githubToken = getEnv('ROD_GITHUB_TOKEN');

/// Whether this instance should run in development mode.
final bool dev = getEnvBool('ROD_DEV');

/// If this instance is in development mode, the ID of the guild to register commands to, else
/// `null`.
final Snowflake? devGuildId =
    dev ? Snowflake(getEnv('ROD_DEV_GUILD_ID')) : null;

/// The address of the lavalink running server to connect to.
String serverAddress = getEnv('LAVALINK_ADDRESS', 'lavalink');

/// The port of the lavalink running server to use to connect.
int serverPort = int.parse(getEnv('LAVALINK_PORT', '2333'));

/// The password used to connect to the lavalink server.
String serverPassword = getEnv('LAVALINK_PASSWORD', 'youshallnotpass');

/// Whether to use or not ssl to establish a connection.
bool useSSL = getEnvBool('LAVALINK_USE_SSL', false);

/// The basic intents needed to run Running on Dart without privileged intents.
final int _baseIntents = GatewayIntents.directMessages |
    GatewayIntents.guilds |
    GatewayIntents.guildVoiceState;

/// Privileged intents that can be enabled to add additional features to Running on Dart.
final int _privilegedIntents = _baseIntents |
    GatewayIntents.guildMessages |
    GatewayIntents.guildMembers |
    GatewayIntents.messageContent;

/// The intents to use for this instance.
final int intents = intentFeaturesEnabled ? _privilegedIntents : _baseIntents;
