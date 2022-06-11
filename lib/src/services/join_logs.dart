import 'package:logging/logging.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/models/guild_settings.dart';

class JoinLogsService {
  static JoinLogsService get instance => _instance ?? (throw Exception('JoinLogsService must be initialised with JoinLogsService.init()'));
  static JoinLogsService? _instance;

  static void init(INyxxWebsocket client) {
    _instance = JoinLogsService._(client);
  }

  final INyxxWebsocket _client;
  final Logger _logger = Logger('ROD.JoinLogs');

  JoinLogsService._(this._client) {
    _client.eventsWs.onGuildMemberAdd.listen(_handle);
  }

  void _handle(IGuildMemberAddEvent event) async {
    if (!await GuildSettingsService.instance.isEnabled(Setting.joinLogs, event.guild.id) || !intentFeaturesEnabled) {
      return;
    }

    final channelId = (await GuildSettingsService.instance.getSetting(Setting.joinLogs, event.guild.id))!.data;
    final channel = _client.channels[channelId];

    if (channel is ITextChannel) {
      _logger.fine('Sending join message for member ${event.member.id} in channel $channelId');

      final now = DateTime.now();

      final embed = EmbedBuilder()
        ..addAuthor((author) {
          author.iconUrl = event.user.avatarURL();
          author.name = event.user.tag;
        })
        ..description = '**Member joined**'
        ..addField(name: 'ID', content: event.user.id, inline: true)
        ..addField(
          name: 'Joined',
          content: '${TimeStampStyle.shortDate.format(now)} (${TimeStampStyle.relativeTime.format(now)})',
          inline: true,
        )
        ..addField(
          name: 'Account created',
          content: '${TimeStampStyle.shortDate.format(event.user.id.timestamp)} (${TimeStampStyle.relativeTime.format(event.user.id.timestamp)})',
        );

      await channel.sendMessage(MessageBuilder.embed(embed));
    } else {
      _logger.warning('Channel $channelId is not a text channel.');
    }
  }
}
