import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:collection/collection.dart';
import 'package:nyxx_extensions/nyxx_extensions.dart';
import 'package:running_on_dart/src/models/feature_settings.dart';
import 'package:running_on_dart/src/repository/feature_settings.dart';
import 'package:running_on_dart/src/modules/feature_settings.dart';
import 'package:running_on_dart/src/settings.dart';
import 'package:running_on_dart/src/init.dart';

const idFieldName = 'ID';
final RegExp suspiciousNameRegex = RegExp(r'^[A-Za-z]+[\._][A-Za-z]+_\d+_\d+$');

class JoinLogsModule implements RequiresInitialization {
  final NyxxGateway _client = Injector.appInstance.get();
  final FeatureSettingsRepository _featureSettingsRepository = Injector.appInstance.get();
  final FeatureSettingsModule _featureSettingsService = Injector.appInstance.get();

  final Logger _logger = Logger('ROD.JoinLogs');

  @override
  Future<void> init() async {
    _client.onGuildMemberAdd.listen(_handleMemberAdd);
    _client.onGuildMemberRemove.listen(_handleMemberRemove);
    _logger.info('JoinLogsModule initialized: listeners registered for GuildMemberAdd and GuildMemberRemove');
  }

  Future<void> _handleMemberAdd(GuildMemberAddEvent event) async {
    final channel = await _getChannelIfFeatureEnabled(event.guildId);
    if (channel == null) {
      return;
    }

    _logger.fine('Sending join message for member ${event.member.id} in channel ${channel.id}');

    final descriptionBuffer = StringBuffer('**Member joined**');
    if (DateTime.now().difference(event.member.id.timestamp).inDays < 30) {
      descriptionBuffer.write(" (New user)");
    }

    if (event.member.user != null && _isSuspiciousName(event.member.user!)) {
      descriptionBuffer.write(" (Suspicious)");
    }

    final embed = EmbedBuilder(
      description: descriptionBuffer.toString(),
      author: EmbedAuthorBuilder(name: event.member.user!.username, iconUrl: event.member.user!.avatar.url),
      fields: [
        EmbedFieldBuilder(name: idFieldName, value: userMention(event.member.id), isInline: true),
        EmbedFieldBuilder(name: 'Joined At', value: _formatDateTimeString(event.member.joinedAt), isInline: true),
        EmbedFieldBuilder(
          name: 'Account created at',
          value: _formatDateTimeString(event.member.id.timestamp),
          isInline: true,
        ),
      ],
    );

    channel.sendMessage(MessageBuilder(embeds: [embed]));
  }

  Future<void> _handleMemberRemove(GuildMemberRemoveEvent event) async {
    _logger.fine(
      'GuildMemberRemove received: guild=${event.guildId} user=${event.user.id} removedMemberPresent=${event.removedMember != null}',
    );

    final channel = await _getChannelIfFeatureEnabled(event.guildId);
    if (channel == null) {
      _logger.fine('JoinLogs disabled or channel not configured for guild ${event.guildId}');
      return;
    }

    final joinedAt = event.removedMember?.joinedAt;
    final daysSinceJoin = joinedAt != null ? DateTime.now().difference(joinedAt).inDays : null;

    if (event.removedMember != null && daysSinceJoin != null && daysSinceJoin > 7) {
      _logger.fine(
        'Skipping leave mark; member joined >7 days ago. guild=${event.guildId} user=${event.user.id} joinedAt=$joinedAt daysSinceJoin=$daysSinceJoin',
      );
      return;
    }

    _logger.fine('Searching recent messages for user ${event.user.id} in channel ${channel.id}');

    final messagesStream = channel.messages
        .stream(pageSize: 50, order: StreamOrder.mostRecentFirst)
        .where((m) => m.embeds.isNotEmpty)
        .where((m) => _messageMatchesUser(m, event.user.id));

    final messagesList = await messagesStream.toList();
    _logger.fine('Searched ${messagesList.length} messages for user=${event.user.id} in channel=${channel.id}');

    final message = messagesList.firstOrNull;
    if (message == null) {
      _logger.info('No join message found to update for user ${event.user.id} in channel ${channel.id}');
      return;
    }

    final embed = message.embeds.first.toEmbedBuilder();
    final before = embed.description ?? '';
    final hasLeft = before.contains('(Left');

    if (hasLeft) {
      _logger.severe(
        'Already marked as Left, possible duplicate _handleMemberRemove call. '
        'guild=${event.guildId} channel=${channel.id} messageId=${message.id} user=${event.user.id} '
        'removedMemberPresent=${event.removedMember != null} joinedAt=${event.removedMember?.joinedAt} '
        'desc="$before"',
      );
      return;
    }

    embed.description = '$before (Left)';

    message.update(MessageUpdateBuilder(embeds: [embed]));
    _logger.severe(
      'Marked user as Left (first time). '
      'guild=${event.guildId} channel=${channel.id} messageId=${message.id} user=${event.user.id} '
      'removedMemberPresent=${event.removedMember != null} joinedAt=${event.removedMember?.joinedAt} '
      'descBefore="$before" descAfter="${embed.description}"',
    );
  }

  bool _messageMatchesUser(Message message, Snowflake userId) {
    try {
      if (message.embeds.isEmpty) return false;
      final fields = message.embeds.first.fields ?? const [];
      final idField = fields.firstWhereOrNull((f) => f.name == idFieldName);
      final value = idField?.value;
      return value != null && value.contains(userId.toString());
    } catch (_) {
      return false;
    }
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

  String _formatDateTimeString(DateTime dateTime) =>
      '${dateTime.format(TimestampStyle.shortDate)} (${dateTime.format(TimestampStyle.relativeTime)})';

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
