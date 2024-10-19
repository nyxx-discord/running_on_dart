import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:human_duration_parser/human_duration_parser.dart';
import 'package:nyxx/nyxx.dart';

final random = Random();
const _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';

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

String? valueOrNull(String? value) {
  if (value == null) {
    return null;
  }

  final trimmedValue = value.trim();
  if (trimmedValue.isEmpty) {
    return null;
  }

  return value;
}

String generateRandomString(int length) =>
    String.fromCharCodes(Iterable.generate(length, (_) => _chars.codeUnitAt(random.nextInt(_chars.length))))
        .toUpperCase();

Iterable<MessageBuilder> spliceEmbedsForMessageBuilders(Iterable<EmbedBuilder> embeds, [int sliceSize = 2]) sync* {
  for (final splicedEmbeds in embeds.slices(sliceSize)) {
    yield MessageBuilder(embeds: splicedEmbeds);
  }
}

Duration? getDurationFromStringOrDefault(String? durationString, Duration? defaultDuration) {
  if (durationString == null) {
    return defaultDuration;
  }

  return parseStringToDuration(durationString) ?? defaultDuration;
}
