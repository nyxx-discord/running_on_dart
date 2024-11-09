import 'dart:async';

import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/models/feature_settings.dart';
import 'package:running_on_dart/src/services/feature_settings.dart';
import 'package:running_on_dart/src/util/util.dart';

extension MapExtensions<K, V> on Map<K, V> {
  Iterable<(K, V)> get keyValues => entries.map((entry) => (entry.key, entry.value));
  void removeAll(Iterable<K> toRemove) => removeWhere((key, value) => toRemove.contains(key));
}

class _CacheEntry {
  DateTime lastUpdated = DateTime.now();
  int count = 0;

  void update(int n) {
    count += n;
    lastUpdated = DateTime.now();
  }
}

final _mentionRegex = RegExp(r'<@\d+>');

class MentionsMonitoringModule implements RequiresInitialization {
  final NyxxGateway _client = Injector.appInstance.get();
  final FeatureSettingsService _featureSettings = Injector.appInstance.get();

  final _logger = Logger('ROD.MentionsMonitoringModule');

  final Map<String, _CacheEntry> _cache = {};

  @override
  Future<void> init() async {
    _client.onMessageCreate.listen(_handleMessage);

    Timer.periodic(Duration(seconds: 4), _runCache);
  }

  Future<void> _runCache(Timer timer) async {
    final toRemove = <String>[];

    for (final (key, value) in _cache.keyValues) {
      if (value.count > 6) {
        toRemove.add(key);
        _kickMemberForKey(key, value.count);
      }

      if (value.lastUpdated.difference(DateTime.now()).inSeconds > 3) {
        toRemove.add(key);
      }
    }

    _cache.removeAll(toRemove);
  }

  Future<void> _kickMemberForKey(String cacheKey, int spammedMentionsCount) async {
    _logger.info("Kicking member. Spammed $spammedMentionsCount mentions");

    final (guildId, userId) = _decomposeCacheKey(cacheKey);
    await _client.guilds[guildId].members
        .delete(userId, auditLogReason: "ROD.MentionsModule automatic action. Spammed $spammedMentionsCount mentions");
  }

  Future<void> _handleMessage(MessageCreateEvent event) async {
    if (event.guildId == null) {
      return;
    }

    if (!(await _featureSettings.isEnabled(Setting.mentions, event.guildId!))) {
      return;
    }

    final member = await event.member?.get();
    if (member == null) {
      return;
    }

    final shouldBeSkippedByPermissions = (member.permissions?.isAdministrator ?? false) ||
        (member.permissions?.canManageMessages ?? false) ||
        (member.permissions?.canManageChannels ?? false);
    if (shouldBeSkippedByPermissions) {
      _logger.info(
          "Detected spamming from user: ${member.user?.username}, id: ${member.id}. Skipping since can manage guild.");
      return;
    }

    final cacheKey = _getCacheKey(event.guildId!, event.message.author.id);
    final cacheEntry = _cache[cacheKey] ?? _CacheEntry();

    cacheEntry.update(_mentionRegex.allMatches(event.message.content).length);

    _cache[cacheKey] = cacheEntry;
  }

  (Snowflake, Snowflake) _decomposeCacheKey(String key) {
    final parts = key.split("_");

    return (Snowflake.parse(parts.first), Snowflake.parse(parts.last));
  }

  String _getCacheKey(Snowflake guildId, Snowflake userId) => '${guildId}_$userId';
}
