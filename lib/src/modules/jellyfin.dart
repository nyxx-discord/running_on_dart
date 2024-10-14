import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/external/sonarr.dart';
import 'package:running_on_dart/src/models/jellyfin_config.dart';
import 'package:running_on_dart/src/repository/jellyfin_config.dart';
import 'package:running_on_dart/src/util/util.dart';
import 'package:tentacle/tentacle.dart';
import 'package:tentacle/src/auth/auth.dart' show AuthInterceptor;
import 'package:dio/dio.dart' show RequestInterceptorHandler, RequestOptions;
import 'package:built_collection/built_collection.dart';

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

  Future<void> startTask(String taskId) => jellyfinClient.getScheduledTasksApi().startTask(taskId: taskId);

  Uri getItemPrimaryImage(String itemId) => Uri.parse("${configUser.config?.basePath}/Items/$itemId/Images/Primary");

  Uri getJellyfinItemUrl(String itemId) => Uri.parse("${configUser.config?.basePath}/#/details?id=$itemId");
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

class JellyfinConfigNotFoundException implements Exception {
  final String message;
  const JellyfinConfigNotFoundException(this.message);

  @override
  String toString() => "JellyfinConfigNotFoundException: $message";
}

class JellyfinModuleV2 implements RequiresInitialization {
  final JellyfinConfigRepository _jellyfinConfigRepository = Injector.appInstance.get();

  @override
  Future<void> init() async {}

  Future<JellyfinConfig?> getJellyfinConfig(String name, Snowflake parentId) {
    return _jellyfinConfigRepository.getByNameAndGuild(name, parentId.toString());
  }

  Future<JellyfinConfig?> getJellyfinDefaultConfig(Snowflake parentId) {
    return _jellyfinConfigRepository.getDefaultForParent(parentId.toString());
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

  Future<JellyfinConfigUser> fetchGetUserConfigWithFallback(
      {required Snowflake userId, required Snowflake parentId, String? instanceName}) async {
    final config = instanceName != null
        ? await getJellyfinConfig(instanceName, parentId)
        : await getJellyfinDefaultConfig(parentId);
    if (config == null) {
      throw JellyfinConfigNotFoundException("Missing jellyfin config");
    }

    final userConfig = await fetchJellyfinUserConfig(userId, config);
    if (userConfig == null) {
      throw JellyfinConfigNotFoundException("User not logged in.");
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
        Tentacle(basePathOverride: configUser.config!.basePath, interceptors: [TokenAuthInterceptor(configUser.token)]),
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
}
