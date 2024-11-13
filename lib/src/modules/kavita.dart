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

class SeriesItem {
  final int seriesId;
  final String name;
  final String originalName;
  final int format;
  final String libraryName;
  final int libraryId;

  SeriesItem(
      {required this.seriesId,
      required this.name,
      required this.originalName,
      required this.format,
      required this.libraryName,
      required this.libraryId});

  factory SeriesItem.fromJson(Map<String, dynamic> raw) {
    return SeriesItem(
      seriesId: raw['seriesId'],
      name: raw['name'],
      originalName: raw['originalName'],
      format: raw['format'],
      libraryName: raw['libraryName'],
      libraryId: raw['libraryId'],
    );
  }
}

class ContinuePoint {
  final int id;
  final int pagesRead;
  final int pages;
  final int volumeId;
  final bool isBook;

  int get chapterId => id;

  ContinuePoint(
      {required this.id, required this.pagesRead, required this.pages, required this.volumeId, this.isBook = false});

  factory ContinuePoint.fromJson(Map<String, dynamic> raw) {
    return ContinuePoint(
      id: raw['id'],
      pagesRead: raw['pagesRead'],
      pages: raw['pages'],
      volumeId: raw['volumeId'],
      isBook: (raw['files'] as List<dynamic>?)?.firstOrNull?['format'] == 3,
    );
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

  Future<Iterable<SeriesItem>> searchSeries(String query) async {
    final result = await _get("/api/Search/search",
        parameters: {
          'queryString': query,
          'includeChapterAndFiles': false.toString(),
        },
        authToken: true);

    final body = jsonDecode(result.body) as Map<String, dynamic>;

    return (body['series'] as List<dynamic>).map((e) => SeriesItem.fromJson(e as Map<String, dynamic>));
  }

  Future<bool> saveContinuePoint(int seriesId, int volumeId, int chapterId, int page) async {
    final result = await _post('/api/Reader/progress',
        body: {
          'seriesId': seriesId,
          'volumeId': volumeId,
          'chapterId': chapterId,
          'pageNum': page,
        },
        authToken: true);

    return result.body == 'true';
  }

  Future<ContinuePoint> getContinuePoint(int seriesId) async {
    final result = await _get("/api/reader/continue-point",
        parameters: {
          'seriesId': seriesId.toString(),
        },
        authToken: true);

    final body = jsonDecode(result.body) as Map<String, dynamic>;
    return ContinuePoint.fromJson(body);
  }

  Future<String> getBookPage(int chapterId, int page) async {
    final result =
        await _get("/api/Book/$chapterId/book-page", parameters: {"page": page.toString()}, authApiKey: true);

    return result.body;
  }

  Future<int> getNextChapter(int seriesId, int volumeId, int currentChapterId) async {
    final result = await _get("/api/Reader/next-chapter",
        parameters: {
          'seriesId': seriesId.toString(),
          'volumeId': volumeId.toString(),
          'currentChapterId': currentChapterId.toString(),
        },
        authToken: true);

    return int.parse(result.body);
  }

  Future<Uint8List> getChapterCover(int chapterId) async {
    final result =
        await _get("/api/Image/chapter-cover", parameters: {"chapterId": chapterId.toString()}, authApiKey: true);

    return result.bodyBytes;
  }

  Future<Uint8List> getSeriesCover(int seriesId) async {
    final result =
        await _get("/api/Image/series-cover", parameters: {"seriesId": seriesId.toString()}, authApiKey: true);

    return result.bodyBytes;
  }

  Future<http.Response> _get(String path,
      {Map<String, String> parameters = const {}, bool authToken = false, bool authApiKey = false}) async {
    final uri =
        Uri.parse('$baseUrl$path').replace(queryParameters: _makeQueryParameters(parameters, authApiKey: authApiKey));

    return await http.get(uri, headers: _makeHeaders(authToken: authToken));
  }

  Future<http.Response> _post(String path,
      {Object? body,
      Map<String, String> parameters = const {},
      bool authToken = false,
      bool authApiKey = false}) async {
    return await http.post(
        Uri.parse('$baseUrl$path').replace(queryParameters: _makeQueryParameters(parameters, authApiKey: authApiKey)),
        headers: _makeHeaders(authToken: authToken),
        body: jsonEncode(body));
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
