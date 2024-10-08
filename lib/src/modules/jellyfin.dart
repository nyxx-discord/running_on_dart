import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/models/jellyfin_config.dart';
import 'package:running_on_dart/src/repository/jellyfin_config.dart';
import 'package:tentacle/tentacle.dart';
import 'package:tentacle/src/auth/auth.dart' show AuthInterceptor;
import 'package:dio/dio.dart' show RequestInterceptorHandler, RequestOptions;
import 'package:built_collection/built_collection.dart';

class CustomAuthInterceptor extends AuthInterceptor {
  final String token;

  CustomAuthInterceptor(this.token);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['Authorization'] = 'MediaBrowser Token="$token"';

    super.onRequest(options, handler);
  }
}

typedef JellyfinInstanceIdentity = (String? instanceName, Snowflake guildId);

class JellyfinClientWrapper {
  final Tentacle jellyfinClient;
  final JellyfinConfig config;

  String get basePath => config.basePath;
  String get name => config.name;

  JellyfinClientWrapper(this.jellyfinClient, this.config);

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

  Uri getItemPrimaryImage(String itemId) => Uri.parse("$basePath/Items/$itemId/Images/Primary");

  Uri getJellyfinItemUrl(String itemId) => Uri.parse("$basePath/#/details?id=$itemId");
}

class JellyfinModule {
  static JellyfinModule get instance =>
      _instance ?? (throw Exception('JellyfinModule must be initialised with JellyfinModule.init()'));
  static JellyfinModule? _instance;

  static final Map<String, JellyfinClientWrapper> _jellyfinClients = {};

  final Map<String, List<String>> _allowedUserRegistrations = {};

  static void init() {
    _instance = JellyfinModule._();

    JellyfinConfigRepository.instance
        .getDefaultConfigs()
        .then((defaultConfigs) => defaultConfigs.forEach((config) => _createClientConfig(config)));
  }

  JellyfinModule._();

  Future<void> deleteJellyfinConfig(JellyfinConfig config) async {
    _jellyfinClients.remove(
      _getClientCacheIdentifier(config.parentId.toString(), config.name, config.isDefault),
    );

    await JellyfinConfigRepository.instance.deleteConfig(config.id!);
  }

  Future<JellyfinClientWrapper?> getClient(JellyfinInstanceIdentity identity) async {
    final cachedClientConfig = _getCachedClientConfig(identity);
    if (cachedClientConfig != null) {
      return cachedClientConfig;
    }

    final config = await JellyfinConfigRepository.instance.getByName(identity.$1!, identity.$2.toString());
    if (config == null) {
      return null;
    }

    return _createClientConfig(config);
  }

  (bool, List<String>) isUserAllowedForRegistration(String instanceName, Snowflake userId) {
    final key = "$instanceName$userId";

    final allowed = _allowedUserRegistrations[key];
    if (allowed == null) {
      return (false, []);
    }

    _allowedUserRegistrations.remove(key);

    return (true, allowed);
  }

  void addUserToAllowedForRegistration(String instanceName, Snowflake userId, List<String> allowedLibraries) =>
      _allowedUserRegistrations["$instanceName$userId"] = allowedLibraries;

  Future<JellyfinConfig> createJellyfinConfig(
      String name, String basePath, String token, bool isDefault, Snowflake guildId) async {
    final config =
        await JellyfinConfigRepository.instance.createJellyfinConfig(name, basePath, token, isDefault, guildId);
    if (config.id == null) {
      throw Error();
    }

    _jellyfinClients[_getClientCacheIdentifier(config.parentId.toString(), config.name, config.isDefault)] =
        _createClientConfig(config);

    return config;
  }

  static JellyfinClientWrapper? _getCachedClientConfig(JellyfinInstanceIdentity identity) =>
      _jellyfinClients[_getClientCacheIdentifier(identity.$2.toString(), identity.$1)];

  static JellyfinClientWrapper _createClientConfig(JellyfinConfig config) {
    final client = Tentacle(basePathOverride: config.basePath, interceptors: [CustomAuthInterceptor(config.token)]);

    final clientConfig = JellyfinClientWrapper(client, config);

    _jellyfinClients[_getClientCacheIdentifier(config.parentId.toString(), config.name, config.isDefault)] =
        clientConfig;

    return clientConfig;
  }

  static String _getClientCacheIdentifier(String guildId, String? instanceName, [bool isDefault = false]) {
    if (instanceName != null && !isDefault) {
      return "$guildId|$instanceName";
    }

    return guildId;
  }
}
