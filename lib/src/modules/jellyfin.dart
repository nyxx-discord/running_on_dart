import 'dart:async';

import 'package:collection/collection.dart';
import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/external/sonarr.dart';
import 'package:running_on_dart/src/external/wizarr.dart';
import 'package:running_on_dart/src/models/jellyfin_config.dart';
import 'package:running_on_dart/src/repository/jellyfin_config.dart';
import 'package:running_on_dart/src/util/util.dart';
import 'package:tentacle/tentacle.dart';
import 'package:tentacle/src/auth/auth.dart' show AuthInterceptor;
import 'package:dio/dio.dart'
    show DioException, ErrorInterceptorHandler, Interceptor, RequestInterceptorHandler, RequestOptions;
import 'package:built_collection/built_collection.dart';

MessageBuilder getWizarrRedeemInvitationMessageBuilder(
    WizarrClient client, String code, Snowflake userId, Snowflake parentId, String configName) {
  return MessageBuilder(
      content:
          "Redeem Wizarr invitation to jellyfin instance. Your code: `$code`. \nYou can also redeem later using slash command: `/jellyfin wizarr redeem-invitation`",
      components: [
        ActionRowBuilder(components: [
          ButtonBuilder.link(url: Uri.parse("${client.baseUrl}/j/$code"), label: "Redeem code in browser"),
          ButtonBuilder.primary(
              customId: RedeemWizarrInvitationId.button(
                      userId: userId, code: code, parentId: parentId, configName: configName)
                  .toString(),
              label: "Redeem here"),
        ])
      ]);
}

class JellyfinLoginSelectId {
  static String identifier = 'JellyfinLoginSelectId';

  final Snowflake userId;

  JellyfinLoginSelectId({required this.userId});

  static JellyfinLoginSelectId? parse(String idString) {
    final idParts = idString.split("/");

    if (idParts.isEmpty || idParts[0] != identifier) {
      return null;
    }

    return JellyfinLoginSelectId(userId: Snowflake.parse(idParts[1]));
  }

  @override
  String toString() => "$identifier/$userId";
}

class JellyfinLoginCustomId {
  static String usernameIdentifier = 'JellyfinLoginCustomId_usernameIdentifier';
  static String quickConnectIdentifier = 'JellyfinLoginCustomId_quickConnectIdentifier';

  final String identifier;
  final Snowflake userId;
  final Snowflake parentId;
  final String configName;
  final bool isModal;

  bool get isUsernameAuth => identifier == usernameIdentifier;
  bool get isQuickConnectAuth => identifier == quickConnectIdentifier;

  JellyfinLoginCustomId(
      {required this.identifier,
      required this.userId,
      required this.configName,
      required this.parentId,
      required this.isModal});

  factory JellyfinLoginCustomId.username(
          {required Snowflake userId, required String configName, required Snowflake parentId, bool isModal = false}) =>
      JellyfinLoginCustomId(
          identifier: usernameIdentifier, userId: userId, configName: configName, parentId: parentId, isModal: isModal);
  factory JellyfinLoginCustomId.quickConnect(
          {required Snowflake userId, required String configName, required Snowflake parentId}) =>
      JellyfinLoginCustomId(
          identifier: quickConnectIdentifier,
          userId: userId,
          configName: configName,
          parentId: parentId,
          isModal: false);

  static JellyfinLoginCustomId? parse(String idString) {
    final idParts = idString.split("/");

    if (idParts.isEmpty || ![usernameIdentifier, quickConnectIdentifier].contains(idParts[0])) {
      return null;
    }

    return JellyfinLoginCustomId(
        identifier: idParts[0],
        userId: Snowflake.parse(idParts[1]),
        parentId: Snowflake.parse(idParts[2]),
        configName: idParts[3],
        isModal: idParts[4] == 'true');
  }

  @override
  String toString() => "$identifier/$userId/$parentId/$configName/${isModal ? 'true' : 'false'}";
}

class RedeemWizarrInvitationId {
  static String buttonIdentifier = 'ReminderRedeemWizarrInvitationButtonIdButton';
  static String modalIdentifier = 'ReminderRedeemWizarrInvitationButtonIdModal';

