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

class JoinLogsModule implements RequiresInitialization {
  final NyxxGateway _client = Injector.appInstance.get();
  final FeatureSettingsRepository _featureSettingsRepository = Injector.appInstance.get();
  final FeatureSettingsModule _featureSettingsService = Injector.appInstance.get();

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

    final descriptionBuffer = StringBuffer('**Member joined**');
    if (DateTime.now().difference(event.member.id.timestamp).inDays < 30) {
      descriptionBuffer.write(" (New user)");
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
    final channel = await _getChannelIfFeatureEnabled(event.guildId);
    if (channel == null) {
      return;
    }

    if (event.removedMember != null && DateTime.now().difference(event.removedMember!.joinedAt).inDays > 7) {
      return;
    }

    _logger.fine('Trying to update join log message for user ${event.user.id} in channel ${channel.id}');

    final messages = channel.messages
        .stream(pageSize: 20, order: StreamOrder.mostRecentFirst)
        .where((message) => message.embeds.isNotEmpty)
        .where(
          (message) =>
              message.embeds.first.fields
                  ?.firstWhereOrNull((f) => f.name == idFieldName)
                  ?.value
                  .contains(event.user.id.toString()) !=
              null,
        );

    final message = (await messages.toList()).firstOrNull;
    if (message == null) {
      return;
    }

    final embed = message.embeds.first.toEmbedBuilder();
    if (embed.description?.contains("(Left") ?? true) {
      return;
    }

    embed.description = "${embed.description} (Left)";

    message.update(MessageUpdateBuilder(embeds: [embed]));
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

  Future<bool> _isEnabledForGuild(Snowflake guildId) async {
    if (!intentFeaturesEnabled) {
      return false;
    }

    return await _featureSettingsService.isEnabled(Setting.joinLogs, guildId);
  }
}
