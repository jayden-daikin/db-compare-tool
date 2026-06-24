import '../models/comparison_config.dart';
import '../models/diff_result.dart';

/// Computes a row-by-row, cell-by-cell diff between two result sets that
/// have already been loaded into memory.
class DiffService {
  static DiffResult compare({
    required List<Map<String, Object?>> leftRows,
    required List<Map<String, Object?>> rightRows,
    required List<ColumnMapping> keyMappings,
    required List<ColumnMapping> compareMappings,
    required bool leftTruncated,
    required bool rightTruncated,
  }) {
    final leftKeyCols = keyMappings.map((m) => m.leftColumn).toList();
    final rightKeyCols = keyMappings.map((m) => m.rightColumn!).toList();

    // Index right rows by composite key (preserving duplicates in order).
    final rightIndex = <String, List<Map<String, Object?>>>{};
    for (final row in rightRows) {
      final key = _buildKey(row, rightKeyCols);
      rightIndex.putIfAbsent(key, () => []).add(row);
    }

    // Count duplicate keys on each side for the summary caveat.
    final leftKeyCounts = <String, int>{};
    for (final row in leftRows) {
      final key = _buildKey(row, leftKeyCols);
      leftKeyCounts[key] = (leftKeyCounts[key] ?? 0) + 1;
    }
    final duplicateKeysLeft = leftKeyCounts.values
        .where((c) => c > 1)
        .fold<int>(0, (sum, c) => sum + (c - 1));
    final duplicateKeysRight = rightIndex.values
        .where((list) => list.length > 1)
        .fold<int>(0, (sum, list) => sum + (list.length - 1));

    // Count how many left rows exist per key so we know when we've seen the last one.
    final leftKeyRemaining = <String, int>{};
    for (final row in leftRows) {
      final key = _buildKey(row, leftKeyCols);
      leftKeyRemaining[key] = (leftKeyRemaining[key] ?? 0) + 1;
    }

    final result = <RowDiff>[];
    int matched = 0;
    int different = 0;

    for (final leftRow in leftRows) {
      final key = _buildKey(leftRow, leftKeyCols);
      final candidates = rightIndex[key];

      final keyValues = <String, Object?>{
        for (final m in keyMappings) m.leftColumn: leftRow[m.leftColumn],
      };

      if (candidates != null && candidates.isNotEmpty) {
        final rightRow = candidates.removeAt(0);
        final cells = <String, CellDiff>{};
        var rowDifferent = false;
        for (final m in compareMappings) {
          final leftValue = leftRow[m.leftColumn];
          final rightValue = rightRow[m.rightColumn!];
          final isDifferent = leftValue != rightValue;
          if (isDifferent) rowDifferent = true;
          cells[m.leftColumn] = CellDiff(
            leftValue: leftValue,
            rightValue: rightValue,
            isDifferent: isDifferent,
          );
        }
        if (rowDifferent) {
          different++;
        } else {
          matched++;
        }
        result.add(RowDiff(
          keyValues: keyValues,
          status: rowDifferent ? RowStatus.different : RowStatus.matched,
          cells: cells,
        ));
      } else {
        final cells = <String, CellDiff>{
          for (final m in compareMappings)
            m.leftColumn: CellDiff(
              leftValue: leftRow[m.leftColumn],
              rightValue: null,
              isDifferent: false,
            ),
        };
        result.add(RowDiff(
          keyValues: keyValues,
          status: RowStatus.missingInRight,
          cells: cells,
        ));
      }

      // After the last left row for this key, flush any extra right rows for
      // the same key immediately so duplicates appear adjacent, not at the end.
      leftKeyRemaining[key] = leftKeyRemaining[key]! - 1;
      if (leftKeyRemaining[key] == 0) {
        final extra = rightIndex[key];
        if (extra != null && extra.isNotEmpty) {
          for (final rightRow in extra) {
            final extraKeyValues = <String, Object?>{
              for (final m in keyMappings)
                m.leftColumn: rightRow[m.rightColumn!],
            };
            final cells = <String, CellDiff>{
              for (final m in compareMappings)
                m.leftColumn: CellDiff(
                  leftValue: null,
                  rightValue: rightRow[m.rightColumn!],
                  isDifferent: false,
                ),
            };
            result.add(RowDiff(
              keyValues: extraKeyValues,
              status: RowStatus.missingInLeft,
              cells: cells,
            ));
          }
          rightIndex.remove(key);
        }
      }
    }

    // Any right-only keys that had no matching left row at all.
    for (final candidates in rightIndex.values) {
      for (final rightRow in candidates) {
        final keyValues = <String, Object?>{
          for (final m in keyMappings) m.leftColumn: rightRow[m.rightColumn!],
        };
        final cells = <String, CellDiff>{
          for (final m in compareMappings)
            m.leftColumn: CellDiff(
              leftValue: null,
              rightValue: rightRow[m.rightColumn!],
              isDifferent: false,
            ),
        };
        result.add(RowDiff(
          keyValues: keyValues,
          status: RowStatus.missingInLeft,
          cells: cells,
        ));
      }
    }

    final missingInRight =
        result.where((r) => r.status == RowStatus.missingInRight).length;
    final missingInLeft =
        result.where((r) => r.status == RowStatus.missingInLeft).length;

    return DiffResult(
      rows: result,
      summary: DiffSummary(
        total: result.length,
        matched: matched,
        different: different,
        missingInLeft: missingInLeft,
        missingInRight: missingInRight,
        duplicateKeysLeft: duplicateKeysLeft,
        duplicateKeysRight: duplicateKeysRight,
        leftTruncated: leftTruncated,
        rightTruncated: rightTruncated,
      ),
    );
  }

  /// Builds a composite key string from the given key columns, tagging each
  /// value with its runtime type and separating values with a control
  /// character so distinct value combinations never collide.
  static String _buildKey(Map<String, Object?> row, List<String> columns) {
    return columns.map((c) {
      final v = row[c];
      return '${v?.runtimeType}:$v';
    }).join('#|#');
  }
}
