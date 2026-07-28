import 'dart:async';

import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_extensions/nyxx_extensions.dart';
import 'package:running_on_dart/src/models/feature_settings.dart';
import 'package:running_on_dart/src/models/join_logs.dart';
import 'package:running_on_dart/src/repository/feature_settings.dart';
import 'package:running_on_dart/src/modules/feature_settings.dart';
import 'package:running_on_dart/src/repository/join_logs.dart';
import 'package:running_on_dart/src/settings.dart';
import 'package:running_on_dart/src/init.dart';
import 'package:running_on_dart/src/util/util.dart';

final RegExp suspiciousNameRegex = RegExp(r'^[A-Za-z]+[\._][A-Za-z]+_\d+_\d+$');

class JoinLogsModule implements RequiresInitialization {
  final NyxxGateway _client = Injector.appInstance.get();
  final FeatureSettingsRepository _featureSettingsRepository = Injector.appInstance.get();
  final FeatureSettingsModule _featureSettingsService = Injector.appInstance.get();
  final JoinLogsRepository _joinLogsRepository = Injector.appInstance.get();

  final Logger _logger = Logger('ROD.JoinLogs');

  @override
  Future<void> init() async {
    _client.onGuildMemberAdd.listen(_handleMemberAdd);
    _client.onGuildMemberRemove.listen(_handleMemberRemove);
  }

  Future<void> _handleMemberAdd(GuildMemberAddEvent event) async {
    final channel = await _getChannelIfFeatureEnabled(event.guildId);
    if (channel == null) {
      return;
    }

    _logger.fine('Sending join message for member ${event.member.id} in channel ${channel.id}');
    final flags = _buildJoinFlags(event.member.user, event.member.id.timestamp);
    final username = event.member.user?.username ?? event.member.user?.globalName ?? 'Unknown';

    final joinLogEntry = JoinLogEntry(
      id: 0,
      userId: event.member.id,
      username: username,
      guildId: event.guildId,
      messageId: null,
      createdAt: event.member.joinedAt.toUtc(),
      leftAt: null,
      flags: flags,
    );

    final message = await channel.sendMessage(
      MessageBuilder(embeds: [_buildJoinLogEmbed(joinLogEntry, event.member.user)]),
    );

    await _joinLogsRepository.save(
      JoinLogEntry(
        id: 0,
        userId: joinLogEntry.userId,
        username: joinLogEntry.username,
        guildId: joinLogEntry.guildId,
        messageId: message.id,
        createdAt: joinLogEntry.createdAt,
        leftAt: joinLogEntry.leftAt,
        flags: joinLogEntry.flags,
      ),
    );
  }

  Future<void> _handleMemberRemove(GuildMemberRemoveEvent event) async {
    final channel = await _getChannelIfFeatureEnabled(event.guildId);
    if (channel == null) {
      return;
    }

    if (event.removedMember != null && DateTime.now().difference(event.removedMember!.joinedAt).inDays > 7) {
      return;
    }

    _logger.fine('Trying to update join log message for user ${event.user.id} in channel ${channel.id}');

    final joinLogEntry = await _joinLogsRepository.findJoinLog(event.user.id, event.guildId);
    if (joinLogEntry == null) {
      return;
    }

    final leftAt = DateTime.now().toUtc();
    final updatedEntry = JoinLogEntry(
      id: joinLogEntry.id,
      userId: joinLogEntry.userId,
      username: joinLogEntry.username,
      guildId: joinLogEntry.guildId,
      messageId: joinLogEntry.messageId,
      createdAt: joinLogEntry.createdAt,
      leftAt: leftAt,
      flags: joinLogEntry.flags,
    );

    await _joinLogsRepository.updateLeftAtAndFlags(updatedEntry.id, leftAt, updatedEntry.flags);

    try {
      if (updatedEntry.messageId == null) {
        _logger.warning('Join log entry ${updatedEntry.id} has no messageId for guild ${event.guildId}');
        return;
      }

      final message = await channel.messages.get(updatedEntry.messageId!);

      _logger.fine('Found message to update: ${message.id} in channel ${channel.id}');

      final updatedEmbed = _buildJoinLogEmbed(updatedEntry, event.user);
      await message.update(MessageUpdateBuilder(embeds: [updatedEmbed]));
    } on Error {
      _logger.fine("Cannot obtain or update message");
    }

    scheduleMicrotask(() => _joinLogsRepository.removeOldLogs());
  }

  Future<TextChannel?> _getChannelIfFeatureEnabled(Snowflake guildId) async {
    final isEnabled = await _isEnabledForGuild(guildId);
    if (!isEnabled) {
      return null;
    }

    final setting = await _featureSettingsRepository.fetchSetting(Setting.joinLogs, guildId);
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

  EmbedBuilder _buildJoinLogEmbed(JoinLogEntry entry, User? user) {
    final descriptionBuffer = StringBuffer('**Member joined**');
    final tags = _buildFlagLabels(entry);
    if (tags.isNotEmpty) {
      descriptionBuffer.write(' (${tags.join(', ')})');
    }

    final fields = [
      EmbedFieldBuilder(name: idFieldName, value: userMention(entry.userId), isInline: true),
      EmbedFieldBuilder(name: 'Joined At', value: formatDateTimeString(entry.createdAt), isInline: true),
      EmbedFieldBuilder(
        name: 'Account created at',
        value: formatDateTimeString(entry.userId.timestamp),
        isInline: true,
      ),
    ];

    if (entry.leftAt != null) {
      fields.add(EmbedFieldBuilder(name: 'Left At', value: formatDateTimeString(entry.leftAt!), isInline: true));

      final onServerDuration = entry.createdAt.difference(entry.leftAt!);
      if (onServerDuration.inDays < 7) {
        fields.add(EmbedFieldBuilder(name: 'On server for', value: onServerDuration.formatReadable(), isInline: true));
      }
    }

    return EmbedBuilder(
      description: descriptionBuffer.toString(),
      author: EmbedAuthorBuilder(name: entry.username, iconUrl: user?.avatar.url),
      fields: fields,
    );
  }

  int _buildJoinFlags(User? user, DateTime accountCreatedAt) {
    var flags = JoinLogFlags.none;

    if (DateTime.now().difference(accountCreatedAt).inDays < 30) {
      flags |= JoinLogFlags.newUser;
    }

    if (user != null && _isSuspiciousName(user)) {
      flags |= JoinLogFlags.suspicious;
    }

    return flags;
  }

  List<String> _buildFlagLabels(JoinLogEntry entry) {
    final labels = <String>[];

    if (entry.hasFlag(JoinLogFlags.newUser)) {
      labels.add('New user');
    }

    if (entry.hasFlag(JoinLogFlags.suspicious)) {
      labels.add('Suspicious');
    }

    if (entry.leftAt != null) {
      labels.add('Left');
    }

    return labels;
  }

  bool _isSuspiciousName(User user) {
    if (user.globalName != null && suspiciousNameRegex.hasMatch(user.globalName!)) {
      return true;
    }

    return suspiciousNameRegex.hasMatch(user.username);
  }

  Future<bool> _isEnabledForGuild(Snowflake guildId) async {
    if (!intentFeaturesEnabled) {
      return false;
    }

    return await _featureSettingsService.isEnabled(Setting.joinLogs, guildId);
  }
}
