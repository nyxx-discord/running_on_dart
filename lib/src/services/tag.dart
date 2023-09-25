import 'package:fuzzy/fuzzy.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/models/tag.dart';

class TagService {
  static TagService get instance =>
      _instance ??
      (throw Exception(
          'TagService must be initialised with TagService.init()'));
  static TagService? _instance;

  final List<Tag> tags = [];
  final List<TagUsedEvent> usedEvents = [];

  static void init() {
    _instance = TagService._();
  }

  TagService._() {
    DatabaseService.instance.fetchTags().then((tags) => this.tags.addAll(tags));
    DatabaseService.instance
        .fetchTagUsage()
        .then((events) => usedEvents.addAll(events));
  }

  /// Create a new tag.
  Future<void> createTag(Tag tag) async {
    await DatabaseService.instance.addTag(tag);

    tags.add(tag);
  }

  /// Update an existing tag.
  Future<void> updateTag(Tag tag) async {
    await DatabaseService.instance.updateTag(tag);
  }

  /// Delete a tag.
  Future<void> deleteTag(Tag tag) async {
    await DatabaseService.instance.deleteTag(tag);

    tags.remove(tag);
  }

  /// Get all the enabled tags in a guild.
  Iterable<Tag> getGuildTags(Snowflake guildId) =>
      tags.where((tag) => tag.guildId == guildId && tag.enabled);

  /// Get all the tags a user owns or can manage.
  Iterable<Tag> getOwnedTags(Snowflake guildId, Snowflake userId) =>
      tags.where((tag) =>
          tag.guildId == guildId &&
          (tag.authorId == userId || adminIds.contains(userId)));

  /// Search the tags in a guild, or the tags a user can manage if [userId] is set.
  Iterable<Tag> search(String query, Snowflake guildId, [Snowflake? userId]) {
    Iterable<Tag> allTags;
    if (userId == null) {
      allTags = getGuildTags(guildId);
    } else {
      allTags = getOwnedTags(guildId, userId);
    }

    final results = Fuzzy<Tag>(
      allTags.toList(),
      options: FuzzyOptions(
        keys: [
          WeightedKey(
            name: 'name',
            getter: (tag) => tag.name,
            weight: 5,
          ),
          WeightedKey(
            name: 'content',
            getter: (tag) => tag.content,
            weight: 1,
          ),
        ],
      ),
    ).search(query);

    return results.map((result) => result.item);
  }

  /// Get a tag by name.
  Tag? getByName(Snowflake guildId, String name) => tags
      .where((tag) => tag.guildId == guildId && tag.name == name)
      .cast<Tag?>()
      .followedBy([null]).first;

  Tag? getById(int id) =>
      tags.where((tag) => tag.id == id).cast<Tag?>().followedBy([null]).first;

  Iterable<TagUsedEvent> getTagUsage(Snowflake guildId, [Tag? tag]) {
    return usedEvents.where((event) {
      if (tag != null && event.tagId != tag.id) {
        return false;
      }

      final fetchedTag = getById(event.tagId);

      return fetchedTag?.guildId == guildId && fetchedTag?.enabled == true;
    });
  }

  Future<void> registerTagUsedEvent(TagUsedEvent event) async {
    await DatabaseService.instance.registerTagUsedEvent(event);

    usedEvents.add(event);
  }
}
