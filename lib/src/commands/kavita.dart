import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_extensions/nyxx_extensions.dart';
import 'package:running_on_dart/src/models/kavita.dart';
import 'package:running_on_dart/src/modules/kavita.dart';
import 'package:running_on_dart/src/util/kavita.dart';
import 'package:running_on_dart/src/util/util.dart';

Future<AuthenticatedKavitaClient> getKavitaClient(KavitaUserConfig? config, ChatContext context) async {
  config ??= await Injector.appInstance
      .get<KavitaModule>()
      .fetchGetUserConfigWithFallback(userId: context.user.id, parentId: getParentIdFromContext(context));

  if (config == null) {
    throw Exception("Invalid jellyfin config or user not logged in.");
  }
  return Injector.appInstance.get<KavitaModule>().createAuthenticatedClient(config);
}

final kavita = ChatGroup('kavita', 'Kavita related commands', children: [
  ChatGroup(
    'user',
    'User related kavita commands',
    children: [
      ChatCommand(
        "login",
        "Login user into given kavita instance",
        id('kavita-user-login', (InteractionChatContext context, KavitaConfig config) async {
          final kavitaModule = Injector.appInstance.get<KavitaModule>();

          final modalResult = await context.getModal(title: "Login to Kavita", components: [
            TextInputBuilder(customId: 'username', style: TextInputStyle.short, label: 'Username', isRequired: true),
            TextInputBuilder(customId: 'password', style: TextInputStyle.short, label: 'Password', isRequired: true),
          ]);

          final apiLoginResult = await kavitaModule
              .createUnauthenticatedClient(config)
              .login(modalResult['username']!, modalResult['password']!);

          await kavitaModule.login(config, apiLoginResult, context.user.id);

          return context.respond(MessageBuilder(content: "Logged in successfully!"));
        }),
      )
    ],
  ),
  ChatCommand(
      'search',
      'Search kavita library',
      id('kavita-test', (ChatContext context, String query, [KavitaUserConfig? config]) async {
        final client = await getKavitaClient(config, context);

        final items = await client.searchSeries(query);
        final paginator = await pagination.builders(await getSearchEmbedPages(items, client).toList());

        return context.respond(paginator);
      })),
  ChatCommand(
    'read',
    'Read series',
    id('kavita-read', (ChatContext context, int seriesId,
        [bool saveReadProgress = true, KavitaUserConfig? config]) async {
      final client = await getKavitaClient(config, context);

      final continuePoint = await client.getContinuePoint(seriesId);
      final paginator = await pagination.factories(
          await generateReadingPaginationFactories(continuePoint, client, seriesId, saveReadProgress).toList(),
          startIndex: continuePoint.pagesRead,
          userId: context.user.id);

      return context.respond(paginator);
    }),
  ),
]);
