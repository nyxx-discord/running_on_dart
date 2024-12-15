import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';

import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/web_app/jwt.dart';
import 'package:running_on_dart/src/web_app/mapper/guild_mapper.dart';
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

    final guildData = await mapGuildsToGuildReducedData(client.guilds.cache.values).toList();

    return createOkResponse(guildData);
  }

  Future<shelf.Response> _handleGuildDetails(shelf.Request request) async {
    final client = Injector.appInstance.get<NyxxGateway>();

    final guildParam = request.params['id'];
    if (guildParam == null) {
      return createBadRequestResponse("Missing id param");
    }

    final includeRoles = request.requestedUri.queryParameters['includeRoles'] ?? null;
    final includeChannels = request.requestedUri.queryParameters['includeChannels'] ?? null;

    try {
      final guild = await client.guilds.get(Snowflake.parse(guildParam));

      return createOkResponse(await mapGuildToDetailsData(guild, includeRoles, includeChannels));
    } on HttpResponseError {
      return createNotFoundResponse();
    }
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
      // ..get("/api/guilds/<id>", _requireJwt(_handleGuildDetails, [JwtPermission.guilds]))
      ..get("/api/guilds/<id>", _handleGuildDetails)
      ..get("/api/validate-oauth", _handleValidateCode)
      ..all(r"/<ignored|.+\w+\.\w+$>", staticHandler)
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
