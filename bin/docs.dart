import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

const baseUrl = 'https://pub.dev/documentation/nyxx/latest/nyxx/';

Future<String> getUrlToProperty(String className, String? fieldName) async {
  final url = 'https://pub.dev/documentation/nyxx/latest/nyxx/$className-class.html';

  if (fieldName == null) {
    return url;
  }

  final httpContent = (await http.read(url));
  var document = html_parser.parse(httpContent);
  var features = document.querySelectorAll('span.name > a');
  final foundRelativeUrl = features.firstWhere((element) => element.innerHtml == fieldName).attributes['href'];

  return Uri.parse(baseUrl + foundRelativeUrl!).toString();
}