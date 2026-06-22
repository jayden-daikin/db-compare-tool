class ColumnInfo {
  final String name;
  final String declaredType;

  const ColumnInfo({required this.name, required this.declaredType});
}

class TableSchema {
  final String tableName;
  final List<ColumnInfo> columns;
  final int rowCount;

  const TableSchema({
    required this.tableName,
    required this.columns,
    required this.rowCount,
  });

  List<String> get columnNames => columns.map((c) => c.name).toList();
}
