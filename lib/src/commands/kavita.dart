import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_extensions/nyxx_extensions.dart';
import 'package:running_on_dart/src/checks.dart';
import 'package:running_on_dart/src/models/kavita.dart';
import 'package:running_on_dart/src/modules/kavita.dart';
import 'package:running_on_dart/src/repository/kavita.dart';
import 'package:running_on_dart/src/util/kavita.dart';
import 'package:running_on_dart/src/util/util.dart';

Future<AuthenticatedKavitaClient> getKavitaClient(KavitaUserConfig? config, ChatContext context) async {
  config ??= await Injector.appInstance.get<KavitaModule>().fetchGetUserConfigWithFallback(
        userId: context.user.id,
        parentId: getParentIdFromContext(context),
      );

  if (config == null) {
    throw Exception("Invalid kavita config or user not logged in."); // Todo: handle properly
  }

  return Injector.appInstance.get<KavitaModule>().createAuthenticatedClient(config);
}

final kavita = ChatGroup(
  'kavita',
  'Kavita related commands',
  checks: [kavitaJellyfinCheck],
  children: [
    ChatGroup(
      'settings',
      'Settings for Kavita',
      children: [
        ChatCommand(
          'add-instance',
          'Add new kavita instance',
          id('kavita-settings-add-instance', (InteractionChatContext context) async {
            final modalResponse = await context.getModal(
              title: "New Instance Configuration",
              components: [
                TextInputBuilder(
                  customId: "name",
                  style: TextInputStyle.short,
                  label: "Instance Name",
                  isRequired: true,
                ),
                TextInputBuilder(
                  customId: "base_url",
                  style: TextInputStyle.short,
                  label: "Base Url",
                  isRequired: true,
                ),
                TextInputBuilder(customId: "is_default", style: TextInputStyle.short, label: "Is Default (True/False)"),
              ],
            );

            final newlyCreatedConfig = await Injector.appInstance.get<KavitaRepository>().saveConfig(
                  KavitaConfig(
                    name: modalResponse['name']!,
                    basePath: modalResponse['base_url']!,
                    isDefault: modalResponse['is_default']?.toLowerCase() == 'true',
                    parentId: getParentIdFromContext(context),
                  ),
                );

            modalResponse.respond(
              MessageBuilder(content: "Added new jellyfin instance with name: ${newlyCreatedConfig.name}"),
            );
          }),
          checks: [kavitaFeatureCreateInstanceCommandCheck],
        ),
      ],
    ),
    ChatGroup(
      'user',
      'User related kavita commands',
      children: [
        ChatCommand(
          "login",
          "Login user into given kavita instance",
          id('kavita-user-login', (
            InteractionChatContext context,
            @Description('Kavita instance to be used') KavitaConfig config,
          ) async {
            final kavitaModule = Injector.appInstance.get<KavitaModule>();

            final modalResult = await context.getModal(
              title: "Login to Kavita",
              components: [
                TextInputBuilder(
                  customId: 'username',
                  style: TextInputStyle.short,
                  label: 'Username',
                  isRequired: true,
                ),
                TextInputBuilder(
                  customId: 'password',
                  style: TextInputStyle.short,
                  label: 'Password',
                  isRequired: true,
                ),
              ],
            );

            final apiLoginResult = await kavitaModule
                .createUnauthenticatedClient(config)
                .login(modalResult['username']!, modalResult['password']!);

            await kavitaModule.login(config, apiLoginResult, context.user.id);

            return context.respond(MessageBuilder(content: "Logged in successfully!"));
          }),
        ),
      ],
    ),
    ChatCommand(
      'search',
      'Search kavita library',
      id('kavita-test', (
        ChatContext context,
        @Description('Query string to search content with') String query, [
        @Description('Kavita instance to be used. Default if not provided') KavitaUserConfig? config,
      ]) async {
        final client = await getKavitaClient(config, context);

        final items = await client.searchSeries(query);
        final paginator = await pagination.builders(await getSearchEmbedPages(items, client).toList());

        return context.respond(paginator);
      }),
    ),
    ChatCommand(
      'read',
      'Read series',
      id('kavita-read', (
        ChatContext context,
        int seriesId, [
        @Description('Whether save reading progress to kavita') bool saveReadProgress = true,
        @Description('Kavita instance to be used. Default if not provided') KavitaUserConfig? config,
      ]) async {
        final client = await getKavitaClient(config, context);

        final continuePoint = await client.getContinuePoint(seriesId);
        if (continuePoint.isBook) {
          return context.respond(MessageBuilder(content: "Books are not currently supported."));
        }

        final paginator = await pagination.factories(
          await generateReadingPaginationFactories(continuePoint, client, seriesId, saveReadProgress).toList(),
          startIndex: continuePoint.pagesRead,
          userId: context.user.id,
        );

        return context.respond(paginator);
      }),
    ),
  ],
);
