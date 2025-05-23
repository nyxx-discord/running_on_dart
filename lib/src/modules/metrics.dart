import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:injector/injector.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/services/bot_info.dart';
import 'package:running_on_dart/src/settings.dart';
import 'package:running_on_dart/src/init.dart';
import 'package:running_on_dart/src/modules/bot_start_duration.dart';
import 'package:running_on_dart/src/util/util.dart';
import 'package:typed_data/typed_buffers.dart';

final String deviceName = botName.toLowerCase().replaceAll(' ', '_');

final String botDeviceId = "${deviceName}_device_id";
final String availabilityTopic = "$deviceName/status";
const String discoveryPrefix = "homeassistant"; // Default HA discovery prefix

typedef ExtractValueCallback = String Function(BotInfo botInfo);
typedef ContextValueCallback = String Function(DynamicMetricContext context);
typedef StaticValueCallback = String Function();

class Metric {
  final String objectId;
  final String name;
  final String? unit;
  final String? icon;
  final String? stateClass;
  final String? deviceClass;
  final bool isDiagnostic;

  late String stateTopic = "$deviceName/metrics/$objectId";

  Metric(
    this.objectId,
    this.name, {
    this.unit,
    this.icon,
    this.isDiagnostic = false,
    this.stateClass,
    this.deviceClass,
  });
}

class DynamicMetricContext {
  var messages = 0;
  var joins = 0;

  var removals = 0;
  var events = 0;
  var interactions = 0;
}

class StaticMetric extends Metric {
  final StaticValueCallback extractValue;

  StaticMetric(super.objectId, super.name, this.extractValue, {super.unit, super.icon, super.deviceClass})
    : super(stateClass: 'measurement');
}

class DynamicMetric extends Metric {
  final ContextValueCallback extractValue;

  DynamicMetric(super.objectId, super.name, this.extractValue, {super.unit, super.icon, super.isDiagnostic = false})
    : super(stateClass: 'measurement', deviceClass: 'data_size');
}

class DiagnosticMetric extends Metric {
  final StaticValueCallback extractValue;

  DiagnosticMetric(
    super.objectId,
    super.name,
    this.extractValue, {
    super.unit,
    super.icon,
    super.stateClass,
    super.deviceClass,
  }) : super(isDiagnostic: true);
}

class BotInfoMetric extends Metric {
  final ExtractValueCallback extractValue;

  BotInfoMetric(super.objectId, super.name, this.extractValue, {super.unit, super.icon, super.isDiagnostic = false})
    : super(stateClass: 'measurement', deviceClass: 'data_size');
}

final List<DiagnosticMetric> oneTimeMetrics = [
  DiagnosticMetric('nyxx_version', 'Nyxx Version', () => ApiOptions.nyxxVersion),
  DiagnosticMetric('bot_version', 'Bot Version', () => version),
  DiagnosticMetric('frontend_version', 'Frontend Version', () => frontendVersion),
  DiagnosticMetric('dart_version', 'Dart Version', getDartPlatform),
];

