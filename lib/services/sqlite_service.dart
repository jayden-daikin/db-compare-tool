import 'package:sqlite3/sqlite3.dart';

import '../models/table_schema.dart';

/// Thin wrapper around a read-only SQLite connection plus helpers for
/// inspecting schema and pulling rows for comparison.
class SqliteService {
  final Database database;
  final String filePath;

  SqliteService._(this.database, this.filePath);

  static SqliteService open(String filePath) {
    final db = sqlite3.open(filePath, mode: OpenMode.readOnly);
    return SqliteService._(db, filePath);
  }

  void close() => database.dispose();

  /// Returns the names of all user tables (excluding sqlite internal tables).
  List<String> listTables() {
    final result = database.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    return result.map((row) => row['name'] as String).toList();
  }

  /// Returns the schema (column names + declared types) and row count for [tableName].
  TableSchema getTableSchema(String tableName) {
    final colResult =
        database.select('PRAGMA table_info(${_quoteIdent(tableName)})');
    final columns = colResult
        .map((row) => ColumnInfo(
              name: row['name'] as String,
              declaredType: (row['type'] as String?)?.isNotEmpty == true
                  ? row['type'] as String
                  : 'UNKNOWN',
            ))
        .toList();
    final countResult = database
        .select('SELECT COUNT(*) AS n FROM ${_quoteIdent(tableName)}');
    final rowCount = countResult.first['n'] as int;
    return TableSchema(
        tableName: tableName, columns: columns, rowCount: rowCount);
  }

  /// Fetches all rows for [columns] of [tableName].
  ({List<Map<String, Object?>> rows, bool truncated}) fetchRows({
    required String tableName,
    required List<String> columns,
  }) {
    final columnList = columns.map(_quoteIdent).join(', ');
    final sql = 'SELECT $columnList FROM ${_quoteIdent(tableName)}';
    final result = database.select(sql);
    final rows = result.map((row) => Map<String, Object?>.from(row)).toList();
    return (rows: rows, truncated: false);
  }

  static String _quoteIdent(String ident) => '"${ident.replaceAll('"', '""')}"';
}
