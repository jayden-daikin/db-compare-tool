import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../models/comparison_config.dart';
import '../models/diff_result.dart';
import '../models/table_schema.dart';
import '../services/diff_service.dart';
import '../services/sqlite_service.dart';

/// Holds the end-to-end state for a single left/right comparison:
/// open connections, selected tables, column mappings, and the diff result.
class ComparisonState extends ChangeNotifier {
  SqliteService? _leftDb;
  SqliteService? _rightDb;

  TableSchema? leftSchema;
  TableSchema? rightSchema;

  ComparisonConfig? config;
  DiffResult? result;

  bool isLoading = false;
  bool isLeftLoading = false;
  bool isRightLoading = false;
  String? errorMessage;

  String? get leftFilePath => _leftDb?.filePath;
  String? get rightFilePath => _rightDb?.filePath;

  List<String> get leftTables => _leftDb?.listTables() ?? const [];
  List<String> get rightTables => _rightDb?.listTables() ?? const [];

  Future<void> openLeftDatabase(String filePath) async {
    isLeftLoading = true;
    errorMessage = null;
    notifyListeners();
    await _letLoadingPaint();

    try {
      _leftDb?.close();
      _leftDb = SqliteService.open(filePath);
      final tables = leftTables;
      leftSchema = tables.isNotEmpty
          ? _leftDb!.getTableSchema(tables.first)
          : null;
      _resetDownstream();
    } catch (e) {
      _leftDb?.close();
      _leftDb = null;
      leftSchema = null;
      _resetDownstream();
      errorMessage = 'Failed to open source database: $e';
    } finally {
      isLeftLoading = false;
      notifyListeners();
    }
  }

  Future<void> openRightDatabase(String filePath) async {
    isRightLoading = true;
    errorMessage = null;
    notifyListeners();
    await _letLoadingPaint();

    try {
      _rightDb?.close();
      _rightDb = SqliteService.open(filePath);
      final tables = rightTables;
      rightSchema = tables.isNotEmpty
          ? _rightDb!.getTableSchema(tables.first)
          : null;
      _resetDownstream();
    } catch (e) {
      _rightDb?.close();
      _rightDb = null;
      rightSchema = null;
      _resetDownstream();
      errorMessage = 'Failed to open target database: $e';
    } finally {
      isRightLoading = false;
      notifyListeners();
    }
  }

  void selectLeftTable(String tableName) {
    leftSchema = _leftDb!.getTableSchema(tableName);
    _resetDownstream();
    notifyListeners();
  }

  void selectRightTable(String tableName) {
    rightSchema = _rightDb!.getTableSchema(tableName);
    _resetDownstream();
    notifyListeners();
  }

  bool get canProceedToMapping => leftSchema != null && rightSchema != null;

  /// Builds the initial column mapping (auto-matching same-named columns,
  /// pre-selecting nothing) once the user moves to the mapping screen.
  void buildInitialConfig() {
    final right = rightSchema!;
    final rightNames = right.columnNames.toSet();

    final mappings = leftSchema!.columns.map((col) {
      final rightMatch = rightNames.contains(col.name) ? col.name : null;
      final isMapped = rightMatch != null;
      final lowerName = col.name.toLowerCase();
      final isKeyCol = isMapped && lowerName == 'date';
      return ColumnMapping(
        leftColumn: col.name,
        rightColumn: rightMatch,
        isKey: isKeyCol,
        isCompare: isMapped && !isKeyCol,
      );
    }).toList();

    config = ComparisonConfig(
      leftTable: leftSchema!.tableName,
      rightTable: rightSchema!.tableName,
      mappings: mappings,
    );
    result = null;
    notifyListeners();
  }

  void notifyConfigChanged() => notifyListeners();

  bool get canRunDiff =>
      config != null &&
      config!.keyMappings.isNotEmpty &&
      config!.compareMappings.isNotEmpty;

  Future<void> runDiff() async {
    final cfg = config;
    if (cfg == null) return;

    isLoading = true;
    errorMessage = null;
    result = null;
    notifyListeners();
    await _letLoadingPaint();

    try {
      final leftPath = leftFilePath;
      final rightPath = rightFilePath;
      if (leftPath == null || rightPath == null) {
        throw StateError('Select both source and target databases first.');
      }

      final keyMappings = cfg.keyMappings.map(_copyMapping).toList();
      final compareMappings = cfg.compareMappings.map(_copyMapping).toList();

      final leftColumns = <String>{
        ...keyMappings.map((m) => m.leftColumn),
        ...compareMappings.map((m) => m.leftColumn),
      }.toList();
      final rightColumns = <String>{
        ...keyMappings.map((m) => m.rightColumn!),
        ...compareMappings.map((m) => m.rightColumn!),
      }.toList();

      result = await Isolate.run(
        () => _computeDiffInBackground(
          leftFilePath: leftPath,
          rightFilePath: rightPath,
          leftTable: cfg.leftTable,
          rightTable: cfg.rightTable,
          leftColumns: leftColumns,
          rightColumns: rightColumns,
          keyMappings: keyMappings,
          compareMappings: compareMappings,
        ),
      );
    } catch (e) {
      errorMessage = 'Failed to compute diff: $e';
      result = null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _letLoadingPaint() =>
      Future<void>.delayed(const Duration(milliseconds: 16));

  ColumnMapping _copyMapping(ColumnMapping mapping) {
    return ColumnMapping(
      leftColumn: mapping.leftColumn,
      rightColumn: mapping.rightColumn,
      isKey: mapping.isKey,
      isCompare: mapping.isCompare,
    );
  }

  void _resetDownstream() {
    config = null;
    result = null;
    errorMessage = null;
  }

  @override
  void dispose() {
    _leftDb?.close();
    _rightDb?.close();
    super.dispose();
  }
}

DiffResult _computeDiffInBackground({
  required String leftFilePath,
  required String rightFilePath,
  required String leftTable,
  required String rightTable,
  required List<String> leftColumns,
  required List<String> rightColumns,
  required List<ColumnMapping> keyMappings,
  required List<ColumnMapping> compareMappings,
}) {
  final leftDb = SqliteService.open(leftFilePath);
  final rightDb = SqliteService.open(rightFilePath);

  try {
    final leftFetch = leftDb.fetchRows(
      tableName: leftTable,
      columns: leftColumns,
    );
    final rightFetch = rightDb.fetchRows(
      tableName: rightTable,
      columns: rightColumns,
    );

    return DiffService.compare(
      leftRows: leftFetch.rows,
      rightRows: rightFetch.rows,
      keyMappings: keyMappings,
      compareMappings: compareMappings,
      leftTruncated: leftFetch.truncated,
      rightTruncated: rightFetch.truncated,
    );
  } finally {
    leftDb.close();
    rightDb.close();
  }
}
