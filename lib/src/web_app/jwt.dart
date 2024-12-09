import 'package:jaguar_jwt/jaguar_jwt.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/web_app/utils.dart';
import 'package:shelf/shelf.dart' as shelf;

enum JwtPermission {
  guilds(1);

  final int value;

  const JwtPermission(this.value);

  static List<int> intValues() => JwtPermission.values.map((p) => p.value).toList();
}

String get jwtSecret => getEnv('JWT_SECRET');

String generateJwt(String subject, {Duration maxAge = const Duration(days: 3), Map<String, dynamic>? payload}) {
  final claimSet = JwtClaim(
    subject: subject,
    issuer: 'Running on Dart',
    maxAge: maxAge,
    payload: payload,
  );

  return issueJwtHS256(claimSet, jwtSecret);
}

Map<String, dynamic> generateJwtResponse(String subject,
    {List<int> permissions = const [], Map<String, dynamic>? userData}) {
  final token = generateJwt(subject, payload: {
    'permissions': permissions,
  });

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

        final permissions = Set.of(claim.payload['permissions'] ?? []);
        if (!permissions.containsAll(permissionsIntValues)) {
          return createForbiddenResponse("Missing permissions");
        }

        return innerHandler(request);
      };
    };
