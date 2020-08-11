//import 'dart:io';

import "dart:io" show File, Platform;

import "package:html/dom.dart" show Document;
import "package:html/parser.dart" as html_parser;
import "package:http/http.dart" as http;

bool get _isLocalFileSystem => Platform.environment["ROD_NYXX_DOCS_PATH"] != null;

String get baseUrl =>
    Platform.environment["ROD_NYXX_DOCS_PATH"]
        ?? "https://pub.dev/documentation/nyxx/latest/nyxx/";

Future<Document> _readDocumentFromUrl(String url) async {
  final fileContentsFuture = _isLocalFileSystem ? File(url).readAsString() : http.read(url);
  return html_parser.parse(await fileContentsFuture);
}

Future<String> getUrlToProperty(String className, String? fieldName) async {
  final url = "$baseUrl$className-class.html";

  if (fieldName == null) {
    return url;
  }

  final document = await _readDocumentFromUrl(url);

  final features = document.querySelectorAll("span.name > a");
  final foundRelativeUrl = features.firstWhere((element) => element.innerHtml == fieldName).attributes["href"];

  return Uri.parse(baseUrl + foundRelativeUrl!).toString();
}

Future<Map<String, String>> searchDocs(String query) async {
  final url = "${baseUrl}nyxx-library.html";

  final document = await _readDocumentFromUrl(url);
  final elements = document.querySelectorAll("span.name > a").where((element) => element.innerHtml.toLowerCase().contains(query.toLowerCase())).take(8);

  return <String, String>{
    for(final element in elements)
      element.innerHtml: Uri.parse(baseUrl + element.attributes["href"]!).toString()
  };
}