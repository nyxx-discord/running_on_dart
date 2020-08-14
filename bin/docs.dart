import "dart:convert" show jsonDecode;
import "dart:io" show File;

List<dynamic> _indexJson = jsonDecode(File("docs/index.json").readAsStringSync()) as List<dynamic>;
String get basePath => "https://nyxx.l7ssha.xyz/";

class DocDefinition {
  late final String name;

  late final String absoluteUrl;

  late final String type;

  DocDefinition(Map<String, dynamic> element) {
    if (element["enclosedBy"] != null && element["enclosedBy"]["type"] == "class") {
      this.name = "${element['enclosedBy']['name']}#${element['name']}";
    } else {
      this.name = element["name"] as String;
    }

    this.type = element["type"] as String;

    final libPath = element["href"].split("/").first;
    this.absoluteUrl ="$basePath$libPath/${element['href']}";
  }
}

Future<DocDefinition?> getDocDefinition(String className, [String? fieldName]) async {
  Map<String, dynamic>? searchResult;

  if (fieldName == null) {
    searchResult = _indexJson.firstWhere((element) => (element["name"] as String).endsWith(className)) as Map<String, dynamic>?;
  } else {
    searchResult = _indexJson.firstWhere((element) => (element["qualifiedName"] as String).endsWith("$className.$fieldName")) as Map<String, dynamic>?;
  }

  if(searchResult == null) {
    return null;
  }

  return DocDefinition(searchResult);
}

Iterable<DocDefinition> searchDocs(String query) sync* {
  final searchResults = _indexJson.where((element) => (element["name"] as String).toLowerCase().contains(query.toLowerCase())).take(10);

  for (final element in searchResults){
    yield DocDefinition(element as Map<String, dynamic>);
  }
}