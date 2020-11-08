import "dart:convert" show utf8;
import "dart:io" show File, FileMode, Process;

String getFileContent(String code) =>
    """
      import "dart:convert";
      import "dart:io";
      import "dart:async";
      import "dart:collection";
      import "dart:isolate";
      import "dart:math";
      import "dart:typed_data";
    
      FutureOr<dynamic> exeCode() async {
        $code
      }
      
      main() async {
        print(await exeCode());
      }
    """;

/// Executes code not connected to main process, therefore doesnt have access to its data
Future<String> eval(String code) async {
  await File("/tmp/dart-eval.dart").writeAsString(getFileContent(code), mode: FileMode.writeOnly);
  final process = await Process.run("dart", ["/tmp/dart-eval.dart"], stderrEncoding: utf8);

  final stdout = process.stdout.toString();

  if (stdout.isNotEmpty) {
    return stdout;
  }

  return process.stderr.toString();
}
