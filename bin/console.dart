import 'package:running_on_dart/src/api/jwt_middleware.dart';

enum Commands {
  generateAdminJwt('generate-admin-jwt');

  final String name;
  const Commands(this.name);

  static Commands byName(String name) {
    return values.firstWhere((e) => e.name == name);
  }
}

int main(List<String> args) {
  if (args.isEmpty) {
    print("Available commands: \n${Commands.values.map((e) => e.name).join(", ")}");
    return -1;
  }

  final command = Commands.byName(args[0]);

  switch (command) {
    case Commands.generateAdminJwt:
      print(generateJwtKey("0", "test-user"));
      break;
    default:
      print("Command '$command' not recognized!");
      return -1;
  }

  return 0;
}
