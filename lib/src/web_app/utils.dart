import 'dart:convert';

import 'package:shelf/shelf.dart' as shelf;

typedef JsonApiResponse = Map<String, dynamic>;

shelf.Response createJsonErrorResponse(int errorCode, String errorMessage) {
  return shelf.Response(errorCode,
      body: jsonEncode({"message": errorMessage}), headers: {"Content-Type": 'application/json'});
}

shelf.Response createOkResponse(Object? body) {
  return shelf.Response.ok(jsonEncode(body), headers: {"Content-Type": 'application/json'});
}

shelf.Response createNotFoundResponse() => shelf.Response.notFound(null);

shelf.Response createBadRequestResponse(String errorMessage) => createJsonErrorResponse(400, errorMessage);

shelf.Response createUnauthorizedResponse(String errorMessage) => createJsonErrorResponse(403, errorMessage);

shelf.Response createValidationErrorResponse(JsonApiResponse errors) => shelf.Response(
      422,
      body: jsonEncode({
        'errors': errors,
      }),
      headers: {"Content-Type": 'application/json'},
    );

shelf.Response createForbiddenResponse([String? errorMessage]) {
  if (errorMessage != null) {
    return createJsonErrorResponse(401, errorMessage);
  }

  return shelf.Response.forbidden(null);
}
