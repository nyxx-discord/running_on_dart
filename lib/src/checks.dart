import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:running_on_dart/src/settings.dart';

final Check administratorCheck = Check((context) => adminIds.contains(context.user.id), 'Administrator check');
