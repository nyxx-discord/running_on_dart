import 'dart:io';

import 'package:injector/injector.dart';
import 'package:mustachex/mustachex.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/api/utils.dart';
import 'package:running_on_dart/src/services/bot_info.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

final clientId = getEnv('DISCORD_CLIENT_ID');
final clientSecret = getEnv('DISCORD_CLIENT_SECRET');
final clientRedirectUri = getEnv('DISCORD_REDIRECT_URI');

class WebServer {
  Future<shelf.Response> _handleBotInfo(shelf.Request request) async {
    final botInfo = await Injector.appInstance.get<BotInfoService>().getCurrentBotInfo();

    return createOkResponse(botInfo.toJson());
  }

  // Future<shelf.Response> _handleGuildInfo(shelf.Request request) async {
  //   final outputJson = Injector.appInstance.get<NyxxGateway>().guilds.cache.values.map((guild) {
  //     return <String, dynamic>{
  //       "id": guild.id.toString(),
  //       "icon_hash": guild.iconHash,
  //       "banner_hash": guild.bannerHash,
  //       "name": guild.name,
  //       "cached_members": guild.members.cache.length,
  //       "cached_roles": guild.roles.cache.length,
  //     };
  //   });
  //
  //   return createOkResponse(outputJson.toList());
  // }

  Future<shelf_router.Router> _setupRouter() async {
    return shelf_router.Router()
        ..get("/", (shelf.Request request) async {
          final data = await Injector.appInstance.get<BotInfoService>().getCurrentBotInfo();

          var processor = MustachexProcessor(initialVariables: data.toJson());

          final templateData = await File("templates/index.html").readAsString();
          final rendered = await processor.process(templateData);

          return shelf.Response.ok(rendered, headers: {"Content-Type": 'text/html'});
        });
      // ..get("/api/info", _handleBotInfo);
      // ..post("/api/login", _handleLogin)
      // ..get("/api/guilds", _authorized(_handleGuildInfo, [WebApiPermission.guilds]));
  }

  shelf.Handler _authorized(shelf.Handler inner) =>
      shelf.Pipeline()/*.addMiddleware()*/.addHandler(inner);

  Future<void> startServer() async {
    final router = await _setupRouter();

    final app =
        const shelf.Pipeline().addMiddleware(shelf.logRequests()).addMiddleware(corsHeaders()).addHandler(router.call);

    await shelf_io.serve(app, "0.0.0.0", 8088);
  }
}
