import 'package:test/test.dart';
import 'package:running_on_dart/src/util/sql_result_formatter.dart';

void main() {
  group('formatTableString', () {
    test('returns "No results" for empty rows', () {
      final result = formatTableString([], ['Column1', 'Column2']);
      expect(result, equals('No results'));
    });

    test('formats basic table correctly', () {
      final rows = [
        ['Alice', 30],
        ['Bob', 25],
      ];
      final columnNames = ['Name', 'Age'];

      final result = formatTableString(rows, columnNames);

      expect(
        result,
        equals(
          '| Name  | Age |\n'
          '|-------|-----|\n'
          '| Alice | 30  |\n'
          '| Bob   | 25  |\n',
        ),
      );
    });

    test('calculates column widths correctly', () {
      final rows = [
        ['Short', 'Very long value that exceeds max width'],
        ['Another value', 'Short'],
      ];
      final columnNames = ['Header1', 'Header2'];

      final result = formatTableString(rows, columnNames);

      // Header1 width = max("Header1".length, "Short".length, "Another value".length) = 13
      // Header2 width = max("Header2".length, truncated "Very long value ..." (30), "Short".length) = 30
      expect(result, contains('| Header1       | Header2                        |'));
      expect(result, contains('| Short         | Very long value that exceed... |'));
      expect(result, contains('| Another value | Short                          |'));
    });

    test('truncates long values with ellipsis', () {
      final longString = 'This is a very long string that needs to be truncated to fit in the column';
      final rows = [
        [longString],
      ];
      final columnNames = ['LongColumn'];

      final result = formatTableString(rows, columnNames);

      expect(result, contains('This is a very long string ...'));
      expect(result, contains('| LongColumn                     |'));
    });

    test('handles null values as "NULL"', () {
      final rows = [
        [null, 'Valid'],
        ['Valid', null],
      ];
      final columnNames = ['Column1', 'Column2'];

      final result = formatTableString(rows, columnNames);

      expect(result, contains('| NULL    | Valid   |'));
      expect(result, contains('| Valid   | NULL    |'));
    });

    test('limits displayed rows to 10 with overflow message', () {
      final rows = List.generate(15, (index) => ['Row ${index + 1}']);
      final columnNames = ['Data'];

      final result = formatTableString(rows, columnNames);

      // Should show 10 rows + overflow message
      final lines = result.split('\n');
      expect(lines.length, 14); // Header + separator + 10 rows + message + empty line
      expect(result, contains('... (5 more rows)'));
    });
  });
}