  final String identifier;
  final Snowflake userId;
  final String code;
  final Snowflake parentId;
  final String configName;

  bool get isButton => identifier == buttonIdentifier;
  bool get isModal => identifier == modalIdentifier;

  RedeemWizarrInvitationId(
      {required this.identifier,
      required this.userId,
      required this.code,
      required this.parentId,
      required this.configName});
  factory RedeemWizarrInvitationId.button(
          {required Snowflake userId, required String code, required Snowflake parentId, required String configName}) =>
      RedeemWizarrInvitationId(
          identifier: buttonIdentifier, userId: userId, code: code, parentId: parentId, configName: configName);
  factory RedeemWizarrInvitationId.modal(
          {required Snowflake userId, required String code, required Snowflake parentId, required String configName}) =>
      RedeemWizarrInvitationId(
          identifier: modalIdentifier, userId: userId, code: code, parentId: parentId, configName: configName);

  static RedeemWizarrInvitationId? parse(String idString) {
    final idParts = idString.split("/");

    if (idParts.isEmpty || ![buttonIdentifier, modalIdentifier].contains(idParts[0])) {
      return null;
    }

    return RedeemWizarrInvitationId(
      identifier: idParts[0],
      userId: Snowflake.parse(idParts[1]),
      code: idParts[2],
      parentId: Snowflake.parse(idParts[3]),
      configName: idParts[4],
    );
  }

  @override
  String toString() => "$identifier/$userId/$code/$parentId/$configName";
}

class AuthenticatedJellyfinClient {
  final Tentacle jellyfinClient;
  final JellyfinConfigUser configUser;

  AuthenticatedJellyfinClient(this.jellyfinClient, this.configUser);

  Future<Iterable<SessionInfo>> getCurrentSessions() async {
    final response = await jellyfinClient.getSessionApi().getSessions(activeWithinSeconds: 15);
    return response.data ?? [];
  }

  Future<List<BaseItemDto>> searchItems(String query,
      {int limit = 15,
      bool includeEpisodes = false,
      bool includeMovies = true,
      bool includeSeries = true,
      bool isMissing = false}) async {
    final includeItemTypes = [
      if (includeEpisodes) BaseItemKind.episode,
      if (includeMovies) BaseItemKind.movie,
      if (includeSeries) BaseItemKind.series,
    ];

    final response = await jellyfinClient.getItemsApi().getItems(
          searchTerm: query,
          limit: limit,
          recursive: true,
          includeItemTypes: BuiltList.from(includeItemTypes),
          fields: BuiltList.from([ItemFields.overview]),
          isMissing: isMissing,
        );

    return response.data?.items?.toList() ?? [];
  }

  Future<UserDto?> createUser(String username, String password, {List<String> allowedLibraries = const []}) async {
    final response = await jellyfinClient.getUserApi().createUserByName(
        createUserByName: CreateUserByName((b) => b
          ..name = username
          ..password = password));
    if (response.data == null) {
      return null;
    }

    if (allowedLibraries.isNotEmpty) {
      final allowedLibrariesLoweredCase = allowedLibraries.map((str) => str.toLowerCase());

      final mediaFoldersResponse = await jellyfinClient.getLibraryApi().getMediaFolders(isHidden: false);
      final mediaFoldersIds = (mediaFoldersResponse.data?.items?.toList() ?? [])
          .where((item) => allowedLibrariesLoweredCase.contains(item.name?.toLowerCase()))
          .map((item) => item.id)
          .nonNulls;

      await jellyfinClient.getUserApi().updateUserPolicy(
          userId: response.data!.id!,
          userPolicy: UserPolicy((up) => up
            ..enabledFolders = ListBuilder(mediaFoldersIds)
            ..authenticationProviderId = 'Jellyfin.Server.Implementations.Users.DefaultAuthenticationProvider'
            ..passwordResetProviderId = 'Jellyfin.Server.Implementations.Users.DefaultPasswordResetProvider'
            ..enableAllFolders = false));
    }

    return response.data;
  }

