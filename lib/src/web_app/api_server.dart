import 'dart:convert';

import 'package:injector/injector.dart';

import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/web_app/utils.dart';
import 'package:running_on_dart/src/services/bot_info.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:http/http.dart' as http;
import 'package:shelf_session/cookies_middleware.dart';
import 'package:shelf_session/session_middleware.dart';

final clientId = getEnv('DISCORD_CLIENT_ID');
final clientSecret = getEnv('DISCORD_CLIENT_SECRET');
final clientRedirectUri = getEnv('DISCORD_REDIRECT_URI');

class WebServer {
  Future<shelf.Response> _handleIndex(shelf.Request request) async {
    final data = await Injector.appInstance.get<BotInfoService>().getCurrentBotInfo();

    return createTwigResponse("index.html", parameters: {
      ...data.toJson(),
      'clientId': clientId,
      'redirectUri': clientRedirectUri,
      'user_data': Session.getSession(request)?.data['user_data'] ?? false,
    });
  }

  Future<shelf.Response> _handleRedirect(shelf.Request request) async {
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

    print(tokenResponse.body);
    print(tokenResponse.statusCode);

    final userData = await http.get(Uri.https('discord.com', '/api/oauth2/@me'), headers: {
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    });

    final userDataJson = jsonDecode(userData.body);
    print(userData.body);
    print(userData.statusCode);

    var session = Session.getSession(request);
    session ??= Session.createSession(request);
    session.data['user_data'] = {
      'id': userDataJson['user']['id'],
      'name': userDataJson['user']['global_name'] ?? userDataJson['user']['username'],
      'avatar': userDataJson['user']['avatar'],
      'expires_at': userDataJson['expires'],
      'token': token,
    };
    session.expires = DateTime.now().add(Duration(seconds: tokenBodyJson['expires_in']));

    return shelf.Response.seeOther("/");
  }

  Future<shelf.Response> _handleLogOut(shelf.Request request) async {
    Session.deleteSession(request);

    return shelf.Response.seeOther("/");
  }

  Future<shelf_router.Router> _setupRouter() async {
    return shelf_router.Router()
      ..get("/", _sessionAware(_handleIndex))
      ..get("/redirect", _sessionAware(_handleRedirect))
      ..get("/logout", _sessionAware(_handleLogOut));
  }

  shelf.Handler _sessionAware(shelf.Handler inner) =>
      shelf.Pipeline().addMiddleware(cookiesMiddleware()).addMiddleware(sessionMiddleware()).addHandler(inner);

  Future<void> startServer() async {
    final router = await _setupRouter();

    final app =
        const shelf.Pipeline().addMiddleware(shelf.logRequests()).addMiddleware(corsHeaders()).addHandler(router.call);

    await shelf_io.serve(app, "0.0.0.0", 8088);
  }
}
