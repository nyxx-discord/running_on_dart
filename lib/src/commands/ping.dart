import 'package:http/http.dart' as http;
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:running_on_dart/src/util.dart';

ChatCommand ping = ChatCommand(
  'ping',
  'Checks if the bot is online',
  id('ping', (IChatContext context) async {
    final color = getRandomColor();

    // Get Gateway latency
    final gatewayLatency = (context.client as INyxxWebsocket).shardManager.gatewayLatency.inMilliseconds;

    // Get REST API latency
    final restLatencyTimer = Stopwatch()..start();
    await http.head(Uri(
      scheme: 'https',
      host: Constants.host,
      path: Constants.baseUri,
    ));
    final restLatency = (restLatencyTimer..stop()).elapsedMilliseconds;

    final embed = EmbedBuilder()
      ..color = color
      ..addField(name: 'Gateway latency', content: '${gatewayLatency}ms', inline: true)
      ..addField(name: 'REST latency', content: '${restLatency}ms', inline: true)
      ..addField(name: 'Message round-trip', content: 'Pending...', inline: true);

    // Get round-trip time
    final roundTripTimer = Stopwatch()..start();
    final response = await context.respond(MessageBuilder.embed(embed));
    final roundTrip = (roundTripTimer..stop()).elapsedMilliseconds;

    embed.replaceField(name: 'Message round-trip', content: '${roundTrip}ms', inline: true);

    await response.edit(MessageBuilder.embed(embed));
  }),
);
