enum RowStatus { matched, different, missingInRight, missingInLeft }

class CellDiff {
  final Object? leftValue;
  final Object? rightValue;
  final bool isDifferent;

  const CellDiff({
    required this.leftValue,
    required this.rightValue,
    required this.isDifferent,
  });
}

class RowDiff {
  /// Key column name (left side name) -> key value.
  final Map<String, Object?> keyValues;
  final RowStatus status;

  /// Compare column name (left side name) -> cell diff.
  final Map<String, CellDiff> cells;

  const RowDiff({
    required this.keyValues,
    required this.status,
    required this.cells,
  });
}

class DiffSummary {
  final int total;
  final int matched;
  final int different;
  final int missingInLeft;
  final int missingInRight;
  final int duplicateKeysLeft;
  final int duplicateKeysRight;
  final bool leftTruncated;
  final bool rightTruncated;

  const DiffSummary({
    required this.total,
    required this.matched,
    required this.different,
    required this.missingInLeft,
    required this.missingInRight,
    required this.duplicateKeysLeft,
    required this.duplicateKeysRight,
    required this.leftTruncated,
    required this.rightTruncated,
  });
}

class DiffResult {
  final List<RowDiff> rows;
  final DiffSummary summary;

  const DiffResult({required this.rows, required this.summary});
}
