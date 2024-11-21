import 'dart:convert';
import 'dart:io';

import 'package:mustachex/mustachex.dart';
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

Future<shelf.Response> createTwigResponse(String name, {Map<String, dynamic>? parameters}) async {
  final processor = MustachexProcessor(initialVariables: parameters);
  final templateData = await File("templates/$name").readAsString();

  return shelf.Response.ok(await processor.process(templateData), headers: {"Content-Type": 'text/html'});
}

shelf.Response createUnauthorizedResponse(String errorMessage) => createJsonErrorResponse(400, errorMessage);

shelf.Response createForbiddenResponse() => shelf.Response.forbidden(null);

void initSession(shelf.Request request, Map<String, dynamic> userDataJson, Map<String, dynamic> tokenDataJson) {
  var session = Session.getSession(request);
  session ??= Session.createSession(request);

  final userId = userDataJson['user']['id'] as String;

  session.data['user_data'] = {
    'id': userId,
    'name': userDataJson['user']['global_name'] ?? userDataJson['user']['username'],
    'avatar': userDataJson['user']['avatar'],
    'expires_t': userDataJson['expires'],
    'token': tokenDataJson['access_token'],
  };
  session.data['is_admin'] = adminIds.contains(Snowflake.parse(userId));

  session.expires = DateTime.now().add(Duration(seconds: tokenDataJson['expires_in']));
}

void deleteSession(shelf.Request request) {
  Session.deleteSession(request);
}

bool isAdminFromSession(shelf.Request request) {
  final session = Session.getSession(request);

  return session?.data['is_admin'] as bool? ?? false;
}

Map<String, dynamic> getCustomDataFromSession(shelf.Request request) {
  final session = Session.getSession(request);

  return {
    'user_data': session?.data['user_data'] as Map<String, dynamic>? ?? false,
    'is_admin': session?.data['is_admin'] ?? false,
  };
}
