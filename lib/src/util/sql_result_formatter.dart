import 'dart:math';
import 'package:postgres/postgres.dart';

const int _maxColumnWidth = 30;
const int _maxRowsToShow = 10;
const String _nullPlaceholder = 'NULL';

String formatSqlResult(Result result) {
  return formatTableString(result.toList(), result.schema.columns.map((c) => c.columnName ?? '?').toList());
}

String formatTableString(List<List<dynamic>> rows, List<String> columnNames) {
  if (rows.isEmpty) {
    return "No results";
  }

  final truncatedHeaders = columnNames.map(_truncate).toList();

  final truncatedRows = rows
      .map((row) => row.map((cell) => _truncate(cell?.toString() ?? _nullPlaceholder)).toList())
      .toList();

  final List<int> columnWidths = _calculateColumnWidths(truncatedHeaders, truncatedRows);

  final buffer = StringBuffer();

  _appendHeader(buffer, truncatedHeaders, columnWidths);
  _appendSeparator(buffer, columnWidths);
  _appendRows(buffer, truncatedRows, columnWidths);

  if (rows.length > _maxRowsToShow) {
    buffer.writeln('... (${rows.length - _maxRowsToShow} more rows)');
  }

  return buffer.toString();
}

List<int> _calculateColumnWidths(List<String> headers, List<List<String>> rows) {
  return List<int>.generate(headers.length, (columnIndex) {
    final headerWidth = headers[columnIndex].length;
    final cellWidths = rows.map((row) => row[columnIndex].length);

    return max(headerWidth, cellWidths.fold(0, max));
  });
}

void _appendHeader(StringBuffer buffer, List<String> headers, List<int> columnWidths) {
  buffer.write('|');

  for (int i = 0; i < headers.length; i++) {
    buffer.write(' ${headers[i].padRight(columnWidths[i])} |');
  }

  buffer.writeln();
}

void _appendSeparator(StringBuffer buffer, List<int> columnWidths) {
  buffer.write('|');

  for (final width in columnWidths) {
    buffer.write('${'-' * (width + 2)}|');
  }

  buffer.writeln();
}

void _appendRows(StringBuffer buffer, List<List<String>> rows, List<int> columnWidths) {
  for (final row in rows.take(_maxRowsToShow)) {
    buffer.write('|');

    for (int i = 0; i < row.length; i++) {
      buffer.write(' ${row[i].padRight(columnWidths[i])} |');
    }

    buffer.writeln();
  }
}

String _truncate(String text) {
  if (text.length > _maxColumnWidth) {
    return '${text.substring(0, _maxColumnWidth - 3)}...';
  }

  return text;
}
