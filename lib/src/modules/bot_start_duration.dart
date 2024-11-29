import 'package:running_on_dart/src/init.dart';

class BotStartDuration implements RequiresInitialization {
  late final DateTime startDate;

  @override
  Future<void> init() async {
    startDate = DateTime.now();
  }
}
