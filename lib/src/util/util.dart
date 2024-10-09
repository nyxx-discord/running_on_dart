import 'dart:io';
import 'dart:math';

import 'package:nyxx/nyxx.dart';

final random = Random();

DiscordColor getRandomColor() {
  return DiscordColor.fromRgb(random.nextInt(255), random.nextInt(255), random.nextInt(255));
}

String getCurrentMemoryString() {
  final current = (ProcessInfo.currentRss / 1024 / 1024).toStringAsFixed(2);
  final rss = (ProcessInfo.maxRss / 1024 / 1024).toStringAsFixed(2);
  return '$current/$rss MB';
}

String getDartPlatform() => Platform.version.split('(').first;

extension DurationFromTicks on Duration {
  String formatShort() => toString().split('.').first.padLeft(8, "0");
}

abstract class RequiresInitialization {
  Future<void> init();
}
