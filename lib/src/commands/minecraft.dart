import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_extensions/nyxx_extensions.dart';
import 'package:running_on_dart/src/modules/minecraft.dart';

final minecraft = ChatGroup(
  "minecraft",
  "Minecraft related servers",
  children: [
    ChatCommand(
      "ping",
      "Queries minecraft server",
      id("minecraft-ping", (ChatContext context, @Description('Minecraft server uri') String serverUri) async {
        final packet = await pingServer(serverUri);

        if (packet == null) {
          return context.respond(MessageBuilder(content: 'Cannot query server: `$serverUri`.'));
        }

        final result = packet.response;
        if (result == null) {
          return context.respond(MessageBuilder(content: 'Cannot obtain data for server: `$serverUri`.'));
        }

        final embed = EmbedBuilder(
          title: 'Minecraft server: `$serverUri`',
          description: result.description.description,
          thumbnail: EmbedThumbnailBuilder(url: Uri.parse('attachment://server_favicon.png')),
          fields: [
            EmbedFieldBuilder(name: 'Version', value: result.version.name, isInline: true),
            EmbedFieldBuilder(name: 'Ping', value: '${packet.ping ?? -1} ms', isInline: true),
            EmbedFieldBuilder(
              name: 'Player stats',
              value: '${result.players.online}/${result.players.max}',
              isInline: true,
            ),
          ],
          footer: EmbedFooterBuilder(text: 'Generated at: ${formatDate(DateTime.now())}'),
        );

        return context.respond(
          MessageBuilder(
            embeds: [embed],
            attachments: [AttachmentBuilder(data: result.getImageBytes, fileName: 'server_favicon.png')],
          ),
        );
      }),
    ),
  ],
);
