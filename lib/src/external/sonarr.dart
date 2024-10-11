import 'dart:convert';

import 'package:http/http.dart' as http;

String _boolToString(bool boolValue) => boolValue ? 'true' : 'false';

class Image {
  final String coverType;
  final String remoteUrl;

  Image({required this.coverType, required this.remoteUrl});

  factory Image.parseJson(Map<String, dynamic> data) {
    return Image(coverType: data['coverType'], remoteUrl: data['remoteUrl']);
  }
}

class Series {
  final String title;
  final String status;
  final String overview;
  final int runtime;
  final Iterable<Image> images;

  Series(
      {required this.title, required this.status, required this.overview, required this.runtime, required this.images});

  factory Series.parseJson(Map<String, dynamic> data) {
    return Series(
      title: data['title'] as String,
      status: data['status'] as String,
      overview: data['overview'] as String,
      runtime: data['runtime'] as int,
      images: (data['images'] as List<Map<String, dynamic>>).map((imageJson) => Image.parseJson(imageJson)),
    );
  }
}

class Calendar {
  final int seriesId;
  final int seasonNumber;
  final int episodeNumber;
  final String title;
  final DateTime airDateUtc;
  final String overview;
  final Series series;

  Calendar(
      {required this.seriesId,
      required this.seasonNumber,
      required this.episodeNumber,
      required this.title,
      required this.airDateUtc,
      required this.overview,
      required this.series});

  factory Calendar.parseJson(Map<String, dynamic> data) {
    return Calendar(
      seriesId: data['seriesId'] as int,
      seasonNumber: data['seasonNumber'] as int,
      episodeNumber: data['episodeNumber'] as int,
      title: data['title'] as String,
      airDateUtc: DateTime.parse(data['seriesId']),
      overview: data['overview'] as String,
      series: Series.parseJson(data['series'] as Map<String, dynamic>),
    );
  }
}

class SonarrClient {
  final String baseUrl;

  late final Map<String, String> _headers;

  SonarrClient({required this.baseUrl, required String token}) {
    _headers = {"X-Api-Key": token, 'Accept': 'application/json', 'Content': 'application/json'};
  }

  Future<Calendar> fetchCalendar({DateTime? start, DateTime? end, bool? includeSeries = true}) async {
    final responseBody = await _get("/api/v3/calendar", parameters: {
      if (start != null) 'start': start.toIso8601String(),
      if (end != null) 'end': end.toIso8601String(),
      if (includeSeries != null) 'includeSeries': _boolToString(includeSeries),
    });

    return Calendar.parseJson(responseBody);
  }

  Future<Map<String, dynamic>> _get(String path, {Map<String, String> parameters = const {}}) async {
    final uri = Uri.parse('$baseUrl/$path');
    uri.queryParameters.addAll(parameters);

    final response = await http.get(uri, headers: _headers);

    return jsonDecode(response.body);
  }
}
