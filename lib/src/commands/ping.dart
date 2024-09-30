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

final ping = ChatCommand(
  'ping',
  'Checks if the bot is online',
  id('ping', (ChatContext context) async {
    final gatewayLatency = context.client.gateway.latency;
    final restLatency = context.client.httpHandler.latency;

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
