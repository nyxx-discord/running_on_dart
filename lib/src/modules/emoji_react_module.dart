import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/models/feature_settings.dart';
import 'package:running_on_dart/src/repository/feature_settings.dart';
import 'package:running_on_dart/src/modules/feature_settings.dart';
import 'package:running_on_dart/src/settings.dart';
import 'package:running_on_dart/src/util/util.dart';
import 'package:running_on_dart/src/init.dart';

import 'package:nyxx/src/models/emoji.dart'; // TODO: This should be imported

class EmojiReactModule implements RequiresInitialization, Reloadable {
  final NyxxGateway _client = Injector.appInstance.get();
  final FeatureSettingsRepository _featureSettingsRepository = Injector.appInstance.get();
  final FeatureSettingsModule _featureSettingsService = Injector.appInstance.get();

  final Set<ApplicationEmoji> _emojis = {};
  final Map<Snowflake, EmojiReactData> _emojiFeatureSettingsCache = {};

  @override
  Future<void> reload() async {
    _emojis.clear();
    _emojis.addAll(await _client.application.emojis.list());
  }

  @override
  Future<void> init() async {
    if (!intentFeaturesEnabled) {
      return;
    }

    _emojiFeatureSettingsCache.addAll(
      (await _featureSettingsRepository.fetchSettingsForType(
        Setting.emojiReact,
      )).map((setting) => MapEntry(setting.guildId, setting.parseData<EmojiReactData>()!)).toMap(),
    );

    await reload();

    _client.onMessageCreate.listen(_handleMessage);

    _featureSettingsService.onFeatureEnabled
        .where((s) => s.setting == Setting.emojiReact)
        .listen((s) => _emojiFeatureSettingsCache[s.guildId] = s.parseData<EmojiReactData>()!);
    _featureSettingsService.onFeatureDisabled
        .where((s) => s.setting == Setting.emojiReact)
        .listen((s) => _emojiFeatureSettingsCache.remove(s.guildId));
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

    final matchingEmojis = [if (data.useBuiltin) ..._findBuiltinEmojis(event.message.content.toLowerCase())];

    if (matchingEmojis.isEmpty) {
      return;
    }

    switch (data.mode) {
      case EmojiReactType.react:
        for (final emoji in matchingEmojis) {
          event.message.react(ReactionBuilder(name: emoji.name, id: emoji.id));
        }
        break;
      case EmojiReactType.message:
        final content = matchingEmojis.map((emoji) => emoji.mention).join(' ');

        event.message.channel.sendMessage(MessageBuilder(content: content));
        break;
    }
  }

  Iterable<ApplicationEmoji> _findBuiltinEmojis(String messageContent) =>
      _emojis.where((emoji) => messageContent.contains(emoji.name));

  (bool, EmojiReactData?) _fetchSettingForGuild(Snowflake guildId) {
    final result = _emojiFeatureSettingsCache[guildId];

    return (result != null, result);
  }
}