  Future<List<TaskInfo>> getScheduledTasks() async {
    final response = await jellyfinClient.getScheduledTasksApi().getTasks(isHidden: false);

    return response.data?.toList() ?? [];
  }

  Future<UserDto> getCurrentUser() async {
    final response = await jellyfinClient.getUserApi().getCurrentUser();

    return response.data!;
  }

  Future<void> startTask(String taskId) => jellyfinClient.getScheduledTasksApi().startTask(taskId: taskId);
  Uri getItemPrimaryImage(String itemId) => Uri.parse("${configUser.config?.basePath}/Items/$itemId/Images/Primary");
  Uri getJellyfinItemUrl(String itemId) => Uri.parse("${configUser.config?.basePath}/#/details?id=$itemId");
  Uri getUserImage(String userId, String imageTag) =>
      Uri.parse("${configUser.config?.basePath}/Users/$userId/Images/Primary?tag=$imageTag");
  Uri getUserProfile(String userId) =>
      Uri.parse('${configUser.config?.basePath}/web/#/userprofile.html?userId=$userId');
}

class AnonymousJellyfinClient {
  final Tentacle jellyfinClient;
  final JellyfinConfig config;

  AnonymousJellyfinClient({required this.jellyfinClient, required this.config});

  Future<AuthenticationResult> loginByPassword(String username, String password) async {
    final response = await jellyfinClient.getUserApi().authenticateUserByName(
        authenticateUserByName: AuthenticateUserByName((builder) => builder
          ..username = username
          ..pw = password));

    return response.data!;
  }

  Future<QuickConnectResult> initiateLoginByQuickConnect() async {
    final response = await jellyfinClient.getQuickConnectApi().initiateQuickConnect();

    return response.data!;
  }

  Future<bool> checkQuickConnectStatus(QuickConnectResult quickConnectResult) async {
    final response = await jellyfinClient.getQuickConnectApi().getQuickConnectState(secret: quickConnectResult.secret!);

    return response.data?.authenticated ?? false;
  }

  Future<AuthenticationResult?> finishLoginByQuickConnect(QuickConnectResult quickConnectResult) async {
    final response = await jellyfinClient.getUserApi().authenticateWithQuickConnect(
        quickConnectDto:
            QuickConnectDto((quickConnectBuilder) => quickConnectBuilder.secret = quickConnectResult.secret));

    if (response.statusCode != 200) {
      return null;
    }

    return response.data!;
  }
}

class TokenAuthInterceptor extends AuthInterceptor {
  final String token;

  TokenAuthInterceptor(this.token);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['Authorization'] = 'MediaBrowser Token="$token"';

    super.onRequest(options, handler);
  }
}

class AnonAuthInterceptor extends AuthInterceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['Authorization'] =
        'MediaBrowser Client="Jellyfin Web", Device="Chrome", DeviceId="1234", Version="10.9.11"';

    super.onRequest(options, handler);
  }
}

class AuthResponseErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      throw JellyfinUnauthorizedException(err.requestOptions.uri.host);
    }

    handler.next(err);
  }
}

class JellyfinUnauthorizedException implements Exception {
  final String host;
  const JellyfinUnauthorizedException(this.host);
}

class JellyfinConfigNotFoundException implements Exception {
  final String message;
  const JellyfinConfigNotFoundException(this.message);

  @override
  String toString() => "JellyfinConfigNotFoundException: $message";
}

class JellyfinAdminUserRequired implements Exception {
  @override
  String toString() => "JellyfinAdminUserRequired: You don't have admin permissions on jellyfin instance.";
}

class JellyfinModuleV2 implements RequiresInitialization {
  final JellyfinConfigRepository _jellyfinConfigRepository = Injector.appInstance.get();
  final NyxxGateway _client = Injector.appInstance.get();

