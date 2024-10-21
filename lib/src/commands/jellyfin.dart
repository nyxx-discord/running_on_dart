import 'dart:async';

import 'package:collection/collection.dart';
import 'package:injector/injector.dart';
import 'package:intl/intl.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_extensions/nyxx_extensions.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/checks.dart';
import 'package:running_on_dart/src/external/wizarr.dart';
import 'package:running_on_dart/src/models/jellyfin_config.dart';
import 'package:running_on_dart/src/util/jellyfin.dart';
import 'package:running_on_dart/src/util/pipelines.dart';
import 'package:running_on_dart/src/util/util.dart';
import 'package:tentacle/tentacle.dart';

final taskProgressFormat = NumberFormat("0.00");

String? valueOrNullIfNotDefault(String? value, [String ifNotDefault = 'Unlimited']) {
  if (value == ifNotDefault) {
    return null;
  }

  return valueOrNull(value);
}

Future<AuthenticatedJellyfinClient> getJellyfinClient(JellyfinConfigUser? config, ChatContext context) async {
  config ??= await Injector.appInstance
      .get<JellyfinModuleV2>()
      .fetchGetUserConfigWithFallback(userId: context.user.id, parentId: context.guild?.id ?? context.user.id);

  if (config == null) {
    throw JellyfinConfigNotFoundException("Invalid jellyfin config or user not logged in.");
  }
  return Injector.appInstance.get<JellyfinModuleV2>().createJellyfinClientAuthenticated(config);
}

Future<void> ensureAdminJellyfinUser(AuthenticatedJellyfinClient jellyfinClient) async {
  final currentUser = await jellyfinClient.getCurrentUser();

  final isAdministrator = currentUser.policy?.isAdministrator ?? false;
  if (!isAdministrator) {
    throw JellyfinAdminUserRequired();
  }
}

