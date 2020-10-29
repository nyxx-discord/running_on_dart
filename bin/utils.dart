import "dart:io" show Platform;

String? get envPrefix => Platform.environment["ROD_PREFIX"];
String? get envHotReload => Platform.environment["ROD_HOT_RELOAD"];
String? get envToken => Platform.environment["ROD_TOKEN"];
String? get envAdminId => Platform.environment["ROD_ADMIN_ID"];

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
