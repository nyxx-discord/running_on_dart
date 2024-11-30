import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';

import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/modules/tag.dart';
import 'package:running_on_dart/src/repository/feature_settings.dart';
import 'package:running_on_dart/src/web_app/mustache.dart';
import 'package:running_on_dart/src/web_app/session_manager_plugin.dart';
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
  final Logger _logger = Logger('ROD.WebServer');

  Future<shelf.Response> _handleSessions(shelf.Request request) async {
    if (!isAdminFromSession(request)) {
      return shelf.Response.forbidden(null);
    }

    final sessions = jsonDecode(await File(sessionsFile).readAsString()) as Map<String, dynamic>;

    return MustacheResponse(name: "sessions.html", parameters: {
      'sessions': sessions.values.toList(),
    });
  }

  Future<shelf.Response> _handleGuilds(shelf.Request request) async {
    if (!isAdminFromSession(request)) {
      return shelf.Response.forbidden(null);
    }

    final client = Injector.appInstance.get<NyxxGateway>();
    final tagModule = Injector.appInstance.get<TagModule>();

    final guildData = Stream.fromIterable(client.guilds.cache.values).asyncMap((entry) async {
      final guildChannels = client.channels.cache.values.whereType<GuildChannel>().where((c) => c.guildId == entry.id);

      final guildCachedMessages = guildChannels
          .whereType<TextChannel>()
          .fold(0, (previous, channel) => previous + channel.messages.cache.length);

      final enabledFeatures =
          (await Injector.appInstance.get<FeatureSettingsRepository>().fetchSettingsForGuild(entry.id))
              .map((s) => s.setting.name)
              .join(", ");

      final tagsCount = tagModule.getGuildTags(entry.id).length;

      return {
        'id': entry.id.toString(),
        'name': entry.name,
        'banner': entry.bannerHash,
        'icon': entry.iconHash,
        'cached_members': entry.members.cache.length,
        'cached_channels': guildChannels.length,
        'cached_messages': guildCachedMessages,
        'cached_roles': entry.roles.cache.length,
        'enabled_features': enabledFeatures.isNotEmpty ? enabledFeatures : "None enabled",
        'tags_count': tagsCount,
      };
    });

    return MustacheResponse(name: "guilds.html", parameters: {
      'guilds': await guildData.toList(),
    });
  }

  Future<shelf.Response> _handleIndex(shelf.Request request) async {
    final data = await Injector.appInstance.get<BotInfoService>().getCurrentBotInfo();

    return MustacheResponse(name: "index.html", parameters: {
      ...data.toJson(),
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

    final userData = await http.get(Uri.https('discord.com', '/api/oauth2/@me'), headers: {
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    });
    final userDataJson = jsonDecode(userData.body);

    initSession(request, userDataJson);

    return shelf.Response.seeOther("/");
  }

  Future<shelf.Response> _handleLogOut(shelf.Request request) async {
    deleteSession(request);

    return shelf.Response.seeOther("/");
  }

  Future<shelf_router.Router> _setupRouter() async {
    return shelf_router.Router()
      ..get("/", _sessionAware(_processMustache(_handleIndex)))
      ..get('/sessions', _sessionAware(_processMustache(_handleSessions)))
      ..get("/guilds", _sessionAware(_processMustache(_handleGuilds)))
      ..get("/redirect", _sessionAware(_handleRedirect))
      ..get("/logout", _sessionAware(_handleLogOut));
  }

  shelf.Handler _processMustache(shelf.Handler inner) =>
      shelf.Pipeline().addMiddleware(processMustache()).addHandler(inner);

  shelf.Handler _sessionAware(shelf.Handler inner) =>
      shelf.Pipeline().addMiddleware(cookiesMiddleware()).addMiddleware(sessionMiddleware()).addHandler(inner);

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