final List<Metric> periodicMetrics = [
  BotInfoMetric('cached_guilds', 'Cached Guilds', (BotInfo info) => info.cachedGuilds.toString()),
  BotInfoMetric('cached_users', 'Cached Users', (BotInfo info) => info.cachedUsers.toString()),
  BotInfoMetric('cached_channels', 'Cached Channels', (BotInfo info) => info.cachedChannels.toString()),
  BotInfoMetric('cached_voice_states', 'Cached Voice States', (BotInfo info) => info.cachedVoiceStates.toString()),
  BotInfoMetric('shard_count', 'Shard Count', (BotInfo info) => info.shardCount.toString()),
  BotInfoMetric('total_tags_count', 'Total Tags Count', (BotInfo info) => info.totalTagsCount.toString()),
  BotInfoMetric(
    'total_reminders_count',
    'Total Reminders Count',
    (BotInfo info) => info.totalRemainderCount.toString(),
  ),
  BotInfoMetric('cached_messages', 'Cached Messages', (BotInfo info) => info.cachedMessages.toString()),
  DiagnosticMetric(
    'memory_usage_current',
    'Memory Usage',
    () => (ProcessInfo.currentRss / 1024 / 1024).toStringAsFixed(2),
    unit: 'MB',
  ),
  DynamicMetric('messages_per_minute', 'Messages', (context) {
    final value = context.messages.toString();
    context.messages = 0;

    return value;
  }, unit: 'msg/min'),
  DynamicMetric('joins_per_minute', 'Guild joins', (context) {
    final value = context.joins.toString();
    context.joins = 0;

    return value;
  }, unit: 'joins/min'),
  DynamicMetric('removals_per_minute', 'Guild removals', (context) {
    final value = context.removals.toString();
    context.removals = 0;

    return value;
  }, unit: 'removals/min'),
  DynamicMetric('events_per_minute', 'Events', (context) {
    final value = context.events.toString();
    context.events = 0;

    return value;
  }, unit: 'events/min'),
  DynamicMetric('interactions_per_minute', 'Interactions', (context) {
    final value = context.interactions.toString();
    context.interactions = 0;

    return value;
  }, unit: 'interactions/min'),
  StaticMetric(
    'uptime',
    'Uptime',
    () {
      final start = Injector.appInstance.get<BotStartDuration>().startDate;
      return DateTime.now().difference(start).inSeconds.toString();
    },
    deviceClass: 'duration',
    unit: 's',
  ),
  StaticMetric(
    'gateway_latency',
    'Gateway Latency',
    () {
      final nyxxGateway = Injector.appInstance.get<NyxxGateway>();

      return nyxxGateway.gateway.latency.inMilliseconds.toString();
    },
    deviceClass: 'duration',
    unit: 'ms',
  ),
  StaticMetric(
    'rest_latency',
    'REST Latency',
    () {
      final nyxxGateway = Injector.appInstance.get<NyxxGateway>();

      return nyxxGateway.httpHandler.latency.inMilliseconds.toString();
    },
    deviceClass: 'duration',
    unit: 'ms',
  ),
];

class MetricsModule implements RequiresInitialization {
  final _logger = Logger('ROD.Metrics');

  late MqttServerClient client;
  Timer? publishStateTimer;

  final DynamicMetricContext dynamicMetricContext = DynamicMetricContext();

  @override
  Future<void> init() async {
    if (!homeAssistantMetricsMqttEnabled) {
      _logger.info("Metrics not enabled skipping");
      return;
    }

    client = MqttServerClient(metricsMqttPath, deviceName, maxConnectionAttempts: 30);
    client.onConnected = _onConnected;
    client.onAutoReconnected = _onAutoReconnected;
    client.onDisconnected = _onDisconnected;

    _connect();

    Injector.appInstance.get<NyxxGateway>().onMessageCreate.listen((e) => dynamicMetricContext.messages++);
    Injector.appInstance.get<NyxxGateway>().onGuildMemberAdd.listen((e) => dynamicMetricContext.joins++);
    Injector.appInstance.get<NyxxGateway>().onGuildMemberRemove.listen((e) => dynamicMetricContext.removals++);
    Injector.appInstance.get<NyxxGateway>().onInteractionCreate.listen((e) => dynamicMetricContext.interactions++);
    Injector.appInstance.get<NyxxGateway>().onEvent.listen((e) => dynamicMetricContext.events++);
  }

  Future<void> _connect() async {
    await client.connect(metricsMqttUsername, metricsMqttPassword);
  }

  Future<void> _onDisconnected() async {
    _logger.warning("Disconnected. Stopping sending statistics...");

    publishStateTimer?.cancel();

    _logger.info("Trying to reconnect manually...");
    for (final _ in Iterable.generate(5)) {
      await Future.delayed(Duration(seconds: 15));

      try {
        await _connect();
      } on SocketException {
        _logger.warning("Reconnection failed...");
      }
    }

    _logger.severe("Cannot reconnect to metrics server. Exiting...");
  }

