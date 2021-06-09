import "dart:io" show Platform, ProcessInfo;

import 'package:nyxx/nyxx.dart';
import "package:nyxx_commander/commander.dart";

String? get envPrefix => Platform.environment["ROD_PREFIX"];
String? get envHotReload => Platform.environment["ROD_HOT_RELOAD"];
String? get envToken => Platform.environment["ROD_TOKEN"];
String? get envAdminId => Platform.environment["ROD_ADMIN_ID"];

DateTime _approxMemberCountLastAccess = DateTime.utc(2005);
int _approxMemberCount = -1;
int _approxMemberOnline = -1;

String get dartVersion {
  final platformVersion = Platform.version;
  return platformVersion.split("(").first;
}

String helpCommandGen(String commandName, String description, {String? additionalInfo}) {
  final buffer = StringBuffer();

  buffer.write("**$envPrefix$commandName**");

  if (additionalInfo != null) {
    buffer.write(" `$additionalInfo`");
  }

  buffer.write(" - $description.\n");

  return buffer.toString();
}

String getMemoryUsageString() {
  final current = (ProcessInfo.currentRss / 1024 / 1024).toStringAsFixed(2);
  final rss = (ProcessInfo.maxRss / 1024 / 1024).toStringAsFixed(2);
  return "$current/${rss}MB";
}

Future<bool> checkForAdmin(CommandContext context) async {
  if(envAdminId != null) {
    return context.author.id == envAdminId;
  }

  return false;
}

String getApproxMemberCount(Nyxx client) {
  if (DateTime.now().difference(_approxMemberCountLastAccess).inMinutes > 5 || _approxMemberCount == -1) {
    Future(() async {
      var amc = 0;
      var amo = 0;

      for (final element in client.guilds.values) {
        final guildPreview = await element.fetchGuildPreview();

        amc += guildPreview.approxMemberCount;
        amo += guildPreview.approxOnlineMembers;
      }

      _approxMemberCount = amc;
      _approxMemberOnline = amo;
    });
  }

  return "$_approxMemberOnline/$_approxMemberCount";
}
