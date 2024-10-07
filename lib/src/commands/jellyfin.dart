import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_extensions/nyxx_extensions.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/checks.dart';
import 'package:running_on_dart/src/models/jellyfin_config.dart';
import 'package:running_on_dart/src/repository/jellyfin_config.dart';
import 'package:running_on_dart/src/util/jellyfin.dart';
import 'package:tentacle/tentacle.dart';

final jellyfin = ChatGroup(
  "jellyfin",
  "Jellyfin Testing Commands",
  checks: [
    jellyfinFeatureEnabledCheck,
  ],
  children: [
    ChatGroup(
        "tasks",
        "Run tasks on Jellyfin instance",
        children: [
          ChatCommand(
            "run",
            "Run given task",
            id('jellyfin-tasks-run', (InteractionChatContext context, [@Description("Instance to use. Default selected if not provided") @UseConverter(jellyfinConfigConverter) JellyfinConfig? config]) async {
              final client = await JellyfinModule.instance.getClient((config?.name, context.guild!.id));
              if (client == null) {
                return context.respond(MessageBuilder(content: "Invalid Jellyfin instance"));
              }

              final selectMenuResult = await context.getSelection(
                await client.getScheduledTasks(),
                MessageBuilder(content: 'Choose task to run!'),
                toSelectMenuOption: (taskInfo) {
                  final label = taskInfo.state != TaskState.idle
                    ? "${taskInfo.name} [${taskInfo.state}]"
                    : taskInfo.name.toString();

                  final description = (taskInfo.description?.length ?? 0) >= 100
                    ? "${taskInfo.description?.substring(0, 97)}..."
                    : taskInfo.description;

                  return SelectMenuOptionBuilder(label: label, value: taskInfo.id!, description: description);
                },
                authorOnly: true
              );

              return context.interaction.updateOriginalResponse(MessageUpdateBuilder(content: "Running `${selectMenuResult.name!}`...", components: []));
            }),
          ),
        ]
    ),
    ChatGroup(
      "user",
      "Jellyfin user related commands",
      children: [
        ChatCommand(
          "allow-registration",
          "Allows user to register into jellyfin instance",
          id('jellyfin-user-allow-registration',
              (ChatContext context, @Description("User to allow registration to") User user,
                  [@Description("Allowed libraries for user. Comma separated") String? allowedLibraries,
                  @Description("Instance to use. Default selected if not provided")
                  @UseConverter(jellyfinConfigConverter)
                  JellyfinConfig? config]) async {
            final client =
                await JellyfinModule.instance.getClient((config?.name, context.guild!.id));
            if (client == null) {
              return context.respond(MessageBuilder(content: "Invalid Jellyfin instance"));
            }

            final allowedLibrariesList =
                allowedLibraries != null ? allowedLibraries.split(',').map((str) => str.trim()).toList() : <String>[];

            JellyfinModule.instance.addUserToAllowedForRegistration(client.name, user.id, allowedLibrariesList);

            return context.respond(MessageBuilder(
                content: '${user.mention} can now create new jellyfin account using `/jellyfin user register`'));
          }),
          checks: [
            jellyfinFeatureAdminCommandCheck,
          ],
        ),
        ChatCommand(
            "register",
            "Allows to self register to jellyfin instance. Given administrator allowed action",
            id('jellyfin-user-register', (InteractionChatContext context,
                [@Description("Instance to use. Default selected if not provided")
                @UseConverter(jellyfinConfigConverter)
                JellyfinConfig? config]) async {
              final client =
                  await JellyfinModule.instance.getClient((config?.name, context.guild!.id));
              if (client == null) {
                return context.respond(MessageBuilder(content: "Invalid Jellyfin instance"));
              }

              final (isAllowed, allowedLibraries) =
                  JellyfinModule.instance.isUserAllowedForRegistration(client.name, context.user.id);
              if (!isAllowed) {
                return context.respond(MessageBuilder(
                    content:
                        'You have not been allowed to create new account on this jellyfin instance. Ask jellyfin administrator for permission.'));
              }

              final modal = await context.getModal(title: "New user Form", components: [
                TextInputBuilder(
                    style: TextInputStyle.short,
                    customId: 'username',
                    label: 'User name',
                    minLength: 4,
                    isRequired: true),
                TextInputBuilder(
                    style: TextInputStyle.short,
                    customId: 'password',
                    label: 'Password',
                    minLength: 8,
                    isRequired: true),
              ]);

              final user =
                  await client.createUser(modal['username']!, modal['password']!, allowedLibraries: allowedLibraries);
              if (user == null) {
                return context.respond(MessageBuilder(content: 'Cannot create an user. Contact administrator'));
              }

              return context
                  .respond(MessageBuilder(content: 'User created successfully. Login here: ${client.basePath}'));
            }),
            options: CommandOptions(defaultResponseLevel: ResponseLevel.private),
            checks: [
              jellyfinFeatureUserCommandCheck,
            ]),
      ],
    ),
    ChatCommand(
        "search",
        "Search instance for content",
        id('jellyfin-search', (ChatContext context, @Description("Term to search jellyfin for") String searchTerm,
            [@Description("Include episodes when searching") bool includeEpisodes = false,
            @Description("Query limit") int limit = 15,
            @Description("Instance to use. Default selected if not provided")
            @UseConverter(jellyfinConfigConverter)
            JellyfinConfig? config]) async {
          final client =
              await JellyfinModule.instance.getClient((config?.name, context.guild!.id));
          if (client == null) {
            return context.respond(MessageBuilder(content: "Invalid Jellyfin instance"));
          }

          final resultsWithoutEpisodes =
              await client.searchItems(searchTerm, includeEpisodes: includeEpisodes, limit: limit);
          final results = [
            ...resultsWithoutEpisodes,
            if (resultsWithoutEpisodes.length < 4)
              ...await client.searchItems(searchTerm,
                  limit: limit - resultsWithoutEpisodes.length,
                  includeEpisodes: true,
                  includeMovies: false,
                  includeSeries: false),
          ];

          final paginator = await pagination.builders(await buildMediaInfoBuilders(results, client).toList());
          return context.respond(paginator);
        }),
        checks: [
          jellyfinFeatureUserCommandCheck,
        ]),
    ChatCommand(
        "current-sessions",
        "Displays current sessions",
        id("jellyfin-current-sessions", (ChatContext context,
            [@Description("Instance to use. Default selected if not provided")
            @UseConverter(jellyfinConfigConverter)
            JellyfinConfig? config]) async {
          final client =
              await JellyfinModule.instance.getClient((config?.name, context.guild!.id));
          if (client == null) {
            return context.respond(MessageBuilder(content: "Invalid Jellyfin instance"));
          }

          final currentSessions = await client.getCurrentSessions();
          if (currentSessions.isEmpty) {
            return context.respond(MessageBuilder(content: "No one watching currently"));
          }

          final embeds = currentSessions.map((sessionInfo) => buildSessionEmbed(sessionInfo, client)).nonNulls.toList();
          context.respond(MessageBuilder(embeds: embeds));
        }),
        checks: [
          jellyfinFeatureUserCommandCheck,
        ]),
    ChatCommand(
        'add-instance',
        "Add new instance to config",
        id("jellyfin-new-instance", (InteractionChatContext context) async {
          final modalResponse = await context.getModal(title: "New Instance Configuration", components: [
            TextInputBuilder(customId: "name", style: TextInputStyle.short, label: "Instance Name"),
            TextInputBuilder(customId: "base_url", style: TextInputStyle.short, label: "Base Url"),
            TextInputBuilder(customId: "api_token", style: TextInputStyle.short, label: "API Token"),
            TextInputBuilder(customId: "is_default", style: TextInputStyle.short, label: "Is Default (True/False)"),
          ]);

          final config = await JellyfinModule.instance.createJellyfinConfig(
            modalResponse['name']!,
            modalResponse['base_url']!,
            modalResponse['api_token']!,
            modalResponse['is_default']?.toLowerCase() == 'true',
            modalResponse.guild?.id ?? modalResponse.user.id,
          );

          modalResponse.respond(MessageBuilder(content: "Added new jellyfin instance with name: ${config.name}"));
        }),
        checks: [
          jellyfinFeatureCreateInstanceCommandCheck,
        ]),
    ChatCommand(
        "transfer-config",
        "Transfers jellyfin instance config to another guild",
        id("jellyfin-transfer-config", (
          ChatContext context,
          @Description("Name of instance") @UseConverter(jellyfinConfigConverter) JellyfinConfig config,
          @Description("Guild or user id to copy to") Snowflake targetParentId, [
          @Description("Copy default flag?") bool copyDefaultFlag = false,
          @Description("New name for config. Copied from original if not provided") String? configName,
        ]) async {
          final newConfig = await JellyfinConfigRepository.instance.createJellyfinConfig(configName ?? config.name,
              config.basePath, config.token, copyDefaultFlag && config.isDefault, targetParentId);

          context.respond(
              MessageBuilder(content: 'Copied config: "${newConfig.name}" to parent: "${newConfig.parentId}"'));
        }),
        checks: [
          jellyfinFeatureAdminCommandCheck,
        ]),
    ChatCommand(
        "remove-config",
        "Removes config from current guild",
        id("jellyfin-remove-config", (ChatContext context,
            @Description("Name of instance") @UseConverter(jellyfinConfigConverter) JellyfinConfig config) async {
          await JellyfinModule.instance.deleteJellyfinConfig(config);

          context.respond(MessageBuilder(content: 'Delete config with name: "${config.name}"'));
        }),
        checks: [
          jellyfinFeatureAdminCommandCheck,
        ]
    ),
  ],
);
