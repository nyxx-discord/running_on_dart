import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:human_duration_parser/human_duration_parser.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

final nonAsciiRegex = RegExp(r'[^\x00-\x7F]');

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

String getDartPlatform() => Platform.version.split('(').first.trim();

extension FormatShortDurationExtension on Duration {
  String formatShort() => toString().split('.').first.padLeft(8, "0");
}

extension ToMapExtension<K, V> on Iterable<MapEntry<K, V>> {
  Map<K, V> toMap() => Map.fromEntries(this);
}

extension EmojiToMention on Emoji {
  String get mention => "<:$name:${this.id}>";
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

Duration? getDurationFromStringOrDefault(String? durationString, [Duration? defaultDuration]) {
  if (durationString == null) {
    return defaultDuration;
  }

  return parseStringToDuration(durationString) ?? defaultDuration;
}

Map<String, String?> getModalDataIndexed(List<MessageComponent> components) {
  return Map.fromEntries(components
      .cast<ActionRowComponent>()
      .map((row) => row.components)
      .flattened
      .cast<TextInputComponent>()
      .map((textInputComponent) => MapEntry<String, String?>(textInputComponent.customId, textInputComponent.value)));
}

Snowflake getParentIdFromContext(ContextData context) => context.guild?.id ?? context.user.id;

String stripNonAscii(String input) {
  return input.replaceAll(nonAsciiRegex, '');
}

bool boolValue(dynamic value) {
  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value >= 0;
  }

  if (value is String) {
    return ['1', 'yes', 'true'].contains(value.toLowerCase().trim());
  }

  return false;
}

String boolToString(bool boolValue) => boolValue ? 'true' : 'false';

extension ModalDataAsMap on ModalContext {
  Map<String, String?> asMap() {
    return interaction.data.components
        .expand((component) => component is ActionRowComponent ? component.components : [component])
        .whereType<TextInputComponent>()
        .map((c) => MapEntry(c.customId, c.value))
        .toMap();
  }
}
