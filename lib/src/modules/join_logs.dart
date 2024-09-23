
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_extensions/nyxx_extensions.dart';
import 'package:running_on_dart/src/models/feature_settings.dart';
import 'package:running_on_dart/src/repository/feature_settings.dart';
import 'package:running_on_dart/src/services/feature_settings.dart';
import 'package:running_on_dart/src/settings.dart';

class JoinLogsModule {
  static JoinLogsModule get instance =>
      _instance ??
          (throw Exception(
              'JoinLogsService must be initialised with JoinLogsService.init()'));
  static JoinLogsModule? _instance;

  static void init(NyxxGateway client) {
    _instance = JoinLogsModule._(client);
  }

  final NyxxGateway _client;
  final Logger _logger = Logger('ROD.JoinLogs');

  JoinLogsModule._(this._client) {
    _client.onGuildMemberAdd.listen(_handle);
  }

  void _handle(GuildMemberAddEvent event) async {
    final isEnabled = await _isEnabledForGuild(event.guildId);
    if (!isEnabled) {
      return;
    }

    final setting = await FeatureSettingsRepository.instance.fetchSetting(Setting.joinLogs, event.guildId);
    if (setting == null) {
      return;
    }

    final channelId = setting.data!;
    final channel = await _client.channels.get(Snowflake.parse(channelId));
    if (channel is! TextChannel) {
      _logger.warning('Channel $channelId is not a text channel.');
      return;
    }

    _logger.fine('Sending join message for member ${event.member.id} in channel $channelId');

    final now = DateTime.now();

    final embed = EmbedBuilder(
      description: '**Member joined**',
      author: EmbedAuthorBuilder(name: event.member.user!.username, iconUrl: event.member.user!.avatar.url),
      fields: [
        EmbedFieldBuilder(name: 'ID', value: event.member.id.toString(), isInline: true),
        EmbedFieldBuilder(name: 'Joined At', value: _formatDateTimeString(now), isInline: true),
        EmbedFieldBuilder(name: 'Account created at', value: formatDate(event.member.id.timestamp), isInline: true)
      ]
    );

    channel.sendMessage(MessageBuilder(embeds: [embed]));
  }

  String _formatDateTimeString(DateTime dateTime) => '${dateTime.format(TimestampStyle.shortDate)}, (${dateTime.format(TimestampStyle.relativeTime)})';

  Future<bool> _isEnabledForGuild(Snowflake guildId) async {
    if (!intentFeaturesEnabled) {
      return false;
    }

    return await FeatureSettingsService.instance.isEnabled(Setting.joinLogs, guildId);
  }
}
