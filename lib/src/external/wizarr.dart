import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

class InvitationValidationResult {
  String username;

  InvitationValidationResult({required this.username});

  factory InvitationValidationResult.parseJson(Map<String, dynamic> data) {
    return InvitationValidationResult(username: data['username']);
  }
}

class Library {
  final String id;
  final String name;

  Library({required this.id, required this.name});

  factory Library.parseJson(Map<String, dynamic> data) {
    return Library(id: data['id'], name: data['name']);
  }
}

class CreateInvitationRequest {
  final String code;
  final Duration? expires;
  final Duration? duration;
  final List<String> specificLibraries;
  final bool unlimited;
  final int sessions;

  CreateInvitationRequest(
      {required this.code,
      required this.expires,
      required this.duration,
      required this.specificLibraries,
      required this.unlimited,
      required this.sessions});

  Map<String, String> toBody() => {
        'code': code,
        if (duration != null) 'duration': duration!.inMinutes.toString(),
        if (expires != null) 'expires': expires!.inMinutes.toString(),
        'live_tv': 'false',
        'plex_allow_sync': 'false',
        'plex_home': 'false',
        'sessions': sessions.toString(),
        'unlimited': unlimited ? 'true' : 'false',
        'specific_libraries': jsonEncode(specificLibraries),
      };
}

class WizarrClient {
  final String baseUrl;
  final String token;
  final String configName;

  WizarrClient({required this.baseUrl, required this.token, required this.configName});

  Future<InvitationValidationResult> validateInvitation(
      String code, String username, String password, String email) async {
    var t = Random.secure().nextInt(100000);

    final tempSid = await _fetchSid(t);
    _validateSid(++t, tempSid);

    final finalSid = await _fetchFinalSid(++t, tempSid);

    return _validateInvitation(code, username, password, email, finalSid);
  }

  Future<bool> createInvitation(CreateInvitationRequest createInvitationRequest) async {
    final response = await _postAuth(_getUri('/api/invitations'), createInvitationRequest.toBody(), encodeJson: false);

    if (response.statusCode < 300) {
      return true;
    }

    if (response is http.StreamedResponse) {
      print(await response.stream.toStringStream().join('\n'));
    }
    return false;
  }

  Future<List<Library>> getAvailableLibraries() async {
    final response = await _getAuth(_getUri("/api/libraries"));

    final body = jsonDecode(response.body) as List<dynamic>;

    return body.map((element) => Library.parseJson(element as Map<String, dynamic>)).toList();
  }

  Future<InvitationValidationResult> _validateInvitation(
      String code, String username, String password, String email, String sid) async {
    final result = await http.post(_getUri("/api/jellyfin"), body: {
      "username": username,
      "email": email,
      "password": password,
      "code": code,
      "socket_id": sid,
    });

    final body = jsonDecode(result.body) as Map<String, dynamic>;
    return InvitationValidationResult.parseJson(body);
  }

  Future<String> _fetchSid(int t) async {
    final result = await http.get(_getUri("/socket.io/", parameters: {
      "EIO": "4",
      "transport": "polling",
      "t": t.toString(),
    }));

    final bodyString = result.body.substring(1);
    final bodyJson = jsonDecode(bodyString);

    return bodyJson['sid'];
  }

  Future<void> _validateSid(int t, String sid) async {
    final result = await http.post(
        _getUri("/socket.io/", parameters: {
          "EIO": "4",
          "transport": "polling",
          "t": t.toString(),
          'sid': sid,
        }),
        body: '40/jellyfin,');

    if (result.body != 'OK') {
      throw Exception("Cannot validate sid");
    }
  }

  Future<String> _fetchFinalSid(int t, String sid) async {
    final result = await http.get(_getUri("/socket.io/", parameters: {
      "EIO": "4",
      "transport": "polling",
      "t": t.toString(),
      'sid': sid,
    }));

    final bodyString = result.body.replaceFirst('40/jellyfin,', '');
    final bodyJson = jsonDecode(bodyString);

    return bodyJson['sid'];
  }

  Future<http.Response> _getAuth(Uri uri) => http.get(uri, headers: _getHeaders(includeAuth: true));
  Future<http.BaseResponse> _postAuth(Uri uri, Map<String, dynamic> body, {bool encodeJson = true}) {
    if (encodeJson) {
      return http.post(uri, headers: _getHeaders(includeAuth: true), body: jsonEncode(body));
    }

    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_getHeaders(includeAuth: true, includeContentType: false))
      ..fields.addAll(body.cast());

    return request.send();
  }

  Map<String, String> _getHeaders({bool includeAuth = false, bool includeContentType = true}) {
    final headers = <String, String>{};

    if (includeAuth) {
      headers.addAll({"Authorization": "Bearer $token"});
    }

    if (includeContentType) {
      headers.addAll({'Accept': 'application/json', 'Content-Type': 'application/json'});
    }

    return headers;
  }

  Uri _getUri(String path, {Map<String, String> parameters = const {}}) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: parameters);
}
