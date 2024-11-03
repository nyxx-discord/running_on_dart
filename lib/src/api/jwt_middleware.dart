import 'package:jaguar_jwt/jaguar_jwt.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/api/api_server.dart';
import 'package:running_on_dart/src/api/utils.dart';
import 'package:shelf/shelf.dart' as shelf;

final jwtKey = getEnv("JWT_SECRET");

class MissingPermissionsException implements Exception {}

String generateJwtKey(String discordUserId, String userName) {
  final perms = adminIds.contains(Snowflake.parse(discordUserId)) ? WebApiPermission.values.map((e) => e.name) : [];

  final jwtClaim = JwtClaim(
    subject: discordUserId,
    maxAge: Duration(days: 1),
    payload: {
      "name": userName,
      'perms': perms,
    },
  );

  return issueJwtHS256(jwtClaim, jwtKey);
}

void validateClaims(JwtClaim jwt, List<String> requiredPermissions) {
  final permissions = (jwt.payload['perms'] as List<dynamic>? ?? []).cast<String>();
  final valid = Set.of(permissions).containsAll(requiredPermissions);
  if (!valid) {
    throw MissingPermissionsException();
  }
}

shelf.Middleware jwtMiddleware([List<String> requiredPermissions = const []]) => (shelf.Handler handler) {
      return (shelf.Request request) {
        final authHeader = request.headers['Authorization'];

        if (authHeader == null) {
          return createUnauthorizedResponse('Missing authorization header');
        }

        try {
          final jwt = verifyJwtHS256Signature(authHeader.replaceFirst('Bearer ', ''), jwtKey);

          if (requiredPermissions.isNotEmpty) {
            validateClaims(jwt, requiredPermissions);
          }
        } on JwtException catch (e) {
          return createUnauthorizedResponse(e.message);
        } on MissingPermissionsException {
          return createForbiddenResponse();
        }

        return handler(request);
      };
    };