  @override
  Future<void> init() async {
    final buttonInteractions = _client.onMessageComponentInteraction
        .where((event) => event.interaction.data.type == MessageComponentType.button);

    buttonInteractions.listen(_handleButtonInteractionForWizarrRedeemInvitation);
    buttonInteractions.listen(_handleButtonInteractionForJellyfinLogin);

    _client.onModalSubmitInteraction.listen(_handleModalInteractionForWizarrRedeemInvitation);
    _client.onModalSubmitInteraction.listen(_handleModalJellyfinLoginUsername);
  }

  Future<void> _handleModalJellyfinLoginUsername(InteractionCreateEvent<ModalSubmitInteraction> event) async {
    final customId = JellyfinLoginCustomId.parse(event.interaction.data.customId);
    if (customId == null || !customId.isModal) {
      return;
    }

    final currentUserId = event.interaction.user?.id ?? event.interaction.member?.id;
    if (customId.userId != currentUserId) {
      return event.interaction.respond(MessageBuilder(content: "Invalid interaction"));
    }

    final config = await getJellyfinConfig(customId.configName, customId.parentId);
    if (config == null) {
      return;
    }

    return _handleLoginUsername(event.interaction, config, customId.userId);
  }

  Future<void> _handleModalInteractionForWizarrRedeemInvitation(
      InteractionCreateEvent<ModalSubmitInteraction> event) async {
    final customId = RedeemWizarrInvitationId.parse(event.interaction.data.customId);
    if (customId == null || !customId.isModal) {
      return;
    }

    if (customId.userId != event.interaction.user?.id) {
      return event.interaction.respond(MessageBuilder(content: "Invalid interaction"));
    }

    final modalComponents = event.interaction.data.components
        .cast<ActionRowComponent>()
        .map((row) => row.components)
        .flattened
        .cast<TextInputComponent>();

    final usernameComponent = modalComponents.firstWhere((component) => component.customId == 'username');
    final passwordComponent = modalComponents.firstWhere((component) => component.customId == 'password');
    final emailComponent = modalComponents.firstWhere((component) => component.customId == 'email');

    final config = await getJellyfinConfig(customId.configName, customId.parentId);
    final client = await fetchGetWizarrClientWithFallback(originalConfig: config, parentId: customId.parentId);

    final redeemResult = await client.validateInvitation(
        customId.code, usernameComponent.value!, passwordComponent.value!, emailComponent.value!);

    event.interaction
        .respond(MessageBuilder(content: "Invitation redeemed (username: ${redeemResult.username})", components: [
      ActionRowBuilder(components: [
        ButtonBuilder.link(url: Uri.parse(config!.basePath), label: "Go to Jellyfin"),
        ButtonBuilder.link(url: Uri.parse('https://jellyfin.org/downloads'), label: "Download Jellyfin client"),
      ])
    ]));
  }

  Future<void> _handleButtonInteractionForJellyfinLogin(
      InteractionCreateEvent<MessageComponentInteraction> event) async {
    final customId = JellyfinLoginCustomId.parse(event.interaction.data.customId);
    if (customId == null) {
      return;
    }

    final currentUserId = event.interaction.user?.id ?? event.interaction.member?.id;

    if (customId.userId != currentUserId) {
      return event.interaction.respond(MessageBuilder(content: "Invalid interaction"));
    }

    final config = await getJellyfinConfig(customId.configName, customId.parentId);
    if (config == null) {
      return;
    }

    if (customId.isQuickConnectAuth) {
      return _handleLoginQuickConnect(event.interaction, config, customId.userId);
    }

    if (customId.isUsernameAuth) {
      return event.interaction.respondModal(ModalBuilder(
          customId: JellyfinLoginCustomId.username(
                  userId: customId.userId, configName: customId.configName, parentId: customId.parentId, isModal: true)
              .toString(),
          title: "Login to jellyfin instance (${config.name})",
          components: [
            ActionRowBuilder(components: [
              TextInputBuilder(customId: 'username', style: TextInputStyle.short, label: 'Username', isRequired: true)
            ]),
            ActionRowBuilder(components: [
              TextInputBuilder(customId: 'password', style: TextInputStyle.short, label: 'Password', isRequired: true)
            ])
          ]));
    }
  }

