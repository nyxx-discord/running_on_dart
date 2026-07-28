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
import 'package:running_on_dart/src/util/util.dart';

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

    final extraData = _getExtraData(entry);

    final embed = _buildModLogEmbed(
      actionType: entry.actionType,
      createdAt: DateTime.now().toUtc(),
      reason: entry.reason,
      additionalData: extraData,
      targetUser: targetUser,
      modUser: modUser,
    );
    final message = await channel.sendMessage(MessageBuilder(embeds: [embed]));

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
      final updatedEmbed = _buildModLogEmbed(
        actionType: AuditLogEvent(updatedEntry.actionType),
        createdAt: updatedEntry.createdAt,
        reason: updatedEntry.reason,
        additionalData: updatedEntry.additionalData,
        targetUser: targetUser,
        modUser: modUser,
      );

      await message.update(MessageUpdateBuilder(embeds: [updatedEmbed]));

      await _modLogsRepository.updateReason(updatedEntry.id, reason, updatedBy);
      return true;
    } catch (error) {
      _logger.warning('Failed to update latest mod log entry reason', error);
      return false;
    }
  }

  EmbedBuilder _buildModLogEmbed({
    required AuditLogEvent actionType,
    required DateTime createdAt,
    required String? reason,
    required Map<String, dynamic>? additionalData,
    required User targetUser,
    required User modUser,
  }) {
    final fields = [
      EmbedFieldBuilder(name: idFieldName, value: userMention(targetUser.id), isInline: true),
      EmbedFieldBuilder(name: 'Moderator', value: userMention(modUser.id), isInline: true),
      EmbedFieldBuilder(name: 'At', value: formatDateTimeString(createdAt), isInline: true),
    ];

    final extraDataField = _buildExtraDataField(actionType, additionalData);
    if (extraDataField != null) {
      fields.add(extraDataField);
    }

    fields.add(EmbedFieldBuilder(name: 'Reason', value: reason ?? 'No reason provided', isInline: false));

    return EmbedBuilder(
      description: '**${getEventTypeName(actionType)}**',
      author: EmbedAuthorBuilder(name: targetUser.username, iconUrl: targetUser.avatar.url),
      fields: fields,
    );
  }

  bool isMemberTimeoutEntry(AuditLogEntry auditLogEntry, AuditLogChange? auditLogChange) =>
      auditLogEntry.actionType == AuditLogEvent.memberUpdate && auditLogChange?.key == 'communication_disabled_until';

  EmbedFieldBuilder? _buildExtraDataField(AuditLogEvent actionType, Map<String, dynamic>? data) {
    if (data == null) {
      return null;
    }

    if (actionType == AuditLogEvent.memberUpdate && data['timeout_until'] != null) {
      final timeoutUntil = DateTime.parse(data['timeout_until'] as String);
      return EmbedFieldBuilder(name: 'Until', value: timeoutUntil.format(TimestampStyle.relativeTime), isInline: true);
    }

    if (actionType == AuditLogEvent.memberPrune && data['pruned_count'] != null) {
      return EmbedFieldBuilder(name: 'Pruned count', value: data['pruned_count'].toString(), isInline: true);
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
