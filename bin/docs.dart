//import 'dart:io';

import "dart:io";

import "package:html/parser.dart" as html_parser;
import "package:http/http.dart" as http;

String get baseUrl =>
    Platform.environment["ROD_NYXX_DOCS_PATH"]
        ?? "https://pub.dev/documentation/nyxx/latest/nyxx/";

Future<String> getUrlToProperty(String className, String? fieldName) async {
  final url = "$baseUrl$className-class.html";

  if (fieldName == null) {
    return url;
  }

  final httpContent = await http.read(url);
  final document = html_parser.parse(httpContent);
  final features = document.querySelectorAll("span.name > a");
  final foundRelativeUrl = features.firstWhere((element) => element.innerHtml == fieldName).attributes["href"];

  return Uri.parse(baseUrl + foundRelativeUrl!).toString();
}

Future<Map<String, String>> searchDocs(String query) async {
  final httpContent = await http.read("${baseUrl}nyxx-library.html");
  final document = html_parser.parse(httpContent);
  final elements = document.querySelectorAll("span.name > a").where((element) => element.innerHtml.toLowerCase().contains(query.toLowerCase())).take(8);

  return <String, String>{
    for(final element in elements)
      element.innerHtml: Uri.parse(baseUrl + element.attributes["href"]!).toString()
  };
}