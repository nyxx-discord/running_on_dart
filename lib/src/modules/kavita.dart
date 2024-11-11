import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/models/kavita.dart';
import 'package:running_on_dart/src/repository/kavita.dart';

class LoginResult {
  final String token;
  final String apiKey;

  LoginResult({required this.token, required this.apiKey});

  factory LoginResult.fromJson(Map<String, dynamic> raw) {
    return LoginResult(token: raw['token'], apiKey: raw['apiKey']);
  }
}

class AuthenticatedKavitaClient {
  final String baseUrl;
  final String token;
  final String apiKey;

  late final Map<String, String> _headers;

  AuthenticatedKavitaClient({required this.baseUrl, required this.token, required this.apiKey}) {
    _headers = {'Accept': 'application/json', 'Content-Type': 'application/json'};
  }

  Future<Uint8List> getChapterImage(int chapterId, int page) async {
    final result = await _get("/api/Reader/image",
        parameters: {"chapterId": chapterId.toString(), "page": page.toString()}, authApiKey: true);

    return result.bodyBytes;
  }

  Future<http.Response> _get(String path,
      {Map<String, String> parameters = const {}, bool authToken = false, bool authApiKey = false}) async {
    final uri =
        Uri.parse('$baseUrl$path').replace(queryParameters: _makeQueryParameters(parameters, authApiKey: authApiKey));

    return await http.get(uri, headers: _makeHeaders(authToken: authToken));
  }

  Map<String, String> _makeQueryParameters(Map<String, String> parameters, {bool authApiKey = false}) => {
        ...parameters,
        if (authApiKey) 'apiKey': apiKey,
      };

  Map<String, String> _makeHeaders({bool authToken = false}) => {
        ..._headers,
        if (authToken) 'Authorization': 'Bearer $token',
      };
}

class UnauthenticatedKavitaClient {
  final String baseUrl;

  late final Map<String, String> _headers;

  UnauthenticatedKavitaClient({required this.baseUrl}) {
    _headers = {'Accept': 'application/json', 'Content-Type': 'application/json'};
  }

  Future<LoginResult> login(String username, String password) async {
    final result = await _post("/api/Account/login", body: {
      "username": username,
      "password": password,
    });

    final body = jsonDecode(result.body);

    return LoginResult.fromJson(body);
  }

  Future<http.Response> _post(String path, {Object? body}) async {
    return await http.post(Uri.parse('$baseUrl$path'), headers: _headers, body: jsonEncode(body));
  }
}

class KavitaModule {
  final KavitaRepository _kavitaRepository = Injector.appInstance.get();

  Future<KavitaConfig?> getJellyfinConfig(String name, Snowflake parentId) {
    return _kavitaRepository.find(name, parentId.toString());
  }

  Future<KavitaConfig?> getJellyfinDefaultConfig(Snowflake parentId) {
    return _kavitaRepository.findDefault(parentId.toString());
  }

  Future<KavitaUserConfig?> getUserConfigForConfig(Snowflake userId, KavitaConfig config) async {
    final userConfig = await _kavitaRepository.findUserConfigForConfig(userId.toString(), config.id!);
    userConfig?.config = config;

    return userConfig;
  }

  Future<KavitaUserConfig?> fetchGetUserConfigWithFallback(
      {required Snowflake userId, required Snowflake parentId, String? instanceName}) async {
    final config = instanceName != null
        ? await getJellyfinConfig(instanceName, parentId)
        : await getJellyfinDefaultConfig(parentId);
    if (config == null) {
      return null;
    }

    final userConfig = await getUserConfigForConfig(userId, config);
    if (userConfig == null) {
      return null;
    }

    return userConfig;
  }

  UnauthenticatedKavitaClient createUnauthenticatedClient(KavitaConfig config) {
    return UnauthenticatedKavitaClient(baseUrl: config.basePath);
  }

  AuthenticatedKavitaClient createAuthenticatedClient(KavitaUserConfig config) {
    if (config.config == null) {
      throw Exception();
    }

    return AuthenticatedKavitaClient(baseUrl: config.config!.basePath, token: config.authToken, apiKey: config.apiKey);
  }

  Future<KavitaUserConfig> login(KavitaConfig config, LoginResult loginResult, Snowflake userId) {
    final userConfig = KavitaUserConfig(
        userId: userId, authToken: loginResult.token, apiKey: loginResult.apiKey, kavitaConfigId: config.id!)
      ..config = config;

    return _kavitaRepository.saveUserConfig(userConfig);
  }
}
