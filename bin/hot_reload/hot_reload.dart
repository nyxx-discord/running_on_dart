import "dart:io";

import "package:jaguar_hotreload/jaguar_hotreload.dart";
import 'package:nyxx.commander/commander.dart';
import 'package:path/path.dart' as path;
import 'dart:developer' as dev;

import "reloaded.dart";

late HotReloader reloader;

Future<void> initReloader() async {
  var info = await dev.Service.getInfo();
  var uri = info.serverUri!;
  uri = uri.replace(path: path.join(uri.path, 'ws'));
  if (uri.scheme == 'https') {
    uri = uri.replace(scheme: 'wss');
  } else {
    uri = uri.replace(scheme: 'ws');
  }

  print('Hot reloading enabled');
  reloader = HotReloader(vmServiceUrl: uri.toString());
  reloader.addPath("/mnt/data3/PROJECTS/running_on_dart/bin/hot_reload/");
  await reloader.go();
}

Future<dynamic> hotReloadCode(String code, CommandContext context) async {
  if (!code.contains("return")) {
    code = "return $code";
  }

  if (!code.endsWith(";")) {
    code = "$code;";
  }

  final fileCode = """
    import 'package:nyxx/nyxx.dart';
    import 'package:nyxx.commander/commander.dart';

    Future<dynamic> execute(CommandContext ctx) async {
      $code
    }
  """;

  await File("/mnt/data3/PROJECTS/running_on_dart/bin/hot_reload/reloaded.dart").writeAsString(fileCode, mode: FileMode.writeOnly);
  await reloader.reload();

  return execute(context);
}