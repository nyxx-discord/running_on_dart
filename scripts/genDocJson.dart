import "dart:convert" show jsonDecode, jsonEncode;
import "dart:io" show File, FileMode;

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

  File("docfiles/nyxxdocs.json")..writeAsStringSync(newFileStuff, mode: FileMode.writeOnly);
}
