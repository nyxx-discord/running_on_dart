import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/models/tag.dart';
import 'package:running_on_dart/src/modules/tag.dart';
import 'package:running_on_dart/src/web_app/mapper/pagination_mapper.dart';
import 'package:running_on_dart/src/web_app/utils.dart';

JsonApiResponse mapGuildTag(Tag tag) {
  return {
    'id': tag.id,
    'name': tag.name,
    'content': tag.content,
    'enabled': tag.enabled,
    'authorId': tag.authorId.toString(),
  };
}

Future<JsonApiResponse> mapGuildTagsToData(Snowflake guildId, int tagsLimit,
    {Map<String, String> filters = const {}, int page = 1}) async {
  final tagsModule = Injector.appInstance.get<TagModule>();

  var tags = tagsModule.getGuildTags(guildId);

  for (final entry in filters.entries) {
    switch (entry.key) {
      case 'name':
        tags = tags.where((t) => t.name.contains(entry.value));
        break;
      case 'content':
        tags = tags.where((t) => t.content.contains(entry.value));
        break;
    }
  }

  return createPaginationResponse(
    data: tags.skip(tagsLimit * (page - 1)).take(tagsLimit).map(mapGuildTag).toList(),
    total: tags.length,
    perPage: tagsLimit,
    page: page,
  );
}
