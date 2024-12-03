import 'dart:convert';

import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_session/session_middleware.dart';

shelf.Response createJsonErrorResponse(int errorCode, String errorMessage) {
  return shelf.Response(errorCode,
      body: jsonEncode({"message": errorMessage}), headers: {"Content-Type": 'application/json'});
}

shelf.Response createOkResponse(Object? body) {
  return shelf.Response.ok(jsonEncode(body), headers: {"Content-Type": 'application/json'});
}

shelf.Response createUnauthorizedResponse(String errorMessage) => createJsonErrorResponse(400, errorMessage);

shelf.Response createForbiddenResponse() => shelf.Response.forbidden(null);

void initSession(shelf.Request request, Map<String, dynamic> userDataJson, List<dynamic> guildsDataJson) {
  var session = Session.getSession(request);
  session ??= Session.createSession(request);

  final userId = userDataJson['user']['id'] as String;

  session.data['user_data'] = {
    'id': userId,
    'name': userDataJson['user']['global_name'] ?? userDataJson['user']['username'],
    'avatar': userDataJson['user']['avatar'],
    'expires_t': userDataJson['expires'],
    'user_agent': request.headers['user-agent'],
    'joined_guilds': guildsDataJson.map((guildData) => guildData['id']).toList(),
  };

  session.data['is_admin'] = adminIds.contains(Snowflake.parse(userId));
  session.expires = DateTime.now().add(Duration(days: 3));

  Injector.appInstance.get<SessionManagerPlugin>().triggerSaveSessions();
}

void deleteSession(shelf.Request request) {
  Session.deleteSession(request);
}

bool isAdminFromSession(shelf.Request request) {
  final session = getSession(request);

  return session?.data['is_admin'] as bool? ?? false;
}

Map<String, dynamic> getCustomDataFromSession(shelf.Request request) {
  final session = getSession(request);

  return {
    'user_data': session?.data['user_data'] as Map<String, dynamic>? ?? false,
    'is_admin': session?.data['is_admin'] ?? false,
  };
}

Session? getSession(shelf.Request request) {
  final session = Session.getSession(request);
  if (session == null) {
    return null;
  }

  final now = DateTime.now();
  if (session.data['user_data'] != null) {
    final nowPlusOneDay = now.add(Duration(days: 1));

    if (session.expires.isBefore(nowPlusOneDay)) {
      session.expires = now.add(Duration(days: 1, hours: 12));
    }
  }

  return session;
}
