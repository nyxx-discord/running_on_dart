import "dart:convert" show Utf8Decoder, jsonDecode;
import "dart:io" show File, HttpClient;

late DateTime lastDocUpdate;
DateTime lastDocUpdateTimer = DateTime(2005);

List<dynamic> _indexJson = jsonDecode(File("docfiles/nyxxdocs.json").readAsStringSync()) as List<dynamic>;
String get basePath => "https://nyxx.l7ssha.xyz/";
Uri get docUpdatePath => Uri.parse("https://api.github.com/repos/nyxx-discord/nyxx/actions/runs?status=success&per_page=1&page=1");

class DocDefinition {
  /// Name of documentation element
  late final String name;

  /// Absolute url to documentation element
  late final String absoluteUrl;

  /// Type of documentation element
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

Future<DateTime> fetchLastDocUpdate() async {
  if (lastDocUpdateTimer.difference(DateTime.now()).inMinutes.abs() > 15) {
    final request = await HttpClient()
        .getUrl(docUpdatePath);

    final response = await request.close();
    final body = await response.transform(const Utf8Decoder()).join();
    final jsonBody = jsonDecode(body);

    final result = DateTime.parse(
        jsonBody["workflow_runs"][0]["updated_at"] as String
    );

    lastDocUpdateTimer = DateTime.now();
    lastDocUpdate = result;
  }

  return lastDocUpdate;
}
