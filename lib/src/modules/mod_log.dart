import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_extensions/nyxx_extensions.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/models/feature_settings.dart';
import 'package:running_on_dart/src/repository/feature_settings.dart';
import 'package:running_on_dart/src/modules/feature_settings.dart';
import 'package:running_on_dart/src/util/util.dart';

class ModLogsModule implements RequiresInitialization {
  final NyxxGateway _client = Injector.appInstance.get();
  final FeatureSettingsRepository _featureSettingsRepository = Injector.appInstance.get();
  final FeatureSettingsModule _featureSettingsService = Injector.appInstance.get();
  final Logger _logger = Logger('ROD.ModLogs');

  Map<AuditLogEvent, List<String>> handledEventTypes = {
    AuditLogEvent.memberUpdate: [
      'communication_disabled_until',
    ],
    AuditLogEvent.memberBanAdd: [],
    AuditLogEvent.memberKick: [],
  };

  @override
  Future<void> init() async {
    _client.onGuildAuditLogCreate.listen(_handleAuditLogAdd);
  }

  Future<void> _handleAuditLogAdd(GuildAuditLogCreateEvent event) async {
    final isEnabled = await _isEnabledForGuild(event.guildId);
    if (!isEnabled) {
      return;
    }

    final setting = await _featureSettingsRepository.fetchSetting(Setting.modLogs, event.guildId);
    if (setting == null) {
      return;
    }

    final entry = event.entry;
    final handledEventType = handledEventTypes[entry.actionType];
    if (handledEventType == null ||
        (handledEventType.isNotEmpty && !handledEventType.contains(entry.changes?.firstOrNull?.key))) {
      return;
    }

    final channelId = setting.parseData<GenericSnowflakeData>()!.value;
    final channel = await _client.channels.get(channelId);
    if (channel is! TextChannel) {
      _logger.warning('Channel $channelId is not a text channel.');
      return;
    }

    final targetUser = await _client.users.get(event.entry.targetId!);
    final modUser = await _client.users.get(event.entry.userId!);

    final messageBuilder = _prepareMessage(entry, targetUser, modUser);
    channel.sendMessage(messageBuilder);
  }

  MessageBuilder _prepareMessage(AuditLogEntry auditLogEntry, User targetUser, User modUser) {
    final eventTypeName = switch (auditLogEntry.actionType) {
      AuditLogEvent.memberKick => 'Kick',
      AuditLogEvent.memberBanAdd => 'Ban',
      AuditLogEvent.memberUpdate => 'Timeout Added',
      _ => throw UnimplementedError(),
    };

    final messageBuffer = StringBuffer('$eventTypeName | ${DateTime.now().format(TimestampStyle.longDateTime)}')
      ..writeln('User: ${targetUser.username} (${targetUser.mention})');

    final auditLogChange = auditLogEntry.changes?.first;
    if (isMemberTimeoutEntry(auditLogEntry, auditLogChange)) {
      final timeoutUntil = DateTime.parse(auditLogChange!.newValue as String);
      messageBuffer.writeln("Until: ${timeoutUntil.format(TimestampStyle.relativeTime)}");
    }

    if (auditLogEntry.reason != null) {
      messageBuffer.writeln('Reason: ${auditLogEntry.reason}');
    }

    messageBuffer.writeln('Moderator: ${modUser.username} (${modUser.mention})');

    return MessageBuilder(
      content: messageBuffer.toString(),
      allowedMentions: AllowedMentions.users([targetUser.id]),
    );
  }

  bool isMemberTimeoutEntry(AuditLogEntry auditLogEntry, AuditLogChange? auditLogChange) =>
      auditLogEntry.actionType == AuditLogEvent.memberUpdate && auditLogChange?.key == 'communication_disabled_until';

  Future<bool> _isEnabledForGuild(Snowflake guildId) async {
    if (!intentFeaturesEnabled) {
      return false;
    }

    return await _featureSettingsService.isEnabled(Setting.modLogs, guildId);
  }
}
