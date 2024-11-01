import 'dart:convert';

import 'package:injector/injector.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/api/jwt_middleware.dart';
import 'package:running_on_dart/src/api/utils.dart';
import 'package:running_on_dart/src/modules/bot_start_duration.dart';

import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:http/http.dart' as http;

final clientId = getEnv('DISCORD_CLIENT_ID');
final clientSecret = getEnv('DISCORD_CLIENT_SECRET');
final clientRedirectUri = getEnv('DISCORD_REDIRECT_URI');

class WebServer {
  Future<shelf.Response> _handleBotInfo(shelf.Request request) async {
    final botStartDuration = Injector.appInstance.get<BotStartDuration>();

    return shelf.Response.ok(jsonEncode({"ok": true, 'uptime': botStartDuration.startDate.toIso8601String()}),
        headers: {'Content-Type': 'application/json'});
  }

  Future<shelf.Response> _handleLogin(shelf.Request request) async {
    final requestBody = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final authCode = requestBody['code'];

    final response = await http.post(Uri.https('discord.com', '/api/oauth2/token'), body: {
      'client_id': clientId,
      'client_secret': clientSecret,
      'redirect_uri': clientRedirectUri,
      'grant_type': 'authorization_code',
      'code': authCode,
    }, headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    });

    if (response.statusCode != 200) {
      return createJsonErrorResponse(400, "Cannot login through discord. Try again");
    }

    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = responseBody['access_token'];

    final authorizedUserResponse = await http.get(Uri.https('discord.com', '/api/oauth2/@me'),
        headers: {"Accept": 'application/json', 'Authorization': 'Bearer $accessToken'});

    if (authorizedUserResponse.statusCode != 200) {
      return createJsonErrorResponse(400, "Cannot fetch user data from discord!");
    }

    final authorizedUserResponseBody = jsonDecode(authorizedUserResponse.body) as Map<String, dynamic>;

    final jwtToken = generateJwtKey(authorizedUserResponseBody['user']['id'],
        authorizedUserResponseBody['user']['global_name'] ?? authorizedUserResponseBody['user']['username']);

    return shelf.Response.ok(jsonEncode({'token': jwtToken}));
  }

  Future<shelf_router.Router> _setupRouter() async {
    return shelf_router.Router()
      ..get("/api/info", _handleBotInfo)
      ..post("/api/login", _handleLogin);
    // ..get("/api/test", _authorized(_handleBotInfo));
  }

  shelf.Handler _authorized(shelf.Handler inner) =>
      const shelf.Pipeline().addMiddleware(jwtMiddleware()).addHandler(inner);

  Future<void> startServer() async {
    final router = await _setupRouter();

    final app =
        const shelf.Pipeline().addMiddleware(shelf.logRequests()).addMiddleware(corsHeaders()).addHandler(router.call);

    await shelf_io.serve(app, "0.0.0.0", 8088);
  }
}
