import 'package:injector/injector.dart';
import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/models/tag.dart';

class TagRepository {
  final _database = Injector.appInstance.get<DatabaseService>();

  final Logger _logger = Logger('ROD.TagRepository');

  /// Fetch all existing tags from the database.
  Future<Iterable<Tag>> fetchAllActiveTags() async {
    final result = await _database.getConnection().execute(Sql.named('''
      SELECT * FROM tags WHERE enabled = TRUE;
    '''));

    return result.map((row) => row.toColumnMap()).map(Tag.fromRow);
  }

  Future<Iterable<Tag>> fetchActiveTagsByName(String nameQuery) async {
    final result = await _database.getConnection().execute(Sql.named('''
      SELECT * FROM tags WHERE enabled = TRUE AND name LIKE @nameQuery;
    '''), parameters: {'nameQuery': '%$nameQuery%'});

    return result.map((row) => row.toColumnMap()).map(Tag.fromRow);
  }

  /// Delete a tag from the database.
  Future<void> deleteTag(Tag tag) async {
    final id = tag.id;

    if (id == null) {
      return;
    }

    await _database.getConnection().execute(Sql.named('''
      UPDATE tags SET enabled = FALSE WHERE id = @id;
    '''), parameters: {
      'id': id,
    });
  }

  /// Add a tag to the database.
  Future<void> addTag(Tag tag) async {
    if (tag.id != null) {
      _logger.warning('Attempting to add tag with id ${tag.id} twice, ignoring');
      return;
    }

    final result = await _database.getConnection().execute(Sql.named('''
    INSERT INTO tags (
      name,
      content,
      enabled,
      guild_id,
      author_id
    ) VALUES (
      @name,
      @content,
      @enabled,
      @guild_id,
      @author_id
    ) RETURNING id;
  '''), parameters: {
      'name': tag.name,
      'content': tag.content,
      'enabled': tag.enabled,
      'guild_id': tag.guildId.toString(),
      'author_id': tag.authorId.toString(),
    });

    tag.id = result.first.first as int;
  }

  /// Update a tag in the database.
  Future<void> updateTag(Tag tag) async {
    if (tag.id == null) {
      return addTag(tag);
    }

    await _database.getConnection().execute(Sql.named('''
      UPDATE tags SET
        name = @name,
        content = @content,
        enabled = @enabled,
        guild_id = @guild_id,
        author_id = @author_id
      WHERE
        id = @id
    '''), parameters: {
      'id': tag.id,
      'name': tag.name,
      'content': tag.content,
      'enabled': tag.enabled,
      'guild_id': tag.guildId.toString(),
      'author_id': tag.authorId.toString(),
    });
  }

  Future<Iterable<TagUsedEvent>> fetchTagUsage() async {
    final result = await _database.getConnection().execute(Sql.named('''
      SELECT tu.* FROM tag_usage tu JOIN tags t ON t.id = tu.command_id AND t.enabled = TRUE;
    '''));

    return result.map((row) => row.toColumnMap()).map(TagUsedEvent.fromRow);
  }

  Future<void> registerTagUsedEvent(TagUsedEvent event) async {
    await _database.getConnection().execute(Sql.named('''
      INSERT INTO tag_usage (
        command_id,
        use_date,
        hidden
      ) VALUES (
        @tag_id,
        @use_date,
        @hidden
      )
    '''), parameters: {
      'tag_id': event.tagId,
      'use_date': event.usedAt,
      'hidden': event.hidden,
    });
  }
}
