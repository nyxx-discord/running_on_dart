import 'package:running_on_dart/src/web_app/utils.dart';

JsonApiResponse createPaginationResponse(
    {required List<JsonApiResponse> data, required int total, required int perPage, required int page}) {
  return {
    'perPage': perPage,
    'page': page,
    'total': total,
    'data': data,
  };
}
