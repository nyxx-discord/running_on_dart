import 'dart:convert';

import 'package:injector/injector.dart';
import 'package:running_on_dart/src/api/jwt_middleware.dart';
import 'package:running_on_dart/src/modules/bot_start_duration.dart';

import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

class WebServer {
  Future<shelf.Response> _handleBotInfo(shelf.Request request) async {
    final botStartDuration = Injector.appInstance.get<BotStartDuration>();

    return shelf.Response.ok(jsonEncode({"ok": true, 'uptime': botStartDuration.startDate.toIso8601String()}), headers: {'Content-Type': 'application/json'});
  }

  Future<shelf_router.Router> _setupRouter() async {
    return shelf_router.Router()
      ..get("/api/info", _handleBotInfo);
      // ..get("/api/test", _authorized(_handleBotInfo));
  }

  shelf.Handler _authorized(shelf.Handler inner) => const shelf.Pipeline().addMiddleware(jwtMiddleware()).addHandler(inner);

  Future<void> startServer() async {
    final router = await _setupRouter();

    final app = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler(router.call);

    await shelf_io.serve(app, "0.0.0.0", 8088);
  }
}
