import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_extensions/nyxx_extensions.dart';
import 'package:running_on_dart/src/models/feature_settings.dart';
import 'package:running_on_dart/src/models/mod_log.dart';
import 'package:running_on_dart/src/repository/feature_settings.dart';
import 'package:running_on_dart/src/repository/mod_logs.dart';
import 'package:running_on_dart/src/modules/feature_settings.dart';
import 'package:running_on_dart/src/init.dart';
import 'package:running_on_dart/src/settings.dart';

String getEventTypeName(AuditLogEvent actionType) {
  return switch (actionType) {
    AuditLogEvent.memberKick => 'Kick',
    AuditLogEvent.memberBanAdd => 'Ban',
    AuditLogEvent.memberUpdate => 'Timeout Added',
    AuditLogEvent.memberPrune => 'Members Pruned',
    _ => throw UnimplementedError(),
  };
}

class ModLogsModule implements RequiresInitialization {
  final NyxxGateway _client = Injector.appInstance.get();
  final FeatureSettingsRepository _featureSettingsRepository = Injector.appInstance.get();
  final FeatureSettingsModule _featureSettingsService = Injector.appInstance.get();
  final ModLogsRepository _modLogsRepository = Injector.appInstance.get();
  final Logger _logger = Logger('ROD.ModLogs');

  Map<AuditLogEvent, List<String>> handledEventTypes = {
    AuditLogEvent.memberUpdate: ['communication_disabled_until'],
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
    final message = await channel.sendMessage(messageBuilder);

    final extraData = _getExtraData(entry);

    await _modLogsRepository.save(
      ModLogEntry(
        id: 0,
        guildId: event.guildId,
        messageId: message.id,
        actionType: entry.actionType.value,
        targetUserId: targetUser.id,
        moderatorUserId: modUser.id,
        reason: entry.reason,
        createdAt: message.timestamp,
        updatedAt: null,
        updatedBy: null,
        additionalData: extraData,
      ),
    );
  }

  Future<bool> updateLatestLogReason(Snowflake guildId, String reason, Snowflake updatedBy) async {
    final channel = await _getChannelIfFeatureEnabled(guildId);
    if (channel == null) {
      return false;
    }

    final latestEntry = await _modLogsRepository.findLatestForGuild(guildId);
    if (latestEntry == null) {
      return false;
    }

    try {
      final message = await channel.messages.get(latestEntry.messageId);
      final updatedEntry = ModLogEntry(
        id: latestEntry.id,
        guildId: latestEntry.guildId,
        messageId: latestEntry.messageId,
        actionType: latestEntry.actionType,
        targetUserId: latestEntry.targetUserId,
        moderatorUserId: latestEntry.moderatorUserId,
        reason: reason,
        createdAt: latestEntry.createdAt,
        updatedAt: DateTime.now().toUtc(),
        updatedBy: updatedBy,
        additionalData: latestEntry.additionalData,
      );

      final targetUser = await _client.users.get(updatedEntry.targetUserId);
      final modUser = await _client.users.get(updatedEntry.moderatorUserId);
      final updatedMessage = _prepareMessageFromEntry(updatedEntry, targetUser, modUser);

      await message.update(
        MessageUpdateBuilder(content: updatedMessage.content, allowedMentions: updatedMessage.allowedMentions),
      );

      await _modLogsRepository.updateReason(updatedEntry.id, reason, updatedBy);
      return true;
    } catch (error) {
      _logger.warning('Failed to update latest mod log entry reason', error);
      return false;
    }
  }

  MessageBuilder _prepareMessage(AuditLogEntry auditLogEntry, User targetUser, User modUser) {
    final eventTypeName = getEventTypeName(auditLogEntry.actionType);

    final messageBuffer = StringBuffer('$eventTypeName | ${DateTime.now().format(TimestampStyle.longDateTime)}')
      ..writeln('\nUser: ${targetUser.username} (${targetUser.mention})');

    final additionalMessageData = getAdditionalMessageData(auditLogEntry, eventTypeName);
    if (additionalMessageData != null) {
      messageBuffer.writeln(additionalMessageData);
    }

    if (auditLogEntry.reason != null) {
      messageBuffer.writeln('Reason: ${auditLogEntry.reason}');
    }

    messageBuffer.writeln('Moderator: ${modUser.username} (${modUser.mention})');

    return MessageBuilder(content: messageBuffer.toString(), allowedMentions: AllowedMentions.users([targetUser.id]));
  }

