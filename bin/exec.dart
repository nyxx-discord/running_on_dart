import "dart:convert" show utf8;
import "dart:io" show File, FileMode, Process;

/// Executes code not connected to main process, therefore doesnt have access to its data
Future<String> eval(String code) async {
  if (!code.contains("return")) {
    code = "return $code";
  }

  if (!code.endsWith(";")) {
    code = "$code;";
  }

  final fileCode = """
    dynamic exeCode() {
      $code
    }
    
    main() {
      print(exeCode());
    }
  """;

  await File("/tmp/dart-eval.dart").writeAsString(fileCode, mode: FileMode.writeOnly);
  final process = await Process.run("dart", ["/tmp/dart-eval.dart"], stderrEncoding: utf8);

  final stdout = process.stdout.toString();

  if (stdout.isNotEmpty) {
    return stdout;
  }

  return process.stderr.toString();
}
