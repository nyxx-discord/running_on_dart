import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/models/jellyfin_config.dart';
import 'package:running_on_dart/src/repository/jellyfin_config.dart';
import 'package:tentacle/tentacle.dart';
import 'package:tentacle/src/auth/auth.dart' show AuthInterceptor;
import 'package:dio/dio.dart' show RequestInterceptorHandler, RequestOptions;

class CustomAuthInterceptor extends AuthInterceptor {
  final String token;

  CustomAuthInterceptor(this.token);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['Authorization'] = 'MediaBrowser Token="$token"';

    super.onRequest(options, handler);
  }
}

class JellyfinIdentificationModel {
  final String? instanceName;
  final Snowflake guildId;

  JellyfinIdentificationModel(this.guildId, this.instanceName);
}

class JellyfinClientWrapper {
  final Tentacle client;
  final String basePath;
  final String name;

  JellyfinClientWrapper(this.client, this.basePath, this.name);

  Future<Iterable<SessionInfo>> getCurrentSessions() async {
    final response = await client.getSessionApi().getSessions(activeWithinSeconds: 15);
    return response.data ?? [];
  }

  Uri getItemPrimaryImage(String itemId) => Uri.parse("$basePath/Items/$itemId/Images/Primary");
}

class JellyfinModule {
  static JellyfinModule get instance => _instance ?? (throw Exception('JellyfinModule must be initialised with JellyfinModule.init()'));
  static JellyfinModule? _instance;

  static final Map<String, JellyfinClientWrapper> _jellyfinClients = {};

  static void init() {
    _instance = JellyfinModule._();

    JellyfinConfigRepository.instance
        .getDefaultConfigs()
        .then((defaultConfigs) => defaultConfigs.forEach((config) => _createClientConfig(config)));
  }

  JellyfinModule._();

  Future<void> deleteJellyfinConfig(JellyfinConfig config) async {
    _jellyfinClients.remove(
      _getClientCacheIdentifier(config.guildId.toString(), config.name, config.isDefault),
    );

    await JellyfinConfigRepository.instance.deleteConfig(config.id!);
  }

  Future<JellyfinClientWrapper?> getClient(JellyfinIdentificationModel sConfig) async {
    final cachedClientConfig = _getCachedClientConfig(sConfig);
    if (cachedClientConfig != null) {
      return cachedClientConfig;
    }

    final config = await JellyfinConfigRepository.instance.getByName(sConfig.instanceName!, sConfig.guildId.toString());
    if (config == null) {
      return null;
    }

    return _createClientConfig(config);
  }

  Future<JellyfinConfig> createJellyfinConfig(String name, String basePath, String token, bool isDefault, Snowflake guildId) async {
    final config = await JellyfinConfigRepository.instance.createJellyfinConfig(name, basePath, token, isDefault, guildId);
    if (config.id == null) {
      throw Error();
    }

    _jellyfinClients[_getClientCacheIdentifier(config.guildId.toString(), config.name, config.isDefault)] = _createClientConfig(config);

    return config;
  }

  static JellyfinClientWrapper? _getCachedClientConfig(JellyfinIdentificationModel sConfig) =>
      _jellyfinClients[_getClientCacheIdentifier(sConfig.guildId.toString(), sConfig.instanceName)];

  static JellyfinClientWrapper _createClientConfig(JellyfinConfig config) {
    final client = Tentacle(basePathOverride: config.basePath, interceptors: [CustomAuthInterceptor(config.token)]);

    final clientConfig = JellyfinClientWrapper(client, config.basePath, config.name);

    _jellyfinClients[_getClientCacheIdentifier(config.guildId.toString(), config.name, config.isDefault)] = clientConfig;

    return clientConfig;
  }

  static String _getClientCacheIdentifier(String guildId, String? instanceName, [bool isDefault = false]) {
    if (instanceName != null && !isDefault) {
      return "$guildId|$instanceName";
    }

    return guildId;
  }
}
