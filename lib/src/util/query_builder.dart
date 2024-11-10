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

abstract class Query {
  final String from;

  Query(this.from);

  Sql build();
}

abstract class _WhereQuery extends Query {
  final List<String> _andWheres = [];
  final List<String> _orWheres = [];

  _WhereQuery(super.from);

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

class UpdateQuery extends _WhereQuery {
  final Map<String, String> _sets = {};

  UpdateQuery(super.from);

  void addSet(String name, String value) => _sets[name] = value;

  @override
  Sql build() {
    if (_andWheres.isEmpty && _orWheres.isEmpty) {
      throw QueryBuilderException("Update query requires where statement");
    }

    final buffer = StringBuffer("UPDATE $from SET ");
    buffer.write(buildSets);

    _buildWheres(buffer);

    buffer.write(";");
    return Sql.named(buffer.toString());
  }
}

class SelectQuery extends _WhereQuery {
  final List<String> _selects = [];

  SelectQuery(super.from);
  factory SelectQuery.selectAll(String from) => SelectQuery(from)..select("*");

  void select(String expression) => _selects.add(expression);

  @override
  Sql build() {
    final buffer = StringBuffer("SELECT ");
    buffer.write(buildSelects(_selects));
    buffer.write(" FROM $from ");

    _buildWheres(buffer);

    buffer.write(";");

    return Sql.named(buffer.toString());
  }
}
