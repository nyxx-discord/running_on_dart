import 'package:injector/injector.dart';
import 'package:jaguar_jwt/jaguar_jwt.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/web_app/utils.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_router/shelf_router.dart';

enum JwtPermission {
  guilds(1);

  final int value;

  const JwtPermission(this.value);

  static List<int> intValues() => JwtPermission.values.map((p) => p.value).toList();
}

String get jwtSecret => getEnv('JWT_SECRET');

String generateJwt(String subject,
    {Duration maxAge = const Duration(days: 3), Map<String, dynamic>? payload, List<int> permissions = const []}) {
  final claimSet = JwtClaim(
    subject: subject,
    issuer: 'Running on Dart',
    maxAge: maxAge,
    payload: {
      ...?payload,
      'permissions': permissions,
    },
  );

  return issueJwtHS256(claimSet, jwtSecret);
}

Map<String, dynamic> generateJwtResponse(String subject,
    {List<int> permissions = const [], Map<String, dynamic>? userData}) {
  final token = generateJwt(subject, permissions: permissions);

  return {
    "token": token,
    "userData": userData,
  };
}

JwtClaim? validateJwtToken(String token) {
  try {
    return verifyJwtHS256Signature(token, jwtSecret);
  } on JwtException {
    return null;
  }
}

List<int> _getPermissionsFromClaimPayload(JwtClaim claim) {
  if (!claim.claimNames().contains('pld')) {
    return [];
  }

  return claim.payload['permissions'].cast<int>() ?? [];
}

shelf.Middleware processJwt(List<JwtPermission> permissions) => (innerHandler) {
      final permissionsIntValues = permissions.map((p) => p.value);

      return (request) {
        final authHeader = request.headers['authorization'];
        if (authHeader == null || !authHeader.startsWith('Bearer')) {
          return createUnauthorizedResponse("Authorization missing");
        }

        final token = authHeader.replaceFirst('Bearer ', '');
        final claim = validateJwtToken(token);
        if (claim == null) {
          return createUnauthorizedResponse("Invalid jwt token");
        }

        if (claim.expiry?.isBefore(DateTime.now()) ?? true) {
          return createUnauthorizedResponse("Token expired");
        }

        final permissions = Set.of(_getPermissionsFromClaimPayload(claim));
        if (!permissions.containsAll(permissionsIntValues)) {
          return createForbiddenResponse("Missing permissions");
        }

        final updatedRequest = request.change(context: {
          'jwt_permissions': permissions,
          'user_id': claim.subject.toString(),
        });

        return innerHandler(updatedRequest);
      };
    };

shelf.Middleware processGuildUser({List<int> orPermissions = const []}) => (innerHandler) {
      return (request) {
        if (orPermissions.isNotEmpty) {
          final jwtPermissions = getJwtPermissionsFromRequest(request);

          if (jwtPermissions.containsAll(orPermissions)) {
            return innerHandler(request);
          }
        }

        final guildId = request.params['id'];
        if (guildId == null) {
          return createForbiddenResponse();
        }

        final guild = Injector.appInstance.get<NyxxGateway>().guilds.cache[Snowflake.parse(guildId)];
        if (guild == null) {
          return createForbiddenResponse();
        }

        final userId = getLoggedInUserIdFromRequest(request);
        if (userId == null) {
          return createForbiddenResponse();
        }

        final member = guild.members.cache[Snowflake.parse(userId)];
        if (member == null) {
          return createForbiddenResponse();
        }

        if (!(member.permissions?.isAdministrator ?? false)) {
          return createForbiddenResponse();
        }

        return innerHandler(request);
      };
    };

Set<int> getJwtPermissionsFromRequest(shelf.Request request) => (request.context['jwt_permissions'] as Set<int>?) ?? {};

String? getLoggedInUserIdFromRequest(shelf.Request request) => request.context['user_id'] as String?;
