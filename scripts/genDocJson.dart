import "dart:convert";
import "dart:io";

void main() {
  final nyxxDocs = jsonDecode(File("../nyxx/nyxx/doc/api/index.json").readAsStringSync()) as List<dynamic>;
  final commanderDocs = jsonDecode(File("../nyxx/nyxx.commander/doc/api/index.json").readAsStringSync()) as List<dynamic>;
  final extensionsDocs = jsonDecode(File("../nyxx/nyxx.extensions/doc/api/index.json").readAsStringSync()) as List<dynamic>;

  print(jsonEncode(commanderDocs));

  final newFileStuff = jsonEncode([
        ...nyxxDocs,
        ...commanderDocs,
        ...extensionsDocs
  ]);

  File("docs/index.json")..writeAsStringSync(newFileStuff, mode: FileMode.writeOnly);
}