import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:running_on_dart/src/util/util.dart';
import 'package:http/http.dart' as http;

extension ReplaceEmbedFieldExtension on EmbedBuilder {
  void replaceField(EmbedFieldBuilder embedField) {
    final index = fields!.indexWhere((element) => element.name == embedField.name);

    fields![index] = embedField;
  }
}

int calculateGatewayLatencyInMilliseconds(NyxxGateway client) {
  return client.gateway.shards.fold(0, (value, shard) => shard.latency.inMilliseconds) ~/ client.gateway.shards.length;
}

Future<int> calculateRestApiLatencyInMilliseconds(NyxxGateway client) async {
  final restLatencyTimer = Stopwatch()..start();
  await http.head(Uri(
    scheme: 'https',
    host: client.apiOptions.host,
    path: client.apiOptions.baseUri,
  ));
  return (restLatencyTimer..stop()).elapsedMilliseconds;
}

final ping = ChatCommand(
  'ping',
  'Checks if the bot is online',
  id('ping', (ChatContext context) async {
    final gatewayLatency = calculateGatewayLatencyInMilliseconds(context.client);
    final restLatency = await calculateRestApiLatencyInMilliseconds(context.client);

    final embed = EmbedBuilder(color: getRandomColor(), fields: [
      EmbedFieldBuilder(name: 'Gateway latency', value: '${gatewayLatency}ms', isInline: true),
      EmbedFieldBuilder(name: 'REST latency', value: '${restLatency}ms', isInline: true),
      EmbedFieldBuilder(name: 'Message round-trip', value: 'Pending...', isInline: true),
    ]);

    // Get round-trip time
    final roundTripTimer = Stopwatch()..start();
    final response = await context.respond(MessageBuilder(embeds: [embed]));
    final roundTrip = (roundTripTimer..stop()).elapsedMilliseconds;

    embed.replaceField(EmbedFieldBuilder(name: 'Message round-trip', value: '${roundTrip}ms', isInline: true));

    await response.edit(MessageUpdateBuilder(embeds: [embed]));
  }),
);
