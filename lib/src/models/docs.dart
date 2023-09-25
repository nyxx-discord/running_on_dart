import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

final Logger _logger = Logger('ROD.Packages');

/// Documentation for an entire package.
class PackageDocs {
  /// The name of the package.
  final String packageName;

  /// The entries into this package's documentation, mapped by qualified name.
  Map<String, DocEntry> entries = {};

  /// All the elements in this package's documentation
  Iterable<DocEntry> get elements => entries.values;

  /// The short name of the elements in this package's documentation entries.
  Iterable<String> get elementNames => elements.map((e) => e.name);

  /// The URL to this package's documentation index on [pub.dev](https://pub.dev).
  String get urlToDocs =>
      'https://pub.dev/documentation/$packageName/latest/index.json';

  /// Create a new [PackageDocs] for a given package.
  PackageDocs({
    required this.packageName,
  });

  /// Update this package's local data from [urlToDocs].
  Future<void> update() async {
    _logger.fine('Updating docs for package "$packageName"');

    final response = await http.get(Uri.parse(urlToDocs));

    if (response.statusCode != 200) {
      _logger.shout(
          'Unable to update docs for package "$packageName": Error ${response.statusCode}');
      return;
    }

    try {
      final data = (jsonDecode(response.body) as List<dynamic>)
          .cast<Map<String, dynamic>>();

      entries = {};

      for (final dataEntry in data) {
        if (dataEntry['__PACKAGE_ORDER__'] != null) {
          continue;
        }

        final entry = DocEntry.fromJson(dataEntry);

        entries[entry.qualifiedName] = entry;
      }
    } on FormatException {
      _logger.shout(
          'Unable to update docs for package "$packageName": Malformed JSON in response');
    }
  }
}

/// An entry into a package's documentation.
class DocEntry {
  /// The short name of the element.
  final String name;

  /// The name that should be displayed to the user when interacting with this element.
  ///
  /// This is generally a combination of [name] and the enclosing element.
  final String displayName;

  /// The qualified name of the element.
  final String qualifiedName;

  final String packageName;

  /// The type of this entry.
  final String type;

  /// The URL to this element's documentation.
  final String urlToDocs;

  /// Create a new [DocEntry] for a given element.
  const DocEntry({
    required this.name,
    required this.qualifiedName,
    required this.displayName,
    required this.packageName,
    required this.type,
    required this.urlToDocs,
  });

  /// Create a [DocEntry] from a documentation entry object received from a dartdoc `index.json` file.
  factory DocEntry.fromJson(Map<String, dynamic> json) {
    String displayName;
    String type;

    switch (json['kind'] as int) {
      case 1:
      case 16:
      case 10:
        displayName = '${json['enclosedBy']['name'] as String}.${json['name'] as String}';
        break;
      case 9:
        displayName =
            '${json['packageName'] != json['name'] ? '${json['packageName'] as String}.' : ''}${json['name'] as String}';
        break;
      case 2:
        displayName =
            '${json['name'] == json['enclosedBy']['name'] ? '(new) ' : ''}${json['name'] as String}';
        break;
      default:
        displayName = json['name'] as String? ?? '';
        break;
    }

    switch (json['kind'] as int) {
      case 1:
      case 18:
        type = 'constant';
        break;
      case 16:
        type = 'property';
        break;
      case 10:
        type = 'method';
        break;
      case 9:
        type = 'library';
        break;
      case 2:
        type = 'constructor';
        break;
      case 3:
        type = 'class';
        break;
      default:
        type = '';
        break;
    }

    return DocEntry(
      name: json['name'] as String,
      displayName: displayName,
      qualifiedName: json['qualifiedName'] as String,
      packageName: json['packageName'] as String,
      type: type,
      urlToDocs:
          'https://pub.dev/documentation/${json['packageName'] as String}/latest/${json['href'] as String}',
    );
  }
}
