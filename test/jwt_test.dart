import 'package:running_on_dart/src/web_app/jwt.dart';
import 'package:test/test.dart';

void main() {
  group('JWT permissions helpers', () {
    test('JwtPermission.intValues returns values', () {
      expect(JwtPermission.intValues(), contains(JwtPermission.guilds.value));
    });
  });
}
