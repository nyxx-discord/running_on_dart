import 'dart:async';
import "dart:convert" show jsonDecode;

import "package:http/http.dart" as http;

const docUrls = [
  "https://pub.dev/documentation/nyxx/latest/index.json",
  "https://pub.dev/documentation/nyxx_interactions/latest/index.jsoni",
  "https://pub.dev/documentation/nyxx_commander/latest/index.json",
  "https://pub.dev/documentation/nyxx_lavalink/latest/index.json",
  "https://pub.dev/documentation/nyxx_extensions/latest/index.json",
];

late DateTime lastDocUpdate;
DateTime lastDocUpdateTimer = DateTime(2005);
Uri get docUpdatePath => Uri.parse("https://api.github.com/repos/nyxx-discord/nyxx/actions/runs?status=success&per_page=1&page=1");

Future<SearchResult?> _findInDocs(bool Function(dynamic) predicate) async {
  for (final path in docUrls) {
    final response = await http.get(Uri.parse(path));

    if (response.statusCode >= 400) {
      continue;
    }

    final payload = jsonDecode(response.body) as List<dynamic>;

    try {
      return SearchResult(payload.firstWhere(predicate), path);
    } on StateError {}
  }

  return null;
}

Future<List<SearchResult>> _whereInDocs(int count, bool Function(dynamic) predicate) async {
  final resultingList = <SearchResult>[];

  for (final path in docUrls) {
    final response = await http.get(Uri.parse(path));
    if (response.statusCode >= 300) {
      return [];
    }

    final payload = jsonDecode(response.body) as List<dynamic>;
    resultingList.addAll(payload.where(predicate).take(count).map((e) => SearchResult(e, path)));

    if (resultingList.length >= count) {
      return resultingList;
    }
  }

  return [];
}

Future<DocDefinition?> getDocDefinition(String className, [String? fieldName]) async {
  SearchResult? searchResult;

  if (fieldName == null) {
    searchResult = await _findInDocs((element) => (element["name"] as String).endsWith(className));
  } else {
    searchResult = await _findInDocs((element) => (element["qualifiedName"] as String).endsWith("$className.$fieldName"));
  }

  if (searchResult == null) {
    return null;
  }

  return DocDefinition(searchResult);
}

Stream<DocDefinition> searchDocs(String query) async* {
  final searchResults = await _whereInDocs(10, (element) => (element["name"] as String).toLowerCase().contains(query.toLowerCase()));

  for (final element in searchResults) {
    yield DocDefinition(element);
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

class SearchResult {
  late final Map<String, dynamic> data;
  final String path;

  String get basePath => path.replaceFirst("index.json", "");

  SearchResult(dynamic result, this.path) {
    data = result as Map<String, dynamic>;
  }
}

class DocDefinition {
  /// Name of documentation element
  late final String name;

  /// Absolute url to documentation element
  late final String absoluteUrl;

  /// Type of documentation element
  late final String type;

  DocDefinition(SearchResult result) {
    if (result.data["enclosedBy"] != null && result.data["enclosedBy"]["type"] == "class") {
      name = "${result.data['enclosedBy']['name']}#${result.data['name']}";
    } else {
      name = result.data["name"] as String;
    }

    type = result.data["type"] as String;

    final libPath = result.data["href"].split("/").first;
    absoluteUrl = "${result.basePath}$libPath/${result.data['href']}";
  }
}
