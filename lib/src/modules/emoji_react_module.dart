import 'package:collection/collection.dart';
import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/models/feature_settings.dart';
import 'package:running_on_dart/src/repository/feature_settings.dart';
import 'package:running_on_dart/src/settings.dart';
import 'package:running_on_dart/src/util/util.dart';

import 'package:nyxx/src/models/emoji.dart'; // TODO: This should be imported

enum Mode {
  react('react'),
  message('message');

  final String name;

  const Mode(this.name);
}

class EmojiFeatureSetting {
  final bool useBuiltin;
  final Mode mode;
  final bool processOtherBots;

  EmojiFeatureSetting({required this.useBuiltin, required this.mode, required this.processOtherBots});

  factory EmojiFeatureSetting.fromJson(Map<String, dynamic> raw) {
    return EmojiFeatureSetting(
      useBuiltin: raw['use_builtin'] ?? true,
      mode: Mode.values.singleWhereOrNull((e) => e.name == raw['mode']) ?? Mode.message,
      processOtherBots: raw['process_other_bots'] ?? true,
    );
  }
}

class EmojiReactModule implements RequiresInitialization {
  final NyxxGateway _client = Injector.appInstance.get();
  final FeatureSettingsRepository _featureSettingsRepository = Injector.appInstance.get();

  late Set<ApplicationEmoji> _emojis;
  late Map<Snowflake, EmojiFeatureSetting> _emojiFeatureSettingsCache;

  @override
  Future<void> init() async {
    if (!intentFeaturesEnabled) {
      return;
    }

    _emojiFeatureSettingsCache = (await _featureSettingsRepository.fetchSettingsForType(Setting.emojiReact))
        .map((setting) => MapEntry(setting.guildId, EmojiFeatureSetting.fromJson(setting.dataAsJson!)))
        .toMap();
    _emojis = (await _client.application.emojis.list())
        .toSet(); // TODO: Add ability to reload module (download new emojis in this case)

    _client.onMessageCreate.listen(_handleMessage);
  }

  Future<void> _handleMessage(MessageCreateEvent event) async {
    if (event.message.author.id == _client.user.id) {
      return;
    }

    if (event.guildId == null) {
      return;
    }

    final (enabled, data) = _fetchSettingForGuild(event.guildId!);
    if (!enabled) {
      return;
    }

    if (!data!.processOtherBots && event.message.author is User && (event.message.author as User).isBot) {
      return;
    }

    final matchingEmojis = [
      if (data.useBuiltin) ..._findBuiltinEmojis(event.message.content.toLowerCase()),
    ];

    if (matchingEmojis.isEmpty) {
      return;
    }

    switch (data.mode) {
      case Mode.react:
        for (final emoji in matchingEmojis) {
          event.message.react(ReactionBuilder(name: emoji.name, id: emoji.id));
        }
        break;
      case Mode.message:
        final content = matchingEmojis.map((emoji) => emoji.mention).join(' ');

        event.message.channel.sendMessage(MessageBuilder(content: content));
        break;
    }
  }

  Iterable<ApplicationEmoji> _findBuiltinEmojis(String messageContent) =>
      _emojis.where((emoji) => messageContent.contains(emoji.name));
  (bool, EmojiFeatureSetting?) _fetchSettingForGuild(Snowflake guildId) {
    final result = _emojiFeatureSettingsCache[guildId];

    return (result != null, result);
  }
}
