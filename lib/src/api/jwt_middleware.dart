import 'package:shelf/shelf.dart' as shelf;

shelf.Middleware jwtMiddleware() => (shelf.Handler handler) {
  return (shelf.Request request) {
    final authHeader = request.headers['Authorization'];

    if (authHeader == null) {
      return shelf.Response.unauthorized(null);
    }

    return handler(request);
  };
};
