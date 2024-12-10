import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';

import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/modules/tag.dart';
import 'package:running_on_dart/src/repository/feature_settings.dart';
import 'package:running_on_dart/src/web_app/jwt.dart';
import 'package:running_on_dart/src/web_app/utils.dart';
import 'package:running_on_dart/src/services/bot_info.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:http/http.dart' as http;
import 'package:shelf_static/shelf_static.dart';

final clientId = getEnv('DISCORD_CLIENT_ID');
final clientSecret = getEnv('DISCORD_CLIENT_SECRET');
final clientRedirectUri = getEnv('DISCORD_REDIRECT_URI');

class WebServer {
  final Logger _logger = Logger('ROD.WebServer');

  Future<shelf.Response> _handleGuilds(shelf.Request request) async {
    final client = Injector.appInstance.get<NyxxGateway>();
    final tagModule = Injector.appInstance.get<TagModule>();

    final guildData = Stream.fromIterable(client.guilds.cache.values).asyncMap((entry) async {
      final guildChannels = client.channels.cache.values.whereType<GuildChannel>().where((c) => c.guildId == entry.id);

      final guildCachedMessages = guildChannels
          .whereType<TextChannel>()
          .fold(0, (previous, channel) => previous + channel.messages.cache.length);

      final enabledFeatures =
          (await Injector.appInstance.get<FeatureSettingsRepository>().fetchSettingsForGuild(entry.id))
              .map((s) => s.setting.name);

      final tagsCount = tagModule.getGuildTags(entry.id).length;

      return {
        'id': entry.id.toString(),
        'name': entry.name,
        'banner': entry.bannerHash,
        'icon': entry.iconHash,
        'cachedMembers': entry.members.cache.length,
        'cachedChannels': guildChannels.length,
        'cachedMessages': guildCachedMessages,
        'cachedRoles': entry.roles.cache.length,
        'enabledFeatures': enabledFeatures.toList(),
        'tagsCount': tagsCount,
      };
    });

    return createOkResponse(await guildData.toList());
  }

  Future<shelf.Response> _handleServerInfo(shelf.Request request) async {
    final data = await Injector.appInstance.get<BotInfoService>().getCurrentBotInfo();

    return createOkResponse(data.toJson());
  }

  Future<shelf.Response> _handleValidateCode(shelf.Request request) async {
    final authCode = request.url.queryParameters['code'];

    final tokenResponse = await http.post(Uri.https('discord.com', '/api/oauth2/token'), body: {
      'client_id': clientId,
      'client_secret': clientSecret,
      'redirect_uri': clientRedirectUri,
      'grant_type': 'authorization_code',
      'code': authCode,
    }, headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    });

    final tokenBodyJson = jsonDecode(tokenResponse.body);
    final token = tokenBodyJson['access_token'];

    final userData = await http.get(Uri.https('discord.com', '/api/oauth2/@me'), headers: {
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    });
    final userDataJson = jsonDecode(userData.body);

    final guildsData = await http.get(Uri.https('discord.com', '/api/users/@me/guilds'), headers: {
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    });
    final guildsDataJson = jsonDecode(guildsData.body);

    final userId = userDataJson['user']['id'] as String;

    final permissions = adminIds.contains(Snowflake.parse(userId)) ? JwtPermission.intValues() : <int>[];

    final jwtResponse = generateJwtResponse(userId,
        userData: {
          'id': userDataJson['user']['id'],
          'name': userDataJson['user']['global_name'] ?? userDataJson['user']['username'],
          'avatar': userDataJson['user']['avatar'],
          'guilds': guildsDataJson.map((guildData) => guildData['id']).toList(),
        },
        permissions: permissions);

    return createOkResponse(jwtResponse);
  }

  Future<shelf.Response> _handleIndex(shelf.Request request) async {
    final content = await File('public/index.html').readAsString();

    return shelf.Response.ok(content, headers: {'content-type': 'text/html'});
  }

  Future<shelf_router.Router> _setupRouter() async {
    final staticHandler = createStaticHandler('public');

    return shelf_router.Router()
      ..get("/api/server-info", _handleServerInfo)
      ..get("/api/guilds", _requireJwt(_handleGuilds, [JwtPermission.guilds]))
      ..get("/api/validate-oauth", _handleValidateCode)
      ..all(r"/<ignored|static/.*.\w+|[^/]+.\w+>", staticHandler)
      ..all("/<ignored|.*>", _handleIndex);
  }

  shelf.Handler _requireJwt(shelf.Handler inner, [List<JwtPermission> permissions = const []]) =>
      shelf.Pipeline().addMiddleware(processJwt(permissions)).addHandler(inner);

  Future<void> startServer() async {
    if (!webServerEnabled) {
      _logger.info("Web server not enabled skipping");
      return;
    }

    final router = await _setupRouter();

    final app =
        const shelf.Pipeline().addMiddleware(shelf.logRequests()).addMiddleware(corsHeaders()).addHandler(router.call);

    _logger.info("Starting server at: http://$webServerHost:$webServerPort/");
    await shelf_io.serve(app, webServerHost, webServerPort);
  }
}
