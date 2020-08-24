import "dart:developer" as dev;
import "dart:io" show File, FileMode;

import "package:jaguar_hotreload/jaguar_hotreload.dart" show HotReloader;
import "package:nyxx_commander/commander.dart" show CommandContext;
import "package:path/path.dart" as path;

import "reloaded.dart" show execute;

late HotReloader _reloader;

Future<void> initReloader() async {
  final info = await dev.Service.getInfo();
  var uri = info.serverUri!;
  uri = uri.replace(path: path.join(uri.path, "ws"));
  if (uri.scheme == "https") {
    uri = uri.replace(scheme: "wss");
  } else {
    uri = uri.replace(scheme: "ws");
  }

  print("Hot reloading enabled");
  _reloader = HotReloader(vmServiceUrl: uri.toString());
  _reloader.addPath("bin/hot_reload/");
  await _reloader.go();
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

  await File("bin/hot_reload/reloaded.dart").writeAsString(fileCode, mode: FileMode.writeOnly);
  await _reloader.reload();

  return execute(context);
}