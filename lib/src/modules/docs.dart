import "dart:convert" show jsonDecode;

import "package:http/http.dart" as http;

const docUrls = [
  "https://nyxx.l7ssha.xyz/dartdocs/nyxx/index.json",
  "https://nyxx.l7ssha.xyz/dartdocs/nyxx_interactions/index.json",
  "https://nyxx.l7ssha.xyz/dartdocs/nyxx_commander/index.json",
  "https://nyxx.l7ssha.xyz/dartdocs/nyxx_lavalink/index.json",
  "https://nyxx.l7ssha.xyz/dartdocs/nyxx_extensions/index.json",
];

late DateTime lastDocUpdate;
DateTime lastDocUpdateTimer = DateTime(2005);

String get basePath => "https://nyxx.l7ssha.xyz/dartdocs/";
Uri get docUpdatePath => Uri.parse("https://api.github.com/repos/nyxx-discord/nyxx/actions/runs?status=success&per_page=1&page=1");

Future<dynamic> _findInDocs(bool predicate(dynamic)) async {
  for (final path in docUrls) {
    final payload = jsonDecode((await http.get(Uri.parse(path))).body) as List<dynamic>;

    try {
      return payload.firstWhere(predicate);
    } on StateError {}
  }

  return null;
}

Future<List<dynamic>> _whereInDocs(int count, bool predicate(dynamic)) async {
  final resultingList = [];

  for (final path in docUrls) {
    final payload = jsonDecode((await http.get(Uri.parse(path))).body) as List<dynamic>;
    resultingList.addAll(payload.where(predicate).take(count));

    if (resultingList.length >= count) {
      return resultingList;
    }
  }

  return [];
}

Future<DocDefinition?> getDocDefinition(String className, [String? fieldName]) async {
  Map<String, dynamic>? searchResult;

  if (fieldName == null) {
    searchResult = await _findInDocs((element) => (element["name"] as String).endsWith(className)) as Map<String, dynamic>?;
  } else {
    searchResult = await _findInDocs((element) => (element["qualifiedName"] as String).endsWith("$className.$fieldName")) as Map<String, dynamic>?;
  }

  if (searchResult == null) {
    return null;
  }

  return DocDefinition(searchResult);
}

Stream<DocDefinition> searchDocs(String query) async* {
  final searchResults = await _whereInDocs(10, (element) => (element["name"] as String).toLowerCase().contains(query.toLowerCase()));

  for (final element in searchResults) {
    yield DocDefinition(element as Map<String, dynamic>);
  }
}

Future<DateTime> fetchLastDocUpdate() async {
  if (lastDocUpdateTimer.difference(DateTime.now()).inMinutes.abs() > 15) {
    final jsonBody = jsonDecode((await http.get(docUpdatePath)).body);

    final result = DateTime.parse(jsonBody["workflow_runs"][0]["updated_at"] as String);

    lastDocUpdateTimer = DateTime.now();
    lastDocUpdate = result;
  }

  return lastDocUpdate;
}

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
    this.absoluteUrl = "$basePath$libPath/${element['href']}";
  }
}
