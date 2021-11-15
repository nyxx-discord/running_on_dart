import 'package:prometheus_client/prometheus_client.dart';
import 'package:prometheus_client/runtime_metrics.dart' as runtime_metrics;
import 'package:prometheus_client_shelf/shelf_metrics.dart' as shelf_metrics;
import 'package:prometheus_client_shelf/shelf_handler.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

late final Counter slashCommandsTotalUsageMetric;

Future<void> registerPrometheus() async {
  runtime_metrics.register();

  slashCommandsTotalUsageMetric = Counter(
    name: 'slash_commands_total_usage',
    help: 'The total amount of used slash commands',
    labelNames: ['name']
  )..register();

  final router = Router()
      ..get('/metrics', prometheusHandler());

  var handler = const shelf.Pipeline()
      .addMiddleware(shelf_metrics.register())
      .addHandler(router);

  var server = await io.serve(handler, '0.0.0.0', 8080);
  print('Serving at http://${server.address.host}:${server.port}');
}