  Future<void> _handleButtonInteractionForWizarrRedeemInvitation(
      InteractionCreateEvent<MessageComponentInteraction> event) async {
    final customId = RedeemWizarrInvitationId.parse(event.interaction.data.customId);
    if (customId == null || !customId.isButton) {
      return;
    }

    if (customId.userId != event.interaction.user?.id) {
      return event.interaction.respond(MessageBuilder(content: "Invalid interaction"));
    }

    event.interaction.respondModal(ModalBuilder(
        customId: RedeemWizarrInvitationId.modal(
                userId: customId.userId,
                code: customId.code,
                parentId: customId.parentId,
                configName: customId.configName)
            .toString(),
        title: "Redeem wizarr code",
        components: [
          ActionRowBuilder(components: [
            TextInputBuilder(customId: "username", style: TextInputStyle.short, label: "Username", isRequired: true),
          ]),
          ActionRowBuilder(components: [
            TextInputBuilder(customId: "password", style: TextInputStyle.short, label: "Password", isRequired: true),
          ]),
          ActionRowBuilder(components: [
            TextInputBuilder(customId: "email", style: TextInputStyle.short, label: "Email", isRequired: true),
          ]),
        ]));
  }

  Future<void> _handleLoginUsername(ModalSubmitInteraction interaction, JellyfinConfig config, Snowflake userId) async {
    final client = Injector.appInstance.get<JellyfinModuleV2>().createJellyfinClientAnonymous(config);
    final modalData = getModalDataIndexed(interaction.data.components);

    final loginCallResult = await client.loginByPassword(modalData['username']!, modalData['password']!);
    final loginResult = await Injector.appInstance.get<JellyfinModuleV2>().login(config, loginCallResult, userId);

    if (loginResult) {
      return interaction.respond(MessageBuilder(content: "Logged in successfully!"), isEphemeral: true);
    }

    return interaction.respond(MessageBuilder(content: "Cannot login. Contact with bot admin!"), isEphemeral: true);
  }

  Future<void> _handleLoginQuickConnect(
      MessageComponentInteraction interaction, JellyfinConfig config, Snowflake userId) async {
    final client = Injector.appInstance.get<JellyfinModuleV2>().createJellyfinClientAnonymous(config);

    final initiationResult = await client.initiateLoginByQuickConnect();

    await interaction.respond(
        MessageBuilder(content: "Quick Connect code: `${initiationResult.code}`. Waiting for confirmation..."),
        isEphemeral: true);
    Timer.periodic(Duration(seconds: 2), (Timer timer) async {
      if (timer.tick > 30) {
        interaction
            .updateOriginalResponse(MessageUpdateBuilder(content: "Cannot login. Took too long to confirm code"));
        timer.cancel();
      }

      final isConfirmed = await client.checkQuickConnectStatus(initiationResult);
      if (!isConfirmed) {
        return;
      }

      timer.cancel();

      final finishResult = await client.finishLoginByQuickConnect(initiationResult);
      if (finishResult == null) {
        interaction.updateOriginalResponse(MessageUpdateBuilder(content: "Cannot login. Contact with bot admin!"));
        return;
      }

      final loginResult = await Injector.appInstance.get<JellyfinModuleV2>().login(config, finishResult, userId);
      if (loginResult) {
        interaction.updateOriginalResponse(MessageUpdateBuilder(content: "Logged in successfully!"));
        return;
      }

      interaction.updateOriginalResponse(MessageUpdateBuilder(content: "Cannot login. Contact with bot admin!"));
    });
  }

  Future<List<JellyfinConfigUser>> getJellyfinConfigBasedOnPreviousLogin(
      Snowflake userId, Snowflake guildId, String host) {
    return _jellyfinConfigRepository.getJellyfinConfigBasedOnPreviousLogin(userId.toString(), guildId.toString(), host);
  }

  Future<JellyfinConfig?> getJellyfinConfig(String name, Snowflake parentId) {
    return _jellyfinConfigRepository.getByNameAndGuild(name, parentId.toString());
  }

  Future<JellyfinConfig?> getJellyfinConfigById(int id) {
    return _jellyfinConfigRepository.getJellyfinConfigById(id);
  }

