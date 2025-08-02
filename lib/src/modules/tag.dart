import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/models/tag.dart';
import 'package:running_on_dart/src/repository/tag.dart';
import 'package:running_on_dart/src/settings.dart';

class TagModule {
  final _tagRepository = Injector.appInstance.get<TagRepository>();

  /// Create a new tag.
  Future<void> createTag(Tag tag) async {
    await _tagRepository.addTag(tag);
  }

  /// Update an existing tag.
  Future<void> updateTag(Tag tag) async {
    await _tagRepository.updateTag(tag);
  }

  /// Delete a tag.
  Future<void> deleteTag(Tag tag) async {
    await _tagRepository.deleteTag(tag);
  }

  Future<int> countTags({Snowflake? guildId}) => _tagRepository.countAllActiveTags(guildId: guildId?.toString());

  /// Get all the enabled tags in a guild.
  Future<Iterable<Tag>> getGuildTags(Snowflake guildId) =>
      _tagRepository.fetchAllActiveTags(guildId: guildId.toString());

  /// Get all the tags a user owns or can manage.
  Future<Iterable<Tag>> getOwnedTags(Snowflake guildId, Snowflake userId) async {
    if (adminIds.contains(userId)) {
      return _tagRepository.fetchAllActiveTags(guildId: guildId.toString());
    }

    return _tagRepository.fetchAllActiveTags(guildId: guildId.toString(), userId: userId.toString());
  }

  Future<Iterable<Tag>> findAll(Snowflake guildId, [Snowflake? userId]) {
    if (userId == null) {
      return getGuildTags(guildId);
    }

    return getOwnedTags(guildId, userId);
  }

  /// Search the tags in a guild, or the tags a user can manage if [userId] is set.
  Future<Iterable<Tag>> search(String query, Snowflake guildId, [Snowflake? userId]) async {
    return _tagRepository.searchActiveTags(query: query, guildId: guildId.toString(), authorId: userId?.toString());
  }

  /// Get a tag by name.
  Future<Tag?> getByName(Snowflake guildId, String name) async {
    final results = await _tagRepository.fetchAllActiveTags(guildId: guildId.toString(), name: name);

    return results.firstOrNull;
  }

  Future<Iterable<(TagUsedEvent, Tag)>> getTagUsage(Snowflake guildId, [Tag? tag]) {
    return _tagRepository.fetchTagUsage(guildId: guildId.toString(), tagId: tag?.id);
  }

  Future<void> registerTagUsedEvent(TagUsedEvent event) async {
    await _tagRepository.registerTagUsedEvent(event);
  }
}
