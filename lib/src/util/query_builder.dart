import 'package:postgres/postgres.dart';

class QueryBuilderException implements Exception {
  final String message;

  QueryBuilderException(this.message);

  @override
  String toString() => "QueryBuilderException: $message";
}

String buildSelects(List<String> selects) {
  if (selects.isEmpty) {
    throw QueryBuilderException("No select statements provided. Select query needs at least one select statement.");
  }

  return selects.join(",");
}

String buildWheres(List<String> wheres, String type) {
  return wheres.join(" $type ");
}

String buildSets(Map<String, String> sets) {
  return sets.entries.map((entry) => '${entry.key} = ${entry.value}').join(",");
}

(String, String) buildInsert(Map<String, String> inserts) {
  return (
    inserts.entries.map((entry) => entry.key).join(","),
    inserts.entries.map((entry) => entry.value).join(","),
  );
}

String buildReturnings(List<String> returnings) => returnings.join(",");

extension ToStringCleanStringBufferExtension on StringBuffer {
  String toStringClean() {
    return toString().split(" ").where((substr) => substr.isNotEmpty).join(" ").replaceFirst(" ;", ";");
  }
}

abstract class Query {
  final String from;
  final String? alias;

  String get aliasOrEmpty => alias ?? '';

  Query(this.from, {this.alias});

  Sql build();
}

mixin _WhereQuery implements Query {
  final List<String> _andWheres = [];
  final List<String> _orWheres = [];

  void andWhere(String expression) => _andWheres.add(expression);
  void orWhere(String expression) => _orWheres.add(expression);

  void _buildWheres(StringBuffer buffer) {
    if (_andWheres.isNotEmpty) {
      buffer.write("WHERE ");
      buffer.write(buildWheres(_andWheres, 'AND'));
    }

    if (_orWheres.isNotEmpty) {
      if (_andWheres.isEmpty) {
        buffer.write("WHERE ");
      } else {
        buffer.write("OR ");
      }
      buffer.write(buildWheres(_orWheres, "OR"));
    }
  }
}

class _Join {
  final String target;
  final String targetAlias;
  final String joinType; // LEFT JOIN, RIGHT JOIN, JOIN, OUTER JOIN
  final List<String> conditions;

  _Join(this.target, this.targetAlias, this.joinType, this.conditions);

  String build() => "$joinType $target $targetAlias ON ${buildWheres(conditions, 'AND')}";
}

class _InsertOnConflict {
  final String constraintName;
  final Map<String, String> _sets;
  final List<String> _wheres;

  _InsertOnConflict(this.constraintName, this._sets, this._wheres);

  String build() {
    if (_sets.isEmpty || _wheres.isEmpty) {
      throw QueryBuilderException("Insert on conflict cannot have empty set or where statements");
    }

    return "ON CONFLICT ON CONSTRAINT $constraintName DO UPDATE SET ${buildSets(_sets)}"
        " WHERE ${buildWheres(_wheres, 'AND')}";
  }
}

mixin _SetQuery implements Query {
  final Map<String, String> _sets = {};

  void addSet(String name, String value) => _sets[name] = value;
  void addNamedSet(String name) => _sets[name] = "@$name";
}

mixin _JoinQuery implements Query {
  final List<_Join> _joins = [];

  void addJoin(String target, String alias, List<String> conditions) =>
      _joins.add(_Join(target, alias, 'JOIN', conditions));
  void addLeftJoin(String target, String alias, List<String> conditions) =>
      _joins.add(_Join(target, alias, 'LEFT JOIN', conditions));

  void _buildJoins(StringBuffer buffer) {
    if (_joins.isEmpty) {
      return;
    }

    buffer.write(_joins.map((join) => join.build()).join(","));
  }
}

class InsertQuery extends Query {
  final Map<String, String> _inserts = {};
  final List<String> _returnings = [];
  _InsertOnConflict? _onConflict;

  InsertQuery(super.from, {super.alias});

  void addInsert(String name, String value) => _inserts[name] = value;
  void addNamedInsert(String name) => _inserts[name] = '@$name';
  void addReturning(String name) => _returnings.add(name);
  void onConflict(String constraintName, Map<String, String> sets, List<String> wheres) =>
      _onConflict = _InsertOnConflict(constraintName, sets, wheres);

  @override
  Sql build() {
    final buffer = StringBuffer("INSERT INTO $from (");

    final (fields, values) = buildInsert(_inserts);

    buffer.write(fields);
    buffer.write(") VALUES (");
    buffer.write(values);
    buffer.write(")");

    if (_onConflict != null) {
      buffer.write(" ");
      buffer.write(_onConflict!.build());
    }

    if (_returnings.isNotEmpty) {
      buffer.write(" RETURNING ");
      buffer.write(buildReturnings(_returnings));
    }

    buffer.write(";");

    return Sql.named(buffer.toStringClean());
  }
}

class UpdateQuery extends Query with _WhereQuery, _SetQuery {
  UpdateQuery(super.from, {super.alias});

  @override
  Sql build() {
    if (_andWheres.isEmpty && _orWheres.isEmpty) {
      throw QueryBuilderException("Update query requires where statement");
    }

    final buffer = StringBuffer("UPDATE $from SET ");
    buffer.write(buildSets(_sets));
    buffer.write(" ");

    _buildWheres(buffer);

    buffer.write(";");
    return Sql.named(buffer.toStringClean());
  }
}

class DeleteQuery extends Query with _WhereQuery {
  DeleteQuery(super.from);

  @override
  Sql build() {
    if (_andWheres.isEmpty && _orWheres.isEmpty) {
      throw QueryBuilderException("Delete query requires where statement");
    }

    final buffer = StringBuffer("DELETE FROM $from $aliasOrEmpty ");

    _buildWheres(buffer);
    buffer.write(";");

    return Sql.named(buffer.toStringClean());
  }
}

class SelectQuery extends Query with _WhereQuery, _JoinQuery {
  final List<String> _selects = [];

  SelectQuery(super.from, {super.alias});
  factory SelectQuery.selectAll(String from, {String? alias}) =>
      SelectQuery(from, alias: alias)..select("${alias != null ? '$alias.' : ''}*");

  void select(String expression) => _selects.add(expression);

  @override
  Sql build() {
    final buffer = StringBuffer("SELECT ");
    buffer.write(buildSelects(_selects));
    buffer.write(" FROM $from ${alias ?? ""} ");

    _buildJoins(buffer);
    buffer.write(" ");
    _buildWheres(buffer);

    buffer.write(";");

    return Sql.named(buffer.toStringClean());
  }
}
