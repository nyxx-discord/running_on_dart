import 'package:logging/logging.dart';
import "package:nyxx/nyxx.dart";
import "package:nyxx_commander/nyxx_commander.dart";
import "package:nyxx_interactions/nyxx_interactions.dart";

import "package:running_on_dart/running_on_dart.dart" as rod;

late INyxxWebsocket botInstance;

void main(List<String> arguments) async {
  if (rod.debug) {
    Logger.root.level = Level.ALL;
  }

  await rod.openDbAndRunMigrations();
  await rod.registerPrometheus();

  botInstance = NyxxFactory.createNyxxWebsocket(rod.botToken, rod.setIntents,
      options: ClientOptions(guildSubscriptions: false, messageCacheSize: 10), cacheOptions: rod.cacheOptions)
    ..eventsWs.onGuildMemberAdd.listen((event) async {
      await rod.joinLogJoinEvent(event);
      await rod.nicknamePoopJoinEvent(event);
    })
    ..eventsWs.onGuildMemberUpdate.listen((event) async {
      await rod.nicknamePoopUpdateEvent(event);
    });

  ICommander.create(botInstance, rod.prefixHandler)
    ..registerCommandGroup(CommandGroup(beforeHandler: rod.adminBeforeHandler)
      ..registerSubCommand("leave", rod.leaveChannelCommand)
      ..registerSubCommand("join", rod.joinChannelCommand))
    // Docs commands
    ..registerCommandGroup(CommandGroup(name: "docs")
      ..registerDefaultCommand(rod.docsCommand)
      ..registerSubCommand("get", rod.docsGetCommand)
      ..registerSubCommand("search", rod.docsSearchCommand))
    // Minor commands
    ..registerCommand("info", rod.infoCommand)
    ..registerCommand("remind", rod.reminderCommand);

  IInteractions.create(WebsocketInteractionBackend(botInstance))
    ..registerSlashCommand(SlashCommandBuilder("info", "Info about bot state", [])..registerHandler(rod.infoSlashCommand))
    ..registerSlashCommand(SlashCommandBuilder("tag", "Show and manipulate tags", [
      CommandOptionBuilder(CommandOptionType.subCommand, "show", "Shows tag to everyone", options: [
        CommandOptionBuilder(CommandOptionType.string, "name", "Name of tag to show", required: true, autoComplete: true)
          ..registerAutocompleteHandler(rod.tagsSearchAutocompleteHandler)
      ])
        ..registerHandler((event) => rod.showTagHandler(event, ephemeral: false)),
      CommandOptionBuilder(CommandOptionType.subCommand, "preview", "Shows tag only for yourself", options: [
        CommandOptionBuilder(CommandOptionType.string, "name", "Name of tag to show", required: true, autoComplete: true)
          ..registerAutocompleteHandler(rod.tagsSearchAutocompleteHandler)
      ])
        ..registerHandler((event) => rod.showTagHandler(event, ephemeral: true)),
      CommandOptionBuilder(CommandOptionType.subCommand, "create", "Creates new tag", options: [
        CommandOptionBuilder(CommandOptionType.string, "name", "Name of tag", required: true),
        CommandOptionBuilder(CommandOptionType.string, "content", "Content of the tag", required: true)
      ])
        ..registerHandler(rod.createTagHandler),
      CommandOptionBuilder(CommandOptionType.subCommand, "delete", "Deletes tag", options: [
        CommandOptionBuilder(CommandOptionType.string, "name", "Name of tag", required: true, autoComplete: true)
          ..registerAutocompleteHandler(rod.tagsSearchForUserAutocompleteHandler)
      ])
        ..registerHandler(rod.deleteTagHandler),
      CommandOptionBuilder(CommandOptionType.subCommand, "stats", "Tag stats", options: [])..registerHandler(rod.tagStatsHandler),
      CommandOptionBuilder(CommandOptionType.subCommand, "search", "Allows to search tags",
          options: [CommandOptionBuilder(CommandOptionType.string, "query", "Query to search tags with", required: true)])
        ..registerHandler(rod.tagSearchHandler),
      CommandOptionBuilder(CommandOptionType.subCommand, "edit", "Allows editing existing tag", options: [
        CommandOptionBuilder(CommandOptionType.string, "name", "Name of tag", required: true, autoComplete: true)
          ..registerAutocompleteHandler(rod.tagsSearchForUserAutocompleteHandler),
        CommandOptionBuilder(CommandOptionType.string, "content", "Content of the tag", required: true)
      ])
        ..registerHandler(rod.tagEditHandler),
    ]))
    ..registerSlashCommand(
        SlashCommandBuilder("avatar", "Shows avatar of the user", [CommandOptionBuilder(CommandOptionType.user, "user", "User to display avatar")])
          ..registerHandler(rod.avatarSlashHandler))
    ..registerSlashCommand(SlashCommandBuilder("ping", "Shows bots latency", [])..registerHandler(rod.pingSlashHandler))
    ..registerSlashCommand(SlashCommandBuilder("docs", "Documentation for nyxx", [
      CommandOptionBuilder(CommandOptionType.subCommand, "get", "Fetches docs for given phrase", options: [
        CommandOptionBuilder(CommandOptionType.string, "phrase", "Phrase to fetch from docs", required: true, autoComplete: true)
          ..registerAutocompleteHandler(rod.docsSearchAutocompleteHandler)
      ])
        ..registerHandler(rod.docsGetSlashHandler),
      CommandOptionBuilder(CommandOptionType.subCommand, "search", "Searches docs for wanted phrase",
          options: [CommandOptionBuilder(CommandOptionType.string, "phrase", "Phrase to fetch from docs", required: true)])
        ..registerHandler(rod.docsSearchHandler),
      CommandOptionBuilder(CommandOptionType.subCommand, "links", "Returns links to docs")..registerHandler(rod.docsLinksHandler)
    ]))
    ..registerSlashCommand(SlashCommandBuilder("voice", "Voice related commands", [
      CommandOptionBuilder(CommandOptionType.subCommand, "join", "Joins voice channel",
          options: [CommandOptionBuilder(CommandOptionType.channel, "channel", "Channel where bot is going to join", required: true)])
        ..registerHandler(rod.joinVoiceHandler),
      CommandOptionBuilder(CommandOptionType.subCommand, "leave", "Leaves voice channel")..registerHandler(rod.leaveVoiceHandler),
    ]))
    ..registerSlashCommand(SlashCommandBuilder("settings", "Manages settings of guild", [
      CommandOptionBuilder(CommandOptionType.subCommand, "enable", "Allows to enable features in a guild", options: [
        CommandOptionBuilder(CommandOptionType.string, "name", "Name of feature to enable", choices: rod.getFeaturesAsChoices().toList(), required: true),
        CommandOptionBuilder(CommandOptionType.string, "data", "Additional data for feature")
      ])
        ..registerHandler(rod.enableFeatureSlash),
      CommandOptionBuilder(CommandOptionType.subCommand, "disable", "Disables feature in guild",
          options: [CommandOptionBuilder(CommandOptionType.string, "name", "Name of option to disable", required: true)])
        ..registerHandler(rod.disableFeatureSlash),
      CommandOptionBuilder(CommandOptionType.subCommand, "list", "Lists features enabled in guild")..registerHandler(rod.listFeaturesSlash),
    ]))
    ..registerSlashCommand(SlashCommandBuilder("reminder", "Manages reminders", [
      CommandOptionBuilder(CommandOptionType.subCommand, "create", "Creates reminder in current channel", options: [
        CommandOptionBuilder(CommandOptionType.string, "trigger-at", "When reminder should go on", required: true),
        CommandOptionBuilder(CommandOptionType.string, "message", "Additional message", required: true),
      ])
        ..registerHandler(rod.reminderAddSlash),
      CommandOptionBuilder(CommandOptionType.subCommand, "list", "List your current remainders")..registerHandler(rod.reminderGetUsers),
      CommandOptionBuilder(CommandOptionType.subCommand, "clear", "Clears all your remainders")..registerHandler(rod.remindersClear),
      CommandOptionBuilder(CommandOptionType.subCommand, "remove", "Remove single remainder",
          options: [CommandOptionBuilder(CommandOptionType.integer, "id", "Id of remainder to delete")])
        ..registerHandler(rod.reminderRemove)
    ]))
    ..syncOnReady(syncRule: ManualCommandSync(sync: rod.syncCommands))
    ..events.onSlashCommand.listen((event) => rod.slashCommandsTotalUsageMetric.labels([event.interaction.name]).inc());

  await rod.initReminderModule(botInstance);
}
