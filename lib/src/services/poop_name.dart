import 'package:logging/logging.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/models/guild_settings.dart';

const _poopEmoji = "💩";
final _poopRegexp = RegExp(r"[!#@^%&-*\.+']");

class PoopNameService {
  static PoopNameService get instance => _instance ?? (throw Exception('PoopNameService must be initialised with PoopNameService.init'));
  static PoopNameService? _instance;

  static void init(INyxxWebsocket client) {
    _instance = PoopNameService._(client);
  }

  final INyxxWebsocket _client;
  final Logger _logger = Logger('ROD.PoopName');

  PoopNameService._(this._client) {
    _client.eventsWs.onGuildMemberAdd.listen((event) => _handle(event.member));
    _client.eventsWs.onGuildMemberUpdate.listen((event) async => _handle(await event.member.getOrDownload()));
  }

  void _handle(IMember member) async {
    if (!await GuildSettingsService.instance.isEnabled(Setting.poopName, member.guild.id) || !intentFeaturesEnabled) {
      return;
    }

    if ((member.nickname ?? (await member.user.getOrDownload()).username).startsWith(_poopRegexp)) {
      _logger.fine("Changing ${member.id} (${member.nickname ?? member.user.getFromCache()?.username})'s nickname to poop emoji");

      await member.edit(builder: MemberBuilder()..nick = _poopEmoji);
    }
  }
}