final jellyfin = ChatGroup("jellyfin", "Jellyfin Testing Commands", checks: [
  jellyfinFeatureEnabledCheck,
], children: [
  ChatGroup("wizarr", "Wizarr related commands", children: [
    ChatCommand(
      "redeem-invitation",
      "Redeem invitation code",
      id("jellyfin-wizarr-redeem-invitation", (InteractionChatContext context, String code,
          [@Description("Instance to use. Default selected if not provided") JellyfinConfig? config]) async {
        final client = await Injector.appInstance
            .get<JellyfinModuleV2>()
            .fetchGetWizarrClientWithFallback(originalConfig: config, parentId: context.guild?.id ?? context.user.id);

        return await context.respond(
            getWizarrRedeemInvitationMessageBuilder(
                client, code, context.user.id, context.guild?.id ?? context.user.id, client.configName),
            level: ResponseLevel.private);
      }),
    ),
    ChatCommand(
      "create-invitation",
      "Create wizarr invitation",
      id("jellyfin-wizarr-create-invitation", (InteractionChatContext context,
          [@Description('Inform user about invitation') User? user,
          @Description("Instance to use. Default selected if not provided") JellyfinConfigUser? config]) async {
        final jellyfinClient = await getJellyfinClient(config, context);

        await ensureAdminJellyfinUser(jellyfinClient);

        final wizarrClient = await Injector.appInstance.get<JellyfinModuleV2>().fetchGetWizarrClientWithFallback(
            originalConfig: jellyfinClient.configUser.config!, parentId: context.guild?.id ?? context.user.id);

        final librariesMap = Map.fromEntries(
            (await wizarrClient.getAvailableLibraries()).map((library) => MapEntry(library.name, library.id)));

        final firstModal = await context.getModal(title: "Create Wizarr invitation", components: [
          TextInputBuilder(
              customId: "code",
              style: TextInputStyle.short,
              label: "Invitation Code (6 characters)",
              isRequired: true,
              value: generateRandomString(6)),
          TextInputBuilder(
              customId: "expiration",
              style: TextInputStyle.short,
              label: "Invitation expiration (or Unlimited)",
              isRequired: true,
              value: '1 Day'),
          TextInputBuilder(
              customId: "unlimited_usage",
              style: TextInputStyle.short,
              label: "Allow unlimited usages (True/False)",
              isRequired: true,
              value: 'False'),
        ]);

        final message = await context.respond(
            MessageBuilder(content: "Click to open second modal and continue", components: [
              ActionRowBuilder(components: [
                ButtonBuilder.primary(
                    customId: ComponentId.generate(allowedUser: context.user.id).toString(), label: 'Open modal')
              ])
            ]),
            level: ResponseLevel.private);
        await context.getButtonPress(message);

        final secondModal = await context.getModal(title: 'Create Wizarr invitation', components: [
          TextInputBuilder(
              customId: "simultaneous_logins_max_number",
              style: TextInputStyle.short,
              label: "Maximum Number of Simultaneous Logins",
              isRequired: true,
              value: 'Unlimited'),
          TextInputBuilder(
              customId: "account_duration",
              style: TextInputStyle.short,
              label: "User Account Duration",
              isRequired: true,
              value: 'Unlimited'),
        ]);

        final librariesSelection = await context.getMultiSelection(
            librariesMap.entries.map((entry) => entry.key).toList(),
            MessageBuilder(content: 'Select wanted libraries to finish code creation'),
            level: ResponseLevel.private,
            authorOnly: true);

        final accountDuration =
            getDurationFromStringOrDefault(valueOrNullIfNotDefault(secondModal['account_duration']), Duration(days: 1));
        final expiresDuration = getDurationFromStringOrDefault(valueOrNullIfNotDefault(firstModal['expiration']), null);
        final code = firstModal['code']!;

        final createInvitationRequest = CreateInvitationRequest(
          code: code,
          expires: accountDuration,
          duration: expiresDuration,
          specificLibraries: librariesSelection.map((libraryName) => librariesMap[libraryName]).nonNulls.toList(),
          unlimited: firstModal['unlimited_usage']?.toLowerCase() == 'true',
          sessions: int.tryParse(secondModal['simultaneous_logins_max_number']!) ?? 0,
        );

        final result = await wizarrClient.createInvitation(createInvitationRequest);

        if (result) {
          var messageToUserSent = '';
          if (user != null) {
            messageToUserSent = ' Message to user ${user.mention} sent.';

            (await user.manager.createDm(user.id)).sendMessage(getWizarrRedeemInvitationMessageBuilder(
              wizarrClient,
              code,
              user.id,
              context.guild?.id ?? context.user.id,
              wizarrClient.configName,
            ));
          }

          return context.respond(
              MessageBuilder(
                  content: 'Invitation with code: `${createInvitationRequest.code}` created.$messageToUserSent'),
              level: ResponseLevel.private);
        }

        return context.respond(MessageBuilder(content: 'Cannot create invitation. Contact administrator.'),
            level: ResponseLevel.private);
      }),
    ),
  ]),
  ChatGroup("sonarr", "Sonarr related commands", children: [
    ChatCommand(
      "calendar",
      "Show upcoming episodes",
      id("jellyfin-sonarr-calendar", (ChatContext context,
          [@Description("Instance to use. Default selected if not provided") JellyfinConfigUser? config]) async {
        final client = await Injector.appInstance.get<JellyfinModuleV2>().fetchGetSonarrClientWithFallback(
            originalConfig: config?.config, parentId: context.guild?.id ?? context.user.id);

        final calendarItems = await client.fetchCalendar(end: DateTime.now().add(Duration(days: 7)));
        final embeds = getSonarrCalendarEmbeds(calendarItems);

        final paginator = await pagination.builders(spliceEmbedsForMessageBuilders(embeds).toList());
        context.respond(paginator);
      }),
    ),
  ]),
  ChatGroup(
    "user",
    "Jellyfin user related commands",
    children: [
      // ChatCommand(
      //   "allow-registration",
      //   "Allows user to register into jellyfin instance",
      //   id('jellyfin-user-allow-registration',
      //       (ChatContext context, @Description("User to allow registration to") User user,
      //           [@Description("Allowed libraries for user. Comma separated") String? allowedLibraries,
      //           @Description("Instance to use. Default selected if not provided")
      //           @UseConverter(jellyfinConfigConverter)
      //           JellyfinConfig? config]) async {
      //     final client =
      //         await Injector.appInstance.get<JellyfinModule>().getClient((config?.name, context.guild!.id));
      //     if (client == null) {
      //       return context.respond(MessageBuilder(content: "Invalid Jellyfin instance"));
      //     }
      //
      //     final allowedLibrariesList =
      //         allowedLibraries != null ? allowedLibraries.split(',').map((str) => str.trim()).toList() : <String>[];
      //
      //     Injector.appInstance
      //         .get<JellyfinModule>()
      //         .addUserToAllowedForRegistration(client.name, user.id, allowedLibrariesList);
      //
      //     return context.respond(MessageBuilder(
      //         content: '${user.mention} can now create new jellyfin account using `/jellyfin user register`'));
      //   }),
      //   checks: [
      //     jellyfinFeatureAdminCommandCheck,
      //   ],
      // ),
      // ChatCommand(
      //     "register",
      //     "Allows to self register to jellyfin instance. Given administrator allowed action",
      //     id('jellyfin-user-register', (InteractionChatContext context,
      //         [@Description("Instance to use. Default selected if not provided")
      //         @UseConverter(jellyfinConfigConverter)
      //         JellyfinConfig? config]) async {
      //       final client =
      //           await Injector.appInstance.get<JellyfinModule>().getClient((config?.name, context.guild!.id));
      //       if (client == null) {
      //         return context.respond(MessageBuilder(content: "Invalid Jellyfin instance"));
      //       }
      //
      //       final (isAllowed, allowedLibraries) =
      //           Injector.appInstance.get<JellyfinModule>().isUserAllowedForRegistration(client.name, context.user.id);
      //       if (!isAllowed) {
      //         return context.respond(MessageBuilder(
      //             content:
      //                 'You have not been allowed to create new account on this jellyfin instance. Ask jellyfin administrator for permission.'));
      //       }
      //
      //       final modal = await context.getModal(title: "New user Form", components: [
      //         TextInputBuilder(
      //             style: TextInputStyle.short,
      //             customId: 'username',
      //             label: 'User name',
      //             minLength: 4,
      //             isRequired: true),
      //         TextInputBuilder(
      //             style: TextInputStyle.short,
      //             customId: 'password',
      //             label: 'Password',
      //             minLength: 8,
      //             isRequired: true),
      //       ]);
      //
      //       final user =
      //           await client.createUser(modal['username']!, modal['password']!, allowedLibraries: allowedLibraries);
      //       if (user == null) {
      //         return context.respond(MessageBuilder(content: 'Cannot create an user. Contact administrator'));
      //       }
      //
      //       return context
      //           .respond(MessageBuilder(content: 'User created successfully. Login here: ${client.basePath}'));
      //     }),
      //     options: CommandOptions(defaultResponseLevel: ResponseLevel.private),
      //     checks: [
      //       jellyfinFeatureUserCommandCheck,
      //     ]),
      ChatCommand(
        "login",
        "Login with password to given jellyfin instance",
        id("jellyfin-user-login", (InteractionChatContext context, JellyfinConfig config) async {
          return context.respond(
              getJellyfinLoginMessage(userId: context.user.id, configName: config.name, parentId: config.parentId),
              level: ResponseLevel.private);
        }),
      ),
      ChatCommand(
        "current-user",
        "Display info about current jellyfin user",
        id('jellyfin-user-current-user', (ChatContext context,
            [@Description("Instance to use. Default selected if not provided") JellyfinConfigUser? config]) async {
          final client = await getJellyfinClient(config, context);

          final currentUser = await client.getCurrentUser();
          context.respond(MessageBuilder(embeds: [getUserInfoEmbed(currentUser, client)]));
        }),
      ),
    ],
  ),
  ChatCommand(
    "search",
    "Search instance for content",
    id('jellyfin-search', (ChatContext context, @Description("Term to search jellyfin for") String searchTerm,
        [@Description("Include episodes when searching") bool includeEpisodes = false,
        @Description("Query limit") int limit = 15,
        @Description("Instance to use. Default selected if not provided") JellyfinConfigUser? config]) async {
      final client = await getJellyfinClient(config, context);

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
  ),
  ChatCommand(
    "current-sessions",
    "Displays current sessions",
    id("jellyfin-current-sessions", (ChatContext context,
        [@Description("Instance to use. Default selected if not provided") JellyfinConfigUser? config]) async {
      final client = await getJellyfinClient(config, context);

      final currentSessions = await client.getCurrentSessions();
      if (currentSessions.isEmpty) {
        return context.respond(MessageBuilder(content: "No one watching currently"));
      }

      final embeds = currentSessions.map((sessionInfo) => buildSessionEmbed(sessionInfo, client)).nonNulls.toList();
      context.respond(MessageBuilder(embeds: embeds));
    }),
  ),
  ChatGroup("settings", "Settings for jellyfin", children: [
    ChatCommand(
        'add-instance',
        "Add new jellyfin instance",
        id("jellyfin-settings-new-instance", (InteractionChatContext context) async {
          final modalResponse = await context.getModal(title: "New Instance Configuration", components: [
            TextInputBuilder(customId: "name", style: TextInputStyle.short, label: "Instance Name", isRequired: true),
            TextInputBuilder(customId: "base_url", style: TextInputStyle.short, label: "Base Url", isRequired: true),
            TextInputBuilder(customId: "is_default", style: TextInputStyle.short, label: "Is Default (True/False)"),
          ]);

          final message = await context.respond(
              MessageBuilder(content: "Click to open second modal", components: [
                ActionRowBuilder(components: [
                  ButtonBuilder.primary(
                      customId: ComponentId.generate(allowedUser: context.user.id).toString(), label: 'Open modal')
                ])
              ]),
              level: ResponseLevel.private);
          await context.getButtonPress(message);

          final secondModalResponse = await context.getModal(title: "New Instance Configuration Pt. 2", components: [
            TextInputBuilder(customId: "sonarr_base_url", style: TextInputStyle.short, label: "Sonarr base url"),
            TextInputBuilder(customId: "sonarr_token", style: TextInputStyle.short, label: "Sonarr Token"),
            TextInputBuilder(customId: "wizarr_base_url", style: TextInputStyle.short, label: "Wizarr base url"),
            TextInputBuilder(customId: "wizarr_token", style: TextInputStyle.short, label: "Wizarr Token"),
          ]);

          final config = JellyfinConfig(
            name: modalResponse['name']!,
            basePath: modalResponse['base_url']!,
            isDefault: modalResponse['is_default']?.toLowerCase() == 'true',
            parentId: modalResponse.guild?.id ?? modalResponse.user.id,
            sonarrBasePath: valueOrNull(secondModalResponse['sonarr_base_url']),
            sonarrToken: valueOrNull(secondModalResponse['sonarr_token']),
            wizarrBasePath: valueOrNull(secondModalResponse['wizarr_base_url']),
            wizarrToken: valueOrNull(secondModalResponse['wizarr_token']),
          );

          final newlyCreatedConfig = await Injector.appInstance.get<JellyfinModuleV2>().createJellyfinConfig(config);

          modalResponse
              .respond(MessageBuilder(content: "Added new jellyfin instance with name: ${newlyCreatedConfig.name}"));
        }),
        checks: [
          jellyfinFeatureCreateInstanceCommandCheck,
        ]),
    ChatCommand(
        "edit-instance",
        "Edit jellyfin instance",
        id('jellyfin-settings-edit-instance', (InteractionChatContext context,
            @Description("Instance to use. Default selected if not provided") JellyfinConfig config) async {
          final modalResponse = await context.getModal(title: "Jellyfin Instance Edit Pt. 1", components: [
            TextInputBuilder(
                customId: "base_url",
                style: TextInputStyle.short,
                label: "Base Url",
                isRequired: true,
                value: config.basePath),
          ]);

          final message = await context.respond(
              MessageBuilder(content: "Click to open second modal", components: [
                ActionRowBuilder(components: [
                  ButtonBuilder.primary(
                      customId: ComponentId.generate(allowedUser: context.user.id).toString(), label: 'Open modal')
                ])
              ]),
              level: ResponseLevel.private);
          await context.getButtonPress(message);

          final secondModalResponse = await context.getModal(title: "Jellyfin Instance Edit Pt. 2", components: [
            TextInputBuilder(
              customId: "sonarr_base_url",
              style: TextInputStyle.short,
              label: "Sonarr base url",
              value: config.sonarrBasePath,
              isRequired: false,
            ),
            TextInputBuilder(
                customId: "sonarr_token",
                style: TextInputStyle.short,
                label: "Sonarr Token",
                value: config.sonarrToken,
                isRequired: false),
            TextInputBuilder(
                customId: "wizarr_base_url",
                style: TextInputStyle.short,
                label: "Wizarr base url",
                value: config.wizarrBasePath,
                isRequired: false),
            TextInputBuilder(
                customId: "wizarr_token",
                style: TextInputStyle.short,
                label: "Wizarr Token",
                value: config.wizarrToken,
                isRequired: false),
          ]);

          final editedConfig = JellyfinConfig(
            name: config.name,
            basePath: modalResponse['base_url']!,
            isDefault: config.isDefault,
            parentId: config.parentId,
            sonarrBasePath: valueOrNull(secondModalResponse['sonarr_base_url']),
            sonarrToken: valueOrNull(secondModalResponse['sonarr_token']),
            wizarrBasePath: valueOrNull(secondModalResponse['wizarr_base_url']),
            wizarrToken: valueOrNull(secondModalResponse['wizarr_token']),
            id: config.id,
          );

          Injector.appInstance.get<JellyfinModuleV2>().updateJellyfinConfig(editedConfig);

          return modalResponse.respond(MessageBuilder(content: 'Successfully updated jellyfin config'));
        }),
        checks: [
          jellyfinFeatureCreateInstanceCommandCheck,
        ]),
    //   ChatCommand(
    //       "transfer-config",
    //       "Transfers jellyfin instance config to another guild",
    //       id("jellyfin-settings-transfer-config", (
    //         ChatContext context,
    //         @Description("Name of instance") @UseConverter(jellyfinConfigConverter) JellyfinConfig config,
    //         @Description("Guild or user id to copy to") Snowflake targetParentId, [
    //         @Description("Copy default flag?") bool copyDefaultFlag = false,
    //         @Description("New name for config. Copied from original if not provided") String? configName,
    //       ]) async {
    //         final newConfig =
    //             await Injector.appInstance.get<JellyfinConfigRepository>().createJellyfinConfig(JellyfinConfig(
    //                   name: configName ?? config.name,
    //                   basePath: config.basePath,
    //                   token: config.token,
    //                   isDefault: copyDefaultFlag && config.isDefault,
    //                   parentId: targetParentId,
    //                   sonarrBasePath: config.sonarrBasePath,
    //                   sonarrToken: config.sonarrToken,
    //                   wizarrBasePath: config.wizarrBasePath,
    //                   wizarrToken: config.wizarrToken,
    //                 ));
    //
    //         context.respond(
    //             MessageBuilder(content: 'Copied config: "${newConfig.name}" to parent: "${newConfig.parentId}"'));
    //       }),
    //       checks: [
    //         jellyfinFeatureAdminCommandCheck,
    //       ]),
    //   ChatCommand(
    //       "remove-config",
    //       "Removes config from current guild",
    //       id("jellyfin-settings-remove-config", (ChatContext context,
    //           @Description("Name of instance") @UseConverter(jellyfinConfigConverter) JellyfinConfig config) async {
    //         await Injector.appInstance.get<JellyfinModule>().deleteJellyfinConfig(config);
    //
    //         context.respond(MessageBuilder(content: 'Delete config with name: "${config.name}"'));
    //       }),
    //       checks: [
    //         jellyfinFeatureAdminCommandCheck,
    //       ]),
  ]),
  ChatGroup("util", "Util commands for jellyfin", children: [
    ChatCommand(
      "complete-refresh",
      "Do a complete refresh of jellyfin instance content",
      id("jellyfin-util-complete-refresh", (ChatContext context,
          [@Description("Instance to use. Default selected if not provided") JellyfinConfigUser? config]) async {
        final client = await getJellyfinClient(config, context);

        await ensureAdminJellyfinUser(client);

        final availableTasks = await client.getScheduledTasks();
        final scanMediaLibraryTask = availableTasks.firstWhere((task) => task.key == 'RefreshLibrary');
        final subtitleExtractTask = availableTasks.firstWhereOrNull((task) => task.key == 'ExtractSubtitles');

        Pipeline(
          name: 'Complete Library Refresh',
          description: "",
          tasks: [
            Task(
                runCallback: () => client.startTask(scanMediaLibraryTask.id!),
                updateCallback: () async {
                  final scheduledTask = (await client.getScheduledTasks())
                      .firstWhereOrNull((taskInfo) => taskInfo.id == scanMediaLibraryTask.id);
                  if (scheduledTask == null || scheduledTask.state == TaskState.idle) {
                    return (true, null);
                  }

                  return (
                    false,
                    "Running `${scheduledTask.name!}` - ${taskProgressFormat.format(scheduledTask.currentProgressPercentage!)}%"
                  );
                }),
            if (subtitleExtractTask != null)
              Task(
                  runCallback: () => client.startTask(subtitleExtractTask.id!),
                  updateCallback: () async {
                    final scheduledTask = (await client.getScheduledTasks())
                        .firstWhereOrNull((taskInfo) => taskInfo.id == subtitleExtractTask.id);
                    if (scheduledTask == null || scheduledTask.state == TaskState.idle) {
                      return (true, null);
                    }

                    return (
                      false,
                      "Running `${scheduledTask.name!}` - ${taskProgressFormat.format(scheduledTask.currentProgressPercentage!)}%"
                    );
                  })
          ],
          updateInterval: Duration(seconds: 2),
        ).forCreateContext(messageSupplier: (messageBuilder) => context.respond(messageBuilder)).execute();
      }),
    ),
    ChatCommand(
      "run",
      "Run given task",
      id('jellyfin-tasks-run', (InteractionChatContext context,
          [@Description("Instance to use. Default selected if not provided") JellyfinConfigUser? config]) async {
        final client = await getJellyfinClient(config, context);

        final selectMenuResult = await context
            .getSelection(await client.getScheduledTasks(), MessageBuilder(content: 'Choose task to run!'),
                toSelectMenuOption: (taskInfo) {
          final label =
              taskInfo.state != TaskState.idle ? "${taskInfo.name} [${taskInfo.state}]" : taskInfo.name.toString();

          final description = (taskInfo.description?.length ?? 0) >= 100
              ? "${taskInfo.description?.substring(0, 97)}..."
              : taskInfo.description;

          return SelectMenuOptionBuilder(label: label, value: taskInfo.id!, description: description);
        }, authorOnly: true);

        Pipeline(
          name: selectMenuResult.name!,
          description: "",
          tasks: [
            Task(
                runCallback: () => client.startTask(selectMenuResult.id!),
                updateCallback: () async {
                  final scheduledTask = (await client.getScheduledTasks())
                      .firstWhereOrNull((taskInfo) => taskInfo.id == selectMenuResult.id);
                  if (scheduledTask == null || scheduledTask.state == TaskState.idle) {
                    return (true, null);
                  }

                  return (
                    false,
                    "Running `${scheduledTask.name!}` - ${taskProgressFormat.format(scheduledTask.currentProgressPercentage!)}%"
                  );
                }),
          ],
          updateInterval: Duration(seconds: 2),
        )
            .forUpdateContext(
                messageSupplier: (messageBuilder) => context.interaction.updateOriginalResponse(messageBuilder))
            .execute();
      }),
    ),
  ]),
]);
