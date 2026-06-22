/// The role a mapped column plays in the comparison: part of the join
/// key, a column whose values are compared, or neither.
enum ColumnRole { none, key, compare }

/// Maps a column on the "left" side to a column on the "right" side
/// (by default, the right column with the same name, if one exists)
/// and tracks whether the user has marked it as a key / compare column.
class ColumnMapping {
  final String leftColumn;
  String? rightColumn;
  bool isKey;
  bool isCompare;

  ColumnMapping({
    required this.leftColumn,
    this.rightColumn,
    this.isKey = false,
    this.isCompare = false,
  });

  bool get isMapped => rightColumn != null;

  ColumnRole get role {
    if (isKey) return ColumnRole.key;
    if (isCompare) return ColumnRole.compare;
    return ColumnRole.none;
  }

  set role(ColumnRole value) {
    isKey = value == ColumnRole.key;
    isCompare = value == ColumnRole.compare;
  }
}

class ComparisonConfig {
  final String leftTable;
  final String rightTable;
  final List<ColumnMapping> mappings;

  ComparisonConfig({
    required this.leftTable,
    required this.rightTable,
    required this.mappings,
  });

  List<ColumnMapping> get keyMappings =>
      mappings.where((m) => m.isKey && m.isMapped).toList();

  List<ColumnMapping> get compareMappings =>
      mappings.where((m) => m.isCompare && m.isMapped).toList();
}
