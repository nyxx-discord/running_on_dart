import 'package:fuzzy/data/result.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/models/tag.dart';

import 'db.dart' as database;

final List<Tag> tags = [];

/// Initialise the tags service.
Future<void> initTags() async {
  for (final tag in await database.fetchTags()) {
    tags.add(tag);
  }
}

/// Create a new tag.
Future<void> createTag(Tag tag) async {
  await database.addTag(tag);

  tags.add(tag);
}

/// Update an existing tag.
Future<void> updateTag(Tag tag) async {
  await database.updateTag(tag);
}

/// Delete a tag.
Future<void> deleteTag(Tag tag) async {
  await database.deleteTag(tag);

  tags.remove(tag);
}

/// Get all the enabled tags in a guild.
Iterable<Tag> getGuildTags(Snowflake guildId) => tags.where((tag) => tag.guildId == guildId && tag.enabled);

/// Get all the tags a user owns or can manage.
Iterable<Tag> getOwnedTags(Snowflake guildId, Snowflake userId) =>
    tags.where((tag) => tag.guildId == guildId && (tag.authorId == userId || adminIds.contains(userId)));

/// Search the tags in a guild, or the tags a user can manage if [userId] is set.
Iterable<Tag> searchTags(String query, Snowflake guildId, [Snowflake? userId]) {
  Iterable<Tag> allTags;
  if (userId == null) {
    allTags = getGuildTags(guildId);
  } else {
    allTags = getOwnedTags(guildId, userId);
  }

  List<Result<Tag>> results = Fuzzy<Tag>(
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
Tag? getByName(Snowflake guildId, String name) => tags.where((tag) => tag.guildId == guildId && tag.name == name).cast<Tag?>().followedBy([null]).first;
