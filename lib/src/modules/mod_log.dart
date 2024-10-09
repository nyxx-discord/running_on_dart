import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_extensions/nyxx_extensions.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/models/feature_settings.dart';
import 'package:running_on_dart/src/repository/feature_settings.dart';
import 'package:running_on_dart/src/services/feature_settings.dart';

class ModLogsModule {
  final NyxxGateway _client = Injector.appInstance.get();
  final FeatureSettingsRepository _featureSettingsRepository = Injector.appInstance.get();
  final FeatureSettingsService _featureSettingsService = Injector.appInstance.get();
  final Logger _logger = Logger('ROD.ModLogs');

  final handledEventTypes = [
    AuditLogEvent.memberUpdate,
    AuditLogEvent.memberBanAdd,
    AuditLogEvent.memberKick,
  ];

  ModLogsModule() {
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
    if (!handledEventTypes.contains(entry.actionType)) {
      return;
    }

    final channelId = setting.data!;
    final channel = await _client.channels.get(Snowflake.parse(channelId));
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

    var timeoutUntilMessage = "";
    final auditLogChange = auditLogEntry.changes?.first;
    if (auditLogEntry.actionType == AuditLogEvent.memberUpdate &&
        auditLogChange?.key == 'communication_disabled_until') {
      final timeoutUntil = DateTime.parse(auditLogChange!.newValue as String);
      timeoutUntilMessage = "\nUntil: ${timeoutUntil.format(TimestampStyle.relativeTime)}";
    }

    final messageContent = """$eventTypeName | ${DateTime.now().format(TimestampStyle.longDateTime)}
User: ${targetUser.username} (${targetUser.mention})$timeoutUntilMessage
Reason: ${auditLogEntry.reason}
Moderator: ${modUser.username} (${modUser.mention})
""";

    return MessageBuilder(
      content: messageContent,
      allowedMentions: AllowedMentions.users([targetUser.id]),
    );
  }

  Future<bool> _isEnabledForGuild(Snowflake guildId) async {
    if (!intentFeaturesEnabled) {
      return false;
    }

    return await _featureSettingsService.isEnabled(Setting.modLogs, guildId);
  }
}