  Future<void> _onConnected() async {
    _logger.info("Connected. Starting processes...");

    ProcessSignal.sigint.watch().listen(close);
    ProcessSignal.sigterm.watch().listen(close);

    initialize();
  }

  Future<void> _onAutoReconnected() async {
    _logger.info("Reconnected. Re-starting processes...");

    initialize();
  }

  Future<void> initialize() async {
    publishAvailability();
    await Future.delayed(Duration(milliseconds: 200));

    publishConfig();
    await Future.delayed(Duration(milliseconds: 200));

    publishOneTimeMetrics();

    publishStateTimer = Timer.periodic(Duration(seconds: 60), publishState);
  }

  Future<void> close(ProcessSignal signal) async {
    publishStateTimer?.cancel();

    publishAvailability(false);

    await Future.delayed(Duration(milliseconds: 200));
    client.disconnect();
  }

  Future<void> publishOneTimeMetrics() async {
    for (final metric in oneTimeMetrics) {
      final currentValue = metric.extractValue();

      final buffer = Uint8Buffer();
      buffer.addAll(utf8.encode(currentValue.toString()));

      client.publishMessage(metric.stateTopic, MqttQos.atMostOnce, buffer, retain: true);
    }
  }

  Future<void> publishState(Timer timer) async {
    final botInfo = await Injector.appInstance.get<BotInfoService>().getCurrentBotInfo();

    for (final metric in periodicMetrics) {
      final currentValue = switch (metric) {
        BotInfoMetric(:final extractValue) => extractValue(botInfo),
        DiagnosticMetric(:final extractValue) => extractValue(),
        DynamicMetric(:final extractValue) => extractValue(dynamicMetricContext),
        StaticMetric(:final extractValue) => extractValue(),
        _ => throw StateError("Invalid metric type"),
      };

      final buffer = Uint8Buffer();
      buffer.addAll(utf8.encode(currentValue.toString()));

      client.publishMessage(metric.stateTopic, MqttQos.atMostOnce, buffer, retain: false);
    }

    _logger.fine("Published state for ${periodicMetrics.length} metrics");
  }

  void publishAvailability([bool isOnline = true]) {
    final statusPayload = isOnline ? "online" : "offline";

    final payloadBuilder = Uint8Buffer();
    payloadBuilder.addAll(utf8.encode(statusPayload));

    client.publishMessage(availabilityTopic, MqttQos.atLeastOnce, payloadBuilder, retain: true);

    _logger.fine("Published availability: $statusPayload");
  }

  void publishConfig() {
    for (final metric in [...oneTimeMetrics, ...periodicMetrics]) {
      final configTopic = "$discoveryPrefix/sensor/$deviceName/${metric.objectId}/config";

      final buffer = Uint8Buffer();
      buffer.addAll(utf8.encode(getConfigPayload(metric)));

      client.publishMessage(configTopic, MqttQos.atLeastOnce, buffer, retain: true);
    }

    _logger.fine("Published sensor configs");
  }

  String getConfigPayload(Metric metric) {
    final Map<String, dynamic> payload = {
      "name": metric.name,
      "state_topic": metric.stateTopic,
      "unique_id": "${deviceName}_${metric.objectId}",
      "device": {
        "identifiers": [botDeviceId],
        "name": botName,
        "manufacturer": "l7ssha.xyz",
        "model": "Running On Dart $version",
        "sw_version": version,
      },
      "availability_topic": availabilityTopic,
      "payload_available": "online",
      "payload_not_available": "offline",
      if (metric.stateClass != null) "state_class": metric.stateClass,
      if (metric.deviceClass != null) "device_class": metric.deviceClass,
      if (metric.unit != null) "unit_of_measurement": metric.unit,
      if (metric.icon != null) "icon": metric.icon,
      if (metric.isDiagnostic) "entity_category": "diagnostic",
    };

    return jsonEncode(payload);
  }
}