  String? getAdditionalMessageData(AuditLogEntry auditLogEntry, String eventTypeName) {
    final extraData = _getExtraData(auditLogEntry);

    return _buildExtraDataLine(auditLogEntry.actionType, extraData);
  }

  bool isMemberTimeoutEntry(AuditLogEntry auditLogEntry, AuditLogChange? auditLogChange) =>
      auditLogEntry.actionType == AuditLogEvent.memberUpdate && auditLogChange?.key == 'communication_disabled_until';

  String? _buildExtraDataLine(AuditLogEvent actionType, Map<String, dynamic>? data) {
    if (data == null) {
      return null;
    }

    if (actionType == AuditLogEvent.memberUpdate && data['timeout_until'] != null) {
      final timeoutUntil = DateTime.parse(data['timeout_until'] as String);
      return "Until: ${timeoutUntil.format(TimestampStyle.relativeTime)}";
    }

    if (actionType == AuditLogEvent.memberPrune && data['pruned_count'] != null) {
      return "Pruned count: ${data['pruned_count']}";
    }

    return null;
  }

  Map<String, dynamic>? _getExtraData(AuditLogEntry auditLogEntry) {
    final auditLogChange = auditLogEntry.changes?.first;
    if (isMemberTimeoutEntry(auditLogEntry, auditLogChange)) {
      final timeoutUntil = DateTime.parse(auditLogChange!.newValue as String);
      return {'timeout_until': timeoutUntil.toUtc().toIso8601String()};
    }

    if (auditLogEntry.actionType == AuditLogEvent.memberPrune) {
      final membersRemoved = auditLogEntry.options?.membersRemoved;
      final prunedCount = membersRemoved == null ? null : int.tryParse(membersRemoved.toString());
      if (prunedCount == null) {
        return null;
      }

      return {'pruned_count': prunedCount};
    }

    return null;
  }

  MessageBuilder _prepareMessageFromEntry(ModLogEntry entry, User targetUser, User modUser) {
    final actionType = AuditLogEvent(entry.actionType);

    final messageBuffer = StringBuffer(
      '${getEventTypeName(actionType)} | ${entry.createdAt.format(TimestampStyle.longDateTime)}',
    )..writeln('\nUser: ${targetUser.username} (${targetUser.mention})');

    final extraLine = _buildExtraDataLine(actionType, entry.additionalData);
    if (extraLine != null) {
      messageBuffer.writeln(extraLine);
    }

    if (entry.reason != null) {
      messageBuffer.writeln('Reason: ${entry.reason}');
    }

    messageBuffer.writeln('Moderator: ${modUser.username} (${modUser.mention})');

    return MessageBuilder(content: messageBuffer.toString(), allowedMentions: AllowedMentions.users([targetUser.id]));
  }

  Future<TextChannel?> _getChannelIfFeatureEnabled(Snowflake guildId) async {
    final isEnabled = await _isEnabledForGuild(guildId);
    if (!isEnabled) {
      return null;
    }

    final setting = await _featureSettingsRepository.fetchSetting(Setting.modLogs, guildId);
    if (setting == null) {
      return null;
    }

    final channelId = setting.parseData<GenericSnowflakeData>()!.value;
    final channel = await _client.channels.get(channelId);
    if (channel is! TextChannel) {
      _logger.warning('Channel $channelId is not a text channel.');
      return null;
    }

    return channel;
  }

  Future<bool> _isEnabledForGuild(Snowflake guildId) async {
    if (!intentFeaturesEnabled) {
      return false;
    }

    return await _featureSettingsService.isEnabled(Setting.modLogs, guildId);
  }
}
