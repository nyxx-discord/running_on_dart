import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:running_on_dart/src/checks.dart';
import 'package:running_on_dart/src/models/feature_settings.dart';
import 'package:running_on_dart/src/modules/minecraft.dart';
import 'package:running_on_dart/src/modules/rcon.dart';
import 'package:running_on_dart/src/repository/feature_settings.dart';

final minecraft = ChatGroup(
  "minecraft",
  "Minecraft related servers",
  children: [
    ChatCommand(
      "ping",
      "Queries minecraft server",
      id("minecraft-ping", (
        ChatContext context, [
        @Description('Minecraft server uri (uses configured server if not provided)') String? serverUri,
      ]) async {
        String? targetUri = serverUri;

        // If no server URI provided, try to use the configured server
        if (targetUri == null && context.guild != null) {
          final setting = await Injector.appInstance.get<FeatureSettingsRepository>().fetchSetting(
            Setting.minecraft,
            context.guild!.id,
          );

          if (setting != null) {
            final data = setting.parseData<MinecraftData>();
            if (data != null) {
              targetUri = data.host;
            }
          }
        }

        if (targetUri == null) {
          return context.respond(
            MessageBuilder(content: 'No server URI provided and no Minecraft server configured for this guild.'),
          );
        }

        final packet = await pingServer(targetUri);

        if (packet == null) {
          return context.respond(MessageBuilder(content: 'Cannot query server: `$targetUri`.'));
        }

        final result = packet.response;
        if (result == null) {
          return context.respond(MessageBuilder(content: 'Cannot obtain data for server: `$targetUri`.'));
        }

        final embed = EmbedBuilder(
          title: 'Minecraft server: `$targetUri`',
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
        );

        return context.respond(
          MessageBuilder(
            embeds: [embed],
            attachments: [AttachmentBuilder(data: result.getImageBytes, fileName: 'server_favicon.png')],
          ),
        );
      }),
    ),
    ChatCommand(
      "info",
      "Get server details and players via RCON",
      checks: [minecraftFeatureEnabledCheck],
      id("minecraft-info", (ChatContext context) async {
        if (context.guild == null) {
          return context.respond(MessageBuilder(content: 'This command can only be used in a server.'));
        }

        final setting = await Injector.appInstance.get<FeatureSettingsRepository>().fetchSetting(
          Setting.minecraft,
          context.guild!.id,
        );

        if (setting == null) {
          return context.respond(MessageBuilder(content: 'Minecraft server is not configured for this guild.'));
        }

        final data = setting.parseData<MinecraftData>();
        if (data == null) {
          return context.respond(MessageBuilder(content: 'Minecraft server configuration is invalid.'));
        }

        try {
          final client = await connectToRcon(data.host, data.port, data.password);
          final info = await client.getServerInfo();
          await client.close();

          final embed = EmbedBuilder(
            title: 'Minecraft Server Info',
            color: DiscordColor.parseHexString("#00FF00"),
            fields: [
              EmbedFieldBuilder(name: 'Version', value: info.version, isInline: true),
              EmbedFieldBuilder(name: 'Players', value: '${info.players.length} online', isInline: true),
              if (info.players.isNotEmpty)
                EmbedFieldBuilder(name: 'Online Players', value: info.players.join(', '), isInline: false),
              EmbedFieldBuilder(name: 'Host', value: data.host, isInline: true),
              EmbedFieldBuilder(name: 'Port', value: data.port.toString(), isInline: true),
            ],
          );

          return context.respond(MessageBuilder(embeds: [embed]));
        } on RconException catch (e) {
          return context.respond(MessageBuilder(content: 'Failed to connect to RCON server: ${e.message}'));
        }
      }),
    ),
    ChatCommand(
      "rcon",
      "Execute RCON command on the server (admin only)",
      checks: [minecraftFeatureEnabledCheck],
      id("minecraft-rcon", (ChatContext context, @Description('Command to execute') String command) async {
        if (context.guild == null) {
          return context.respond(MessageBuilder(content: 'This command can only be used in a server.'));
        }

        final setting = await Injector.appInstance.get<FeatureSettingsRepository>().fetchSetting(
          Setting.minecraft,
          context.guild!.id,
        );

        if (setting == null) {
          return context.respond(MessageBuilder(content: 'Minecraft server is not configured for this guild.'));
        }

        final data = setting.parseData<MinecraftData>();
        if (data == null) {
          return context.respond(MessageBuilder(content: 'Minecraft server configuration is invalid.'));
        }

        if (!data.isAdmin(context.user.id)) {
          return context.respond(MessageBuilder(content: 'You do not have permission to execute RCON commands.'));
        }

        try {
          final client = await connectToRcon(data.host, data.port, data.password);
          final response = await client.sendCommand(command);
          await client.close();

          final truncatedResponse = response.length > 1900 ? '${response.substring(0, 1900)}...' : response;

          final embed = EmbedBuilder(
            title: 'RCON Command Executed',
            color: DiscordColor.parseHexString("#0000FF"),
            fields: [
              EmbedFieldBuilder(name: 'Command', value: '```$command```', isInline: false),
              EmbedFieldBuilder(name: 'Response', value: '```\n$truncatedResponse\n```', isInline: false),
            ],
          );

          return context.respond(MessageBuilder(embeds: [embed]));
        } on RconException catch (e) {
          return context.respond(MessageBuilder(content: 'Failed to execute RCON command: ${e.message}'));
        }
      }),
    ),
  ],
);
