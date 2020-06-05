import "dart:io";

String get dartVersion {
  final platformVersion = Platform.version;
  return platformVersion.split("(").first;
}