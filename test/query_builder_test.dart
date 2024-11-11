import 'package:postgres/postgres.dart';
import 'package:postgres/src/v3/query_description.dart' show SqlImpl;

import 'package:running_on_dart/src/util/query_builder.dart';
import 'package:test/test.dart';

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

      test('Join multiple conditions', () {
        final query = SelectQuery.selectAll("tag_usage", alias: "tu")
          ..addJoin('tags', 't', ['t.id = tu.command_id', 't.enabled = TRUE']);

        expect(query.build().asString(),
            "SELECT tu.* FROM tag_usage tu JOIN tags t ON t.id = tu.command_id AND t.enabled = TRUE;");
      });

      test("Simple select all with alias", () {
        final query = SelectQuery.selectAll("test", alias: 't')..andWhere("t.name = 'test'");

        expect(query.build().asString(), "SELECT t.* FROM test t WHERE t.name = 'test';");
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

    group("Delete tests", () {
      test("Simple delete", () {
        final query = DeleteQuery("test")..andWhere("name = 'test'");

        expect(query.build().asString(), "DELETE FROM test WHERE name = 'test';");
      });
    });
  });
}
