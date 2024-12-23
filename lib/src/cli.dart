import 'package:running_on_dart/src/settings.dart';
import 'package:running_on_dart/src/web_app/jwt.dart';

bool handleCli(List<String> args) {
  if (args.isNotEmpty && dev) {
    final commandArg = args.first;
    if (commandArg == 'generate-test-jwt') {
      print(generateJwt('test', maxAge: Duration(days: 31), permissions: JwtPermission.intValues()));
      return true;
    }
  }

  return false;
}
