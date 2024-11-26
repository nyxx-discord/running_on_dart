import 'dart:async';
import 'dart:io';

import 'package:mustachex/mustachex.dart';
import 'package:running_on_dart/src/settings.dart';
import 'package:running_on_dart/src/web_app/api_server.dart';
import 'package:running_on_dart/src/web_app/utils.dart';
import 'package:shelf/shelf.dart' as shelf;

FutureOr<String> _mustachePartialResolver(MissingPartialException missingPartial) {
  final file = File("$webServerTemplatesDirectory/component/${missingPartial.partialName}.html");
  if (!file.existsSync()) {
    throw missingPartial;
  }

  return file.readAsStringSync();
}

class MustacheResponse extends shelf.Response {
  final String name;
  final Map<String, dynamic>? parameters;

  MustacheResponse({required this.name, this.parameters}) : super(200);

  Future<shelf.Response> process() async {
    final processor = MustachexProcessor(initialVariables: {
      ...?parameters,
      'clientId': clientId,
      'redirectUri': clientRedirectUri,
      'server_alert_content': webServerAlertContent,
    }, partialsResolver: _mustachePartialResolver);

    final templateData = await File("$webServerTemplatesDirectory/$name").readAsString();

    return shelf.Response(statusCode,
        body: await processor.process(templateData), headers: {"Content-Type": 'text/html'});
  }
}

shelf.Middleware processMustache({void Function(String message, bool isError)? logger}) => (innerHandler) {
      return (request) {
        return Future.sync(() => innerHandler(request)).then((response) {
          if (response is MustacheResponse) {
            response.parameters?.addAll(getCustomDataFromSession(request));

            return response.process();
          }

          return response;
        });
      };
    };
