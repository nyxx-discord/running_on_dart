import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/models/tag.dart';
import 'package:running_on_dart/src/modules/tag.dart';
import 'package:running_on_dart/src/web_app/mapper/pagination_mapper.dart';
import 'package:running_on_dart/src/web_app/utils.dart';

JsonApiResponse _mapGuildTag(Tag tag) {
  return {
    'id': tag.id,
    'name': tag.name,
    'content': tag.content,
    'enabled': tag.enabled,
    'authorId': tag.authorId.toString(),
  };
}

Future<JsonApiResponse> mapGuildTagsToData(Snowflake guildId, int tagsLimit,
    {String? searchQuery, int page = 1}) async {
  final tagsModule = Injector.appInstance.get<TagModule>();

  var tags = tagsModule.getGuildTags(guildId);
  if (searchQuery != null) {
    tags = tags.where((tag) => tag.name.contains(searchQuery));
  }

  return createPaginationResponse(
    data: tags.skip(tagsLimit * (page - 1)).take(tagsLimit).map(_mapGuildTag).toList(),
    total: tags.length,
    perPage: tagsLimit,
    page: page,
  );
}
