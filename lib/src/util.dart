import 'dart:math';

import 'package:nyxx/nyxx.dart';

DiscordColor getRandomColor() {
  Random random = Random();

  return DiscordColor.fromRgb(random.nextInt(255), random.nextInt(255), random.nextInt(255));
}
