import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

Future<void> cleanupSlashHandler(ISlashCommandInteractionEvent event) async {
  await event.acknowledge(hidden: true);

  if(event.interaction.memberAuthorPermissions != null && !event.interaction.memberAuthorPermissions!.connect) {
    return event.respond(MessageBuilder.content("You don't have permissions"));
  }

  final channel = event.interaction.channel.getFromCache();
  if (channel == null) {
    return event.respond(MessageBuilder.content('Channel missing from cache'));
  }

  final toTake = int.parse(event.getArg('count').value.toString());
  final channelLastMessages = await channel.downloadMessages(limit: toTake).toList();

  try {
    await channel.bulkRemoveMessages(channelLastMessages);
    return event.respond(MessageBuilder.content("Messages removed"), hidden: true);
  } on Error {
    return event.respond(MessageBuilder.content("Error removing messages"), hidden: true);
  }
}
