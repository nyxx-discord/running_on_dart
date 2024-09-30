import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_extensions/nyxx_extensions.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/commands/tag.dart';
import 'package:running_on_dart/src/modules/jellyfin.dart';

void main() async {
  final commands = CommandsPlugin(
    prefix: null,
    guild: devGuildId,
    options: CommandsOptions(logErrors: dev),
  );

  commands
    ..addCommand(avatar)
    ..addCommand(docs)
    ..addCommand(featureSettings)
    ..addCommand(github)
    ..addCommand(info)
    ..addCommand(ping)
    ..addCommand(tag)
    ..addCommand(reminder)
    ..addCommand(admin)
    ..addCommand(jellyfin)
    ..addConverter(settingsConverter)
    ..addConverter(manageableTagConverter)
    ..addConverter(durationConverter)
    ..addConverter(reminderConverter);

  commands.onCommandError.listen((error) {
    if (error is CheckFailedException) {
      error.context.respond(MessageBuilder(content: "Sorry, you can't use that command!"));
    }
  });

  final client = await Nyxx.connectGateway(token, intents,
      options: GatewayClientOptions(
        plugins: [
          Logging(),
          CliIntegration(),
          IgnoreExceptions(),
          commands,
          pagination,
        ],
      ));

  await DatabaseService.instance.awaitReady();

  PoopNameModule.init(client);
  JoinLogsModule.init(client);
  ReminderModule.init(client);
  ModLogsModule.init(client);
  TagModule.init();
  DocsModule.init();
  JellyfinModule.init();

  // final sessions = await JellyfinService.instance.fetchCurrentSessions();
  // final firstSession = sessions.first;
  //
  // final nowPlayingItem = firstSession.nowPlayingItem!;
  //
  // print(Duration(microseconds: nowPlayingItem.runTimeTicks! ~/ 10));
  // print(Duration(microseconds: firstSession.playState!.positionTicks! ~/ 10));

//
//   print(nowPlayingItem.name);
//   print(nowPlayingItem.type?.name);
//
//   final seasonInfo = await JellyfinService.instance.getSeasonInfo(nowPlayingItem.parentId!);
//
//   print(seasonInfo!);
//
//   // final image = await JellyfinService.instance.jellyfinClient.getImageApi().getItemImageInfos(itemId: nowPlayingItem.id!, imageType: ImageType.primary);
// // https://jellyfin.proxmox.lshk.cc/Items/6e8da2e085e8fd5d0a139fdf44ac5e30/Images/Primary
// // https://jellyfin.proxmox.lshk.cc/Items/cdc674b790f4208c0a38e90ee78c64a6/Images/Primary
// // https://jellyfin.proxmox.lshk.cc/Items/70669122b137623cecd9c8757b0578c3/Images/Primary
}
