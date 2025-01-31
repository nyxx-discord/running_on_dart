import 'package:running_on_dart/src/settings.dart';
import 'package:running_on_dart/src/web_app/jwt.dart';

bool handleCli(List<String> args) {
  if (args.isNotEmpty && dev) {
    final commandArg = args.first;
    if (commandArg == 'generate-test-jwt') {
      print(generateJwt('1300543841996374131', maxAge: Duration(days: 31), permissions: []));
      return true;
    }
  }

  return false;
}
