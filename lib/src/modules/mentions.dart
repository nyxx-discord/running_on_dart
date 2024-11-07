import 'dart:async';

import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/util/util.dart';

extension MapExtensions<K, V> on Map<K, V> {
  Iterable<(K, V)> get keyValues => entries.map((entry) => (entry.key, entry.value));
}

class _CacheEntry {
  DateTime lastUpdated = DateTime.now();
  int count = 0;

  void update(int n) {
    count += n;
    lastUpdated = DateTime.now();
  }
}

class MentionsMonitoringModule implements RequiresInitialization {
  final NyxxGateway _client = Injector.appInstance.get<NyxxGateway>();

  final Map<String, _CacheEntry> _cache = {};

  @override
  Future<void> init() async {
    _client.onMessageCreate.listen(_handleMessage);

    Timer.periodic(Duration(seconds: 4), _runCache);
  }

  Future<void> _runCache(Timer timer) async {
    for (final (key, value) in _cache.keyValues) {
      if (value.count > 3) {
        _cache.remove(key);
        _kickMemberForKey(key, value.count);
      }

      if (value.lastUpdated.difference(DateTime.now()).inSeconds > 3) {
        _cache.remove(key);
      }
    }
  }

  Future<void> _kickMemberForKey(String cacheKey, int spammedMentionsCount) async {
    final (guildId, userId) = _decomposeCacheKey(cacheKey);

    await _client.guilds[guildId].members
        .delete(userId, auditLogReason: "ROD.MentionsModule automatic action. Spammed $spammedMentionsCount mentions");
  }

  Future<void> _handleMessage(MessageCreateEvent event) async {
    final member = await event.member?.get();
    if (member == null) {
      return;
    }

    final shouldBeSkippedByPermissions =
        (member.permissions?.canManageMessages ?? false) || (member.permissions?.canManageChannels ?? false);
    if (shouldBeSkippedByPermissions) {
      return;
    }

    if (event.guildId == null) {
      return;
    }

    final cacheKey = _getCacheKey(event.guildId!, event.message.author.id);
    final cacheEntry = _cache[cacheKey] ?? _CacheEntry();

    cacheEntry.update(event.message.mentions.length);

    _cache[cacheKey] = cacheEntry;
  }

  (Snowflake, Snowflake) _decomposeCacheKey(String key) {
    final parts = key.split("_");

    return (Snowflake.parse(parts.first), Snowflake.parse(parts.last));
  }

  String _getCacheKey(Snowflake guildId, Snowflake userId) => '${guildId}_$userId';
}
