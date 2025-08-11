import 'package:postgres/postgres.dart';
import 'package:postgres/src/v3/query_description.dart' show SqlImpl;

import 'package:running_on_dart/src/util/query_builder.dart';
import 'package:test/test.dart';

extension PostgresSqlStringExtension on Sql {
  String asString() => (this as SqlImpl).sql;
}

void main() {
  group("Query builder tests", () {
    group("Helper builder functions", () {
      test("buildSelects throws on empty list", () {
        expect(() => buildSelects([]), throwsA(isA<QueryBuilderException>()));
      });

      test("buildSelects joins with commas", () {
        expect(buildSelects(['a', 'b', 'c']), 'a,b,c');
      });

      test("buildWheres joins with AND/OR correctly", () {
        expect(buildWheres(['a=1', 'b=2'], 'AND'), 'a=1 AND b=2');
        expect(buildWheres(['a=1', 'b=2'], 'OR'), 'a=1 OR b=2');
      });

      test("buildSets formats key = value and preserves order", () {
        final sets = {'a': '@a', 'b': 'now()'};
        expect(buildSets(sets), 'a = @a,b = now()');
      });

      test("buildInsert returns fields and values preserving order", () {
        final inserts = {'a': '1', 'b': '2'};
        final res = buildInsert(inserts);
        expect(res.$1, 'a,b');
        expect(res.$2, '1,2');
      });

      test("buildReturnings comma joins", () {
        expect(buildReturnings(['id', 'name']), 'id,name');
      });

      test("toStringClean collapses spaces and fixes space before semicolon", () {
        final buf = StringBuffer('SELECT  *  FROM  t  ;');

        expect(buf.toStringClean(), 'SELECT * FROM t;');
      });
      test("toStringClean collapses multiple spaces across query (no tabs/newlines)", () {
        final buf = StringBuffer('SELECT   a   FROM    t   WHERE   x =  1   ;');
        expect(buf.toStringClean(), 'SELECT a FROM t WHERE x = 1;');
      });

      test("toStringClean keeps single spaces between tokens and removes space before semicolon", () {
        final buf = StringBuffer('INSERT  INTO  t  (a,b)  VALUES  (1,2)  ;');
        expect(buf.toStringClean(), 'INSERT INTO t (a,b) VALUES (1,2);');
      });
    });

    group("RawQuery", () {
      test("returns Sql.named with exact string", () {
        final raw = RawQuery('SELECT 1;');
        expect(raw.build().asString(), 'SELECT 1;');
      });
    });

    group("Select tests", () {
      test("Simple select", () {
        final query = SelectQuery("test")
          ..select("*")
          ..andWhere("name = 'test'");

        expect(query.build().asString(), "SELECT * FROM test WHERE name = 'test';");
      });

      test("Simple select all", () {
        final query = SelectQuery.selectAll("test")..andWhere("name = 'test'");

        expect(query.build().asString(), "SELECT * FROM test WHERE name = 'test';");
      });

      test("Select without where", () {
        final query = SelectQuery("test")..select("*");

        expect(query.build().asString(), "SELECT * FROM test;");
      });

      test("Select multiple and statements", () {
        final query = SelectQuery("test")
          ..select("*")
          ..andWhere("name = 'test'")
          ..andWhere("model = 'xg'");

        expect(query.build().asString(), "SELECT * FROM test WHERE name = 'test' AND model = 'xg';");
      });

      test("Select multiple or statements", () {
        final query = SelectQuery("test")
          ..select("*")
          ..orWhere("name = 'test'")
          ..orWhere("model = 'xg'");

        expect(query.build().asString(), "SELECT * FROM test WHERE name = 'test' OR model = 'xg';");
      });

      test("Select both AND and OR statements", () {
        final query = SelectQuery("test")
          ..select("*")
          ..andWhere("a = 1")
          ..andWhere("b = 2")
          ..orWhere("c = 3")
          ..orWhere("d = 4");

        expect(query.build().asString(), "SELECT * FROM test WHERE a = 1 AND b = 2 OR c = 3 OR d = 4;");
      });

      test("Join another table", () {
        final query = SelectQuery("test", alias: "t")
          ..select("t.*")
          ..select("ot.*")
          ..orWhere("t.name = 'test'")
          ..orWhere("t.model = 'xg'")
          ..addJoin("other_table", "ot", ["ot.id = t.test_id"])
          ..addLeftJoin("another_table", "at", ["at.test_id = t.id"]);

        expect(
          query.build().asString(),
          "SELECT t.*,ot.* FROM test t JOIN other_table ot ON ot.id = t.test_id,LEFT JOIN another_table at ON at.test_id = t.id WHERE t.name = 'test' OR t.model = 'xg';",
        );
      });

      test('Join multiple conditions', () {
        final query = SelectQuery.selectAll("tag_usage", alias: "tu")
          ..addJoin('tags', 't', ['t.id = tu.command_id', 't.enabled = TRUE']);

        expect(
          query.build().asString(),
          "SELECT tu.* FROM tag_usage tu JOIN tags t ON t.id = tu.command_id AND t.enabled = TRUE;",
        );
      });

      test("Simple select all with alias", () {
        final query = SelectQuery.selectAll("test", alias: 't')..andWhere("t.name = 'test'");

        expect(query.build().asString(), "SELECT t.* FROM test t WHERE t.name = 'test';");
      });

      test("Select build throws when no selects provided", () {
        final query = SelectQuery("test");
        expect(() => query.build().asString(), throwsA(isA<QueryBuilderException>()));
      });
    });

    group("Update tests", () {
      test("Simple update", () {
        final query = UpdateQuery("test")
          ..addSet("name", "moron")
          ..andWhere("id = 1");

        expect(query.build().asString(), "UPDATE test SET name = moron WHERE id = 1;");
      });

      test("Named sets", () {
        final query = UpdateQuery("test")
          ..addNamedSet("name")
          ..addNamedSet("model")
          ..andWhere("id = 1");

        expect(query.build().asString(), "UPDATE test SET name = @name,model = @model WHERE id = 1;");
      });

      test("Update requires where - throws", () {
        final query = UpdateQuery("test")..addSet("name", "'x'");
        expect(() => query.build().asString(), throwsA(isA<QueryBuilderException>()));
      });

      test("Update with AND and OR wheres", () {
        final query = UpdateQuery("test")
          ..addNamedSet("name")
          ..andWhere("a = 1")
          ..orWhere("b = 2");

        expect(query.build().asString(), "UPDATE test SET name = @name WHERE a = 1 OR b = 2;");
      });
    });

    group("Insert tests", () {
      test("Simple insert", () {
        final query = InsertQuery("test")
          ..addInsert("name", "moron")
          ..addNamedInsert("model");

        expect(query.build().asString(), "INSERT INTO test (name,model) VALUES (moron,@model);");
      });

      test("Insert with returning", () {
        final query = InsertQuery("test")
          ..addInsert("name", "moron")
          ..addNamedInsert("model")
          ..addReturning("id");

        expect(query.build().asString(), "INSERT INTO test (name,model) VALUES (moron,@model) RETURNING id;");
      });

      test("Insert with multiple returnings preserves order", () {
        final query = InsertQuery("test")
          ..addNamedInsert("a")
          ..addNamedInsert("b")
          ..addReturning("id")
          ..addReturning("name");

        expect(query.build().asString(), "INSERT INTO test (a,b) VALUES (@a,@b) RETURNING id,name;");
      });

      test("on conflict", () {
        final query = InsertQuery("test")
          ..addInsert("name", "moron")
          ..addNamedInsert("model")
          ..onConflict("test_constraint", {'model': "@model"}, ['id = @id'])
          ..addReturning("id");

        expect(
          query.build().asString(),
          "INSERT INTO test (name,model) VALUES (moron,@model) ON CONFLICT ON CONSTRAINT test_constraint DO UPDATE SET model = @model WHERE id = @id RETURNING id;",
        );
      });

      test("on conflict throws when sets empty", () {
        final query = InsertQuery("t")..addNamedInsert("a");
        // Build the onConflict object directly by calling onConflict with empty sets to assert throw at build time
        query.onConflict("c", {}, ['x = 1']);
        expect(() => query.build().asString(), throwsA(isA<QueryBuilderException>()));
      });

      test("on conflict throws when wheres empty", () {
        final query = InsertQuery("t")..addNamedInsert("a");
        query.onConflict("c", {'a': '@a'}, []);
        expect(() => query.build().asString(), throwsA(isA<QueryBuilderException>()));
      });

      test("Empty inserts produce empty columns and values (document current behavior)", () {
        final query = InsertQuery("t");
        expect(query.build().asString(), "INSERT INTO t () VALUES ();");
      });
    });

    group("Delete tests", () {
      test("Simple delete", () {
        final query = DeleteQuery("test")..andWhere("name = 'test'");

        expect(query.build().asString(), "DELETE FROM test WHERE name = 'test';");
      });

      test("Delete requires where - throws", () {
        final query = DeleteQuery("test");
        expect(() => query.build().asString(), throwsA(isA<QueryBuilderException>()));
      });

      test("Delete OR wheres", () {
        final query = DeleteQuery("test")
          ..orWhere("a = 1")
          ..orWhere("b = 2");
        expect(query.build().asString(), "DELETE FROM test WHERE a = 1 OR b = 2;");
      });

      test("Delete AND and OR wheres mixed", () {
        final query = DeleteQuery("test")
          ..andWhere("a = 1")
          ..andWhere("b = 2")
          ..orWhere("c = 3");
        expect(query.build().asString(), "DELETE FROM test WHERE a = 1 AND b = 2 OR c = 3;");
      });
    });
  });
}
