import 'dart:async';

import 'package:nyxx/nyxx.dart';
import 'package:prometheus_client/prometheus_client.dart';
import 'package:prometheus_client/runtime_metrics.dart' as runtime_metrics;
import 'package:prometheus_client_shelf/shelf_metrics.dart' as shelf_metrics;
import 'package:prometheus_client_shelf/shelf_handler.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

late final Counter slashCommandsTotalUsageMetric;
late final Counter commanderTotalUsageMetric;

late final Counter nyxxTotalMessagesSentMetric;
late final Counter nyxxTotalGuildJoinsMetric;

late final Gauge nyxxTotalUsersMetric;
late final Gauge nyxxTotalChannelsMetric;
late final Gauge nyxxTotalMessageCacheMetric;
late final Gauge nyxxTotalVoiceStates;

late final Gauge nyxxWsLatencyMetric;

late final Counter nyxxHttpResponse;

void registerPeriodicCollectors(INyxxWebsocket client) {
  Timer.periodic(const Duration(seconds: 5), (t) {
    nyxxTotalUsersMetric.value = client.users.length.toDouble();
    nyxxTotalChannelsMetric.value = client.channels.length.toDouble();
    nyxxTotalMessageCacheMetric.value =
        client.channels.values.whereType<ITextChannel>().map((e) => e.messageCache.length).fold(0, (first, second) => first + second);
    nyxxTotalVoiceStates.value = client.guilds.values.map((g) => g.voiceStates.length).reduce((f, s) => f + s).toDouble();

    for (final shard in client.shardManager.shards) {
      nyxxWsLatencyMetric.labels([shard.id.toString()]).value = shard.gatewayLatency.inMicroseconds.toDouble();
    }
  });
}

Future<void> registerPrometheus() async {
  runtime_metrics.register();

  slashCommandsTotalUsageMetric = Counter(name: 'slash_commands_total_usage', help: 'The total amount of used slash commands', labelNames: ['name'])
    ..register();
  commanderTotalUsageMetric = Counter(name: 'commander_total_usage', help: 'The total amount of used commander commands', labelNames: ['name'])..register();
  nyxxTotalMessagesSentMetric = Counter(name: 'nyxx_total_messages_sent', help: "Total number of messages sent", labelNames: ['guild_id'])..register();
  nyxxTotalGuildJoinsMetric = Counter(name: 'nyxx_total_guild_joins', help: "Total number of guild joins", labelNames: ['guild_id'])..register();
  nyxxTotalUsersMetric = Gauge(name: 'nyxx_total_users_cache', help: "Total number of users in cache")..register();
  nyxxTotalChannelsMetric = Gauge(name: 'nyxx_total_channels_cache', help: "Total number of channels in cache")..register();
  nyxxTotalMessageCacheMetric = Gauge(name: 'nyxx_total_messages_cache', help: "Total number of messages in cache")..register();
  nyxxTotalVoiceStates = Gauge(name: 'nyxx_total_voice_states_cache', help: "Total number of voice states in cache")..register();
  nyxxWsLatencyMetric = Gauge(name: 'nyxx_ws_latency', help: "Websocket latency", labelNames: ['shard_id'])..register();
  nyxxHttpResponse = Counter(name: 'nyxx_http_response', help: 'Code of http responses', labelNames: ['code'])..register();

  final router = Router()..get('/metrics', prometheusHandler());
  var handler = const shelf.Pipeline().addMiddleware(shelf_metrics.register()).addHandler(router);

  var server = await io.serve(handler, '0.0.0.0', 8080);
  print('Serving at http://${server.address.host}:${server.port}');
}
