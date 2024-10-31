import 'dart:convert';

import 'package:shelf/shelf.dart' as shelf;

shelf.Response createJsonErrorResponse(int errorCode, String errorMessage) {
  return shelf.Response(errorCode,
      body: jsonEncode({"message": errorMessage}), headers: {"Content-Type": 'application/json'});
}

shelf.Response createUnauthorizedResponse(String errorMessage) => createJsonErrorResponse(400, errorMessage);

shelf.Response createForbiddenResponse() => shelf.Response.forbidden(null);
