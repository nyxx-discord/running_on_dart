import "dart:async";

import "package:nyxx/nyxx.dart";
import "package:running_on_dart/src/internal/utils.dart";

const intents =
  GatewayIntents.guilds
  | GatewayIntents.guildBans
  | GatewayIntents.guildEmojis
  | GatewayIntents.guildIntegrations
  | GatewayIntents.guildWebhooks
  | GatewayIntents.guildInvites
  | GatewayIntents.guildVoiceState
  | GatewayIntents.guildMessages
  | GatewayIntents.directMessages
  | GatewayIntents.guildMembers;

String get botToken => envToken!;

FutureOr<String?> prefixHandler(Message message) async => envPrefix;

final cacheOptions = CacheOptions()
  ..memberCachePolicyLocation = CachePolicyLocation.none()
  ..userCachePolicyLocation = CachePolicyLocation.none();