  Future<JellyfinConfig?> getJellyfinDefaultConfig(Snowflake parentId) {
    return _jellyfinConfigRepository.getDefaultForParent(parentId.toString());
  }

  Future<WizarrClient> fetchGetWizarrClientWithFallback(
      {required JellyfinConfig? originalConfig, required Snowflake parentId}) async {
    final config = originalConfig ?? await getJellyfinDefaultConfig(parentId);
    if (config == null) {
      throw JellyfinConfigNotFoundException("Missing jellyfin config");
    }

    if (config.wizarrBasePath == null || config.wizarrToken == null) {
      throw JellyfinConfigNotFoundException("Wizarr not configured!");
    }

    return WizarrClient(baseUrl: config.wizarrBasePath!, token: config.wizarrToken!, configName: config.name);
  }

  Future<SonarrClient> fetchGetSonarrClientWithFallback(
      {required JellyfinConfig? originalConfig, required Snowflake parentId}) async {
    final config = originalConfig ?? await getJellyfinDefaultConfig(parentId);
    if (config == null) {
      throw JellyfinConfigNotFoundException("Missing jellyfin config");
    }

    if (config.sonarrBasePath == null || config.sonarrToken == null) {
      throw JellyfinConfigNotFoundException("Sonarr not configured!");
    }

    return SonarrClient(baseUrl: config.sonarrBasePath!, token: config.sonarrToken!);
  }

  Future<JellyfinConfigUser?> fetchGetUserConfigWithFallback(
      {required Snowflake userId, required Snowflake parentId, String? instanceName}) async {
    final config = instanceName != null
        ? await getJellyfinConfig(instanceName, parentId)
        : await getJellyfinDefaultConfig(parentId);
    if (config == null) {
      return null;
    }

    final userConfig = await fetchJellyfinUserConfig(userId, config);
    if (userConfig == null) {
      return null;
    }

    return userConfig;
  }

  Future<JellyfinConfigUser?> fetchJellyfinUserConfig(Snowflake userId, JellyfinConfig config) async {
    final userConfig = await _jellyfinConfigRepository.getUserConfig(userId.toString(), config.id!);
    userConfig?.config = config;

    return userConfig;
  }

  AnonymousJellyfinClient createJellyfinClientAnonymous(JellyfinConfig config) {
    return AnonymousJellyfinClient(
        jellyfinClient: Tentacle(basePathOverride: config.basePath, interceptors: [AnonAuthInterceptor()]),
        config: config);
  }

  AuthenticatedJellyfinClient createJellyfinClientAuthenticated(JellyfinConfigUser configUser) {
    return AuthenticatedJellyfinClient(
        Tentacle(
            basePathOverride: configUser.config!.basePath,
            interceptors: [TokenAuthInterceptor(configUser.token), AuthResponseErrorInterceptor()]),
        configUser);
  }

  Future<bool> login(JellyfinConfig config, AuthenticationResult authResult, Snowflake userId) async {
    await _jellyfinConfigRepository.saveJellyfinConfigUser(
      JellyfinConfigUser(userId: userId, token: authResult.accessToken!, jellyfinConfigId: config.id!),
    );

    return true;
  }

  Future<bool> loginWithPassword(JellyfinConfig config, String username, String password, Snowflake userId) async {
    final client = createJellyfinClientAnonymous(config);

    final response = await client.loginByPassword(username, password);
    await _jellyfinConfigRepository.saveJellyfinConfigUser(
      JellyfinConfigUser(userId: userId, token: response.accessToken!, jellyfinConfigId: config.id!),
    );

    return true;
  }

  Future<JellyfinConfig> createJellyfinConfig(JellyfinConfig config) async {
    final createdConfig = await _jellyfinConfigRepository.createJellyfinConfig(config);
    if (createdConfig.id == null) {
      throw Error();
    }

    return createdConfig;
  }

  Future<void> updateJellyfinConfig(JellyfinConfig config) async {
    return await _jellyfinConfigRepository.updateJellyfinConfig(config);
  }
}
