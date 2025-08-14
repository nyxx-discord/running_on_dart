import 'package:injector/injector.dart';
import 'package:logging/logging.dart';
import 'package:running_on_dart/src/models/tag.dart';
import 'package:running_on_dart/src/services/db.dart';
import 'package:running_on_dart/src/util/query_builder.dart';

class TagRepository {
  final _database = Injector.appInstance.get<DatabaseService>();

  final Logger _logger = Logger('ROD.TagRepository');

  /// Fetch all existing tags from the database.
  Future<Iterable<Tag>> fetchAllActiveTags({String? guildId, String? userId, String? name}) async {
    final query = SelectQuery.selectAll('tags')..andWhere('enabled = TRUE');
    final parameters = <String, dynamic>{};

    if (guildId != null) {
      query.andWhere('guild_id = @guildId');
      parameters.addAll({'guildId': guildId});
    }

    if (userId != null) {
      query.andWhere('author_id = @userId');
      parameters.addAll({'userId': userId});
    }

    if (name != null) {
      query.andWhere('name LIKE @nameQuery');
      parameters.addAll({'nameQuery': '%$name%'});
    }

    final result = await _database.executeQuery(query, parameters: parameters);

    return result.map((row) => row.toColumnMap()).map(Tag.fromRow);
  }

  Future<int> countAllActiveTags({String? guildId}) async {
    final query = SelectQuery('tags')
      ..select('COUNT(*) as count_tags')
      ..andWhere('enabled = TRUE');

    final parameters = <String, dynamic>{};
    if (guildId != null) {
      query.andWhere('guild_id = @guildId');
      parameters.addAll({'guildId': guildId});
    }

    final result = await _database.executeQuery(query, parameters: parameters);

    return result.first.toColumnMap()['count_tags'] ?? 0;
  }

  Future<Tag?> fetchRandomActiveTag({required String guildId}) async {
    final query = SelectQuery.selectAll('tags')
      ..andWhere('enabled = TRUE')
      ..andWhere('guild_id = @guildId')
      ..orderBy('random()')
      ..limit(1);

    final params = <String, dynamic>{"guildId": guildId};

    final result = await _database.executeQuery(query, parameters: params);
    if (result.isEmpty) {
      return null;
    }

    return Tag.fromRow(result.first.toColumnMap());
  }

  Future<Iterable<Tag>> searchActiveTags({
    required String query,
    int limit = 25,
    int offset = 0,
    double similarityThreshold = 0.1,
    String? authorId,
    String? guildId,
  }) async {
    final raw = RawQuery(r'''
SELECT id, name, content, enabled, guild_id, author_id
FROM (
  SELECT
    id, name, content, enabled, guild_id, author_id,
    (similarity(name, @q) * 5.0 + similarity(content, @q) * 1.0) AS score
  FROM tags
  WHERE enabled = TRUE
    AND (@authorId::text IS NULL OR author_id::text = @authorId)
    AND (@guildId::text IS NULL OR guild_id::text = @guildId)
    AND (
      name ILIKE '%' || @q || '%'
      OR content ILIKE '%' || @q || '%'
      OR name % @q
      OR content % @q
    )
) s
WHERE score >= @simThresh
ORDER BY score DESC, name ASC
LIMIT @limit OFFSET @offset
''');

    final result = await _database.executeQuery(
      raw,
      parameters: {
        'q': query,
        'limit': limit,
        'offset': offset,
        'simThresh': similarityThreshold,
        'authorId': authorId,
        'guildId': guildId,
      },
    );

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

    final result = await _database.executeQuery(
      query,
      parameters: {
        'name': tag.name,
        'content': tag.content,
        'enabled': tag.enabled,
        'guild_id': tag.guildId.toString(),
        'author_id': tag.authorId.toString(),
      },
    );

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

    await _database.executeQuery(
      query,
      parameters: {
        'id': tag.id,
        'name': tag.name,
        'content': tag.content,
        'enabled': tag.enabled,
        'guild_id': tag.guildId.toString(),
        'author_id': tag.authorId.toString(),
      },
    );
  }

  Future<Iterable<(TagUsedEvent, Tag)>> fetchTagUsage({String? guildId, int? tagId}) async {
    final query = SelectQuery.selectAll("tag_usage", alias: "tu")
      ..select('t.*')
      ..addJoin('tags', 't', ['t.id = tu.command_id', 't.enabled = TRUE']);

    final parameters = <String, dynamic>{};

    if (guildId != null) {
      query.andWhere('t.guild_id = @guildId');
      parameters.addAll({'guildId': guildId});
    }

    if (tagId != null) {
      query.andWhere('t.id = @tagId');
      parameters.addAll({'tagId': tagId});
    }

    final result = await _database.executeQuery(query, parameters: parameters);

    return result.map((row) => row.toColumnMap()).map((row) => (TagUsedEvent.fromRow(row), Tag.fromRow(row)));
  }

  Future<void> registerTagUsedEvent(TagUsedEvent event) async {
    final query = InsertQuery("tag_usage")
      ..addNamedInsert("command_id")
      ..addNamedInsert("use_date")
      ..addNamedInsert("hidden");

    await _database.executeQuery(
      query,
      parameters: {'command_id': event.tagId, 'use_date': event.usedAt, 'hidden': event.hidden},
    );
  }
}
