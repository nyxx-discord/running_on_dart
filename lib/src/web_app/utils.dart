import 'dart:convert';
import 'dart:io';

import 'package:mustachex/mustachex.dart';
import 'package:shelf/shelf.dart' as shelf;

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
