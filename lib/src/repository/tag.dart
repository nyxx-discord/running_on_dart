import 'package:injector/injector.dart';
import 'package:logging/logging.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/models/tag.dart';
import 'package:running_on_dart/src/util/query_builder.dart';

class TagRepository {
  final _database = Injector.appInstance.get<DatabaseService>();

  final Logger _logger = Logger('ROD.TagRepository');

  /// Fetch all existing tags from the database.
  Future<Iterable<Tag>> fetchAllActiveTags() async {
    final query = SelectQuery.selectAll('tags')..andWhere('enabled = TRUE');

    final result = await _database.executeQuery(query);

    return result.map((row) => row.toColumnMap()).map(Tag.fromRow);
  }

  Future<Iterable<Tag>> fetchActiveTagsByName(String nameQuery) async {
    final query = SelectQuery.selectAll("tags")
      ..andWhere("enabled = TRUE")
      ..andWhere("name LIKE @nameQuery");

    final result = await _database.executeQuery(query, parameters: {'nameQuery': '%$nameQuery%'});

    return result.map((row) => row.toColumnMap()).map(Tag.fromRow);
  }

  /// Delete a tag from the database.
  Future<void> deleteTag(Tag tag) async {
    final id = tag.id;

    if (id == null) {
      return;
    }

    final query = UpdateQuery("tags")
      ..addSet("enabled", "FALSE")
      ..andWhere("id = @id");

    await _database.executeQuery(query, parameters: {'id': id});
  }

  /// Add a tag to the database.
  Future<void> addTag(Tag tag) async {
    if (tag.id != null) {
      _logger.warning('Attempting to add tag with id ${tag.id} twice, ignoring');
      return;
    }

    final query = InsertQuery("tags")
      ..addNamedInsert("name")
      ..addNamedInsert("content")
      ..addNamedInsert("enabled")
      ..addNamedInsert("guild_id")
      ..addNamedInsert("author_id")
      ..addReturning("id");

    final result = await _database.executeQuery(query, parameters: {
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

    final query = UpdateQuery("tags")
      ..addNamedSet('name')
      ..addNamedSet('content')
      ..addNamedSet('enabled')
      ..addNamedSet('guild_id')
      ..addNamedSet('author_id')
      ..andWhere("id = @id");

    await _database.executeQuery(query, parameters: {
      'id': tag.id,
      'name': tag.name,
      'content': tag.content,
      'enabled': tag.enabled,
      'guild_id': tag.guildId.toString(),
      'author_id': tag.authorId.toString(),
    });
  }

  Future<Iterable<TagUsedEvent>> fetchTagUsage() async {
    final query = SelectQuery.selectAll("tag_usage", alias: "tu")
      ..addJoin('tags', 't', ['t.id = tu.command_id', 't.enabled = TRUE']);

    final result = await _database.executeQuery(query);

    return result.map((row) => row.toColumnMap()).map(TagUsedEvent.fromRow);
  }

  Future<void> registerTagUsedEvent(TagUsedEvent event) async {
    final query = InsertQuery("tag_usage")
      ..addNamedInsert("command_id")
      ..addNamedInsert("use_date")
      ..addNamedInsert("hidden");

    await _database.executeQuery(query, parameters: {
      'command_id': event.tagId,
      'use_date': event.usedAt,
      'hidden': event.hidden,
    });
  }
}
