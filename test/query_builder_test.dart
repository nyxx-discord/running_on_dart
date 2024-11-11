import 'package:postgres/postgres.dart';
import 'package:postgres/src/v3/query_description.dart' show SqlImpl;

import 'package:running_on_dart/src/util/query_builder.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

extension PostgresSqlStringExtension on Sql {
  String asString() => (this as SqlImpl).sql;
}

void main() {
  group("Query builder tests", () {
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

      test("Join another table", () {
        final query = SelectQuery("test", alias: "t")
          ..select("t.*")
          ..select("ot.*")
          ..orWhere("t.name = 'test'")
          ..orWhere("t.model = 'xg'")
          ..addJoin("other_table", "ot", ["ot.id = t.test_id"])
          ..addLeftJoin("another_table", "at", ["at.test_id = t.id"]);

        expect(query.build().asString(),
            "SELECT t.*,ot.* FROM test t JOIN other_table ot ON ot.id = t.test_id,LEFT JOIN another_table at ON at.test_id = t.id WHERE t.name = 'test' OR t.model = 'xg';");
      });
    });

    group("Update tests", () {
      test("Simple update", () {
        final query = UpdateQuery("test")
          ..addSet("name", "moron")
          ..andWhere("id = 1");

        expect(query.build().asString(), "UPDATE test SET name = moron WHERE id = 1;");
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
    });
  });
}
