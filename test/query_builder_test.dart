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

      test("Select without where", () {
        final query = SelectQuery("test")..select("*");

        expect(query.build().asString(),
            "SELECT * FROM test ;"); // TODO: Somehow clean up unnecessary whitespaces after building query
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
    });
  });
}
