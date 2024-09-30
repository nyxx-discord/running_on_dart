import 'package:nyxx/nyxx.dart';

/// A simple tag with name and content.
class Tag {
  /// The name of this tag.
  final String name;

  /// The content of this tag.
  final String content;

  /// Whether the tag  is enabled.
  bool enabled;

  /// The ID of the guild this tag belongs to.
  final Snowflake guildId;

  /// The ID of the user this tag belongs to.
  final Snowflake authorId;

  /// The id of this tag, or `null` if this tag has not been inserted into the database.
  int? id;

  /// Create a new [Tag].
  Tag({
    required this.name,
    required this.content,
    required this.enabled,
    required this.guildId,
    required this.authorId,
    this.id,
  });

  /// Create a [Tag] from a database row.
  factory Tag.fromRow(Map<String, dynamic> row) {
    return Tag(
      name: row['name'] as String,
      content: row['content'] as String,
      enabled: row['enabled'] as bool,
      guildId: Snowflake.parse(row['guild_id'] as String),
      authorId: Snowflake.parse(row['author_id'] as String),
      id: row['id'] as int,
    );
  }
}

class TagUsedEvent {
  final int tagId;
  final DateTime usedAt;
  final bool hidden;

  TagUsedEvent({
    required this.tagId,
    required this.usedAt,
    required this.hidden,
  });

  factory TagUsedEvent.fromTag({
    required Tag tag,
    required bool hidden,
  }) =>
      TagUsedEvent(
        tagId: tag.id!,
        usedAt: DateTime.now(),
        hidden: hidden,
      );

  factory TagUsedEvent.fromRow(Map<String, dynamic> row) {
    return TagUsedEvent(
      tagId: row['command_id'] as int,
      usedAt: row['use_date'] as DateTime,
      hidden: row['hidden'] as bool,
    );
  }
}
