import 'dart:async';
import "dart:convert" show jsonDecode, jsonEncode;
import 'dart:io';

import "package:http/http.dart" as http;
import 'package:logging/logging.dart';

const docUrls = [
  "https://pub.dev/documentation/nyxx/latest/index.json",
  "https://pub.dev/documentation/nyxx_interactions/latest/index.json",
  "https://pub.dev/documentation/nyxx_commander/latest/index.json",
  "https://pub.dev/documentation/nyxx_lavalink/latest/index.json",
  "https://pub.dev/documentation/nyxx_extensions/latest/index.json",
];

late DateTime lastDocUpdate;
DateTime lastDocUpdateTimer = DateTime(2005);
Uri get docUpdatePath => Uri.parse("https://api.github.com/repos/nyxx-discord/nyxx/actions/runs?status=success&per_page=1&page=1");
final logger = Logger("ROD - docs");

void setupDocsUpdateJob() {
  logger.info("Starting docs cache updater job");

  Timer.periodic(const Duration(minutes: 1), (timer) async {
    final output = <dynamic>[];

    for (final url in docUrls) {
      final data = await http.get(Uri.parse(url));
      final decodedData = jsonDecode(data.body);

      output.addAll(decodedData as List<dynamic>);
    }

    output.sort((first, second) => (first['qualifiedName'] as String).compareTo(second['qualifiedName'] as String));

    await File("docs_cache.json").writeAsString(jsonEncode(output), mode: FileMode.write);

    logger.info("Update of docs cache successful");
  });
}

Stream<SearchResult> _whereInDocs(int count, bool Function(dynamic) predicate) async* {
  final rawFile = await File('docs_cache.json').readAsString();
  final docsData = jsonDecode(rawFile) as List<dynamic>;

  yield* Stream.fromIterable(docsData.where(predicate).take(count).map((e) => SearchResult(e)) as List<SearchResult>);
}

Future<DocDefinition?> getDocDefinition(String className, [String? fieldName]) async {
  try {
    SearchResult? searchResult;

    if (fieldName == null) {
      searchResult = await _whereInDocs(1, (element) => (element["name"] as String).endsWith(className)).first;
    } else {
      searchResult = await _whereInDocs(1, (element) => (element["qualifiedName"] as String).endsWith("$className.$fieldName")).first;
    }

    return DocDefinition(searchResult);
  } on StateError {
    return null;
  }
}

Stream<DocDefinition> searchDocs(String query) async* {
  final searchResults = _whereInDocs(10, (element) => (element["name"] as String).toLowerCase().contains(query.toLowerCase()));

  await for (final element in searchResults) {
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

  String get basePath => "https://pub.dev/documentation/${data['packageName']}/latest";

  SearchResult(dynamic result) {
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
