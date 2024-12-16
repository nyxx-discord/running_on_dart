import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/modules/tag.dart';
import 'package:running_on_dart/src/web_app/utils.dart';

Stream<JsonApiResponse> mapGuildTagsToData(Snowflake guildId, int tagsLimit) async* {
  final tagsModule = Injector.appInstance.get<TagModule>();

  for (final tag in tagsModule.getGuildTags(guildId).take(tagsLimit)) {
    yield {
      'id': tag.id,
      'name': tag.name,
      'content': tag.content,
      'enabled': tag.enabled,
      'authorId': tag.authorId.toString(),
    };
  }
}
