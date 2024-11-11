import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:running_on_dart/src/models/kavita.dart';
import 'package:running_on_dart/src/modules/kavita.dart';
import 'package:running_on_dart/src/repository/kavita.dart';
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
        id('kavita-user-login', (InteractionChatContext context) async {
          final config = await Injector.appInstance
              .get<KavitaRepository>()
              .findAllForParent(getParentIdFromContext(context).toString());

          final modalResult = await context.getModal(title: "Login to Kavita", components: [
            TextInputBuilder(customId: 'username', style: TextInputStyle.short, label: 'Username', isRequired: true),
            TextInputBuilder(customId: 'password', style: TextInputStyle.short, label: 'Password', isRequired: true),
          ]);

          final apiLoginResult = await Injector.appInstance
              .get<KavitaModule>()
              .createUnauthenticatedClient(config.first)
              .login(modalResult['username']!, modalResult['password']!);

          await Injector.appInstance.get<KavitaModule>().login(config.first, apiLoginResult, context.user.id);

          return context.respond(MessageBuilder(content: "Logged in successfully!"));
        }),
      )
    ],
  ),
  ChatCommand(
      "test",
      "Test",
      id('kavita-test', (ChatContext context, [KavitaUserConfig? config]) async {
        final client = await getKavitaClient(config, context);

        final pageData = await client.getChapterImage(104, 3);

        return context.respond(MessageBuilder(attachments: [
          AttachmentBuilder(data: pageData, fileName: '003.jpg'),
        ]));
      }))
]);
