import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/comparison_config.dart';
import '../models/diff_result.dart';
import '../state/comparison_state.dart';
import '../widgets/diff_summary_bar.dart';
import '../widgets/diff_table.dart';
import '../widgets/framed_field.dart';

enum _DiffFilter { all, differencesOnly, missingOnly }

const List<int> _kRowsPerPageOptions = [
  10,
  20,
  50,
  100,
  500,
  1000,
  5000,
  10000,
];
const int _kDefaultRowsPerPage = 100;

class DiffResultScreen extends StatefulWidget {
  final bool runOnOpen;

  const DiffResultScreen({super.key, this.runOnOpen = false});

  @override
  State<DiffResultScreen> createState() => _DiffResultScreenState();
}

class _DiffResultScreenState extends State<DiffResultScreen> {
  _DiffFilter _filter = _DiffFilter.all;
  int _rowsPerPage = _kDefaultRowsPerPage;
  int _currentPage = 0;
  bool _startedRun = false;

  @override
  void initState() {
    super.initState();
    if (widget.runOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _startedRun) return;
        _startedRun = true;
        context.read<ComparisonState>().runDiff();
      });
    }
  }

  List<RowDiff> _applyFilter(List<RowDiff> rows, ComparisonConfig config) {
    switch (_filter) {
      case _DiffFilter.all:
        return rows;
      case _DiffFilter.differencesOnly:
        return rows.where((r) => r.status == RowStatus.different).toList();
      case _DiffFilter.missingOnly:
        final missing = rows
            .where(
              (r) =>
                  r.status == RowStatus.missingInLeft ||
                  r.status == RowStatus.missingInRight,
            )
            .toList();
        final keyCols = config.keyMappings.map((m) => m.leftColumn).toList();
        missing.sort((a, b) {
          for (final col in keyCols) {
            final cmp = _compareKeyValues(a.keyValues[col], b.keyValues[col]);
            if (cmp != 0) return cmp;
          }
          return 0;
        });
        return missing;
    }
  }

  int _compareKeyValues(Object? a, Object? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    if (a is Comparable && b is Comparable && a.runtimeType == b.runtimeType) {
      return a.compareTo(b);
    }
    return a.toString().compareTo(b.toString());
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ComparisonState>();
    final result = state.result;
    final config = state.config;

    return Scaffold(
      appBar: AppBar(title: const Text('Compare Result')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.errorMessage != null
          ? Center(child: Text(state.errorMessage!))
          : result == null || config == null
          ? const Center(child: Text('No diff result available.'))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: _buildBody(state, config, result),
            ),
    );
  }

  Widget _buildBody(
    ComparisonState state,
    ComparisonConfig config,
    DiffResult result,
  ) {
    final filteredRows = _applyFilter(result.rows, config);

    final bool hasPagination = filteredRows.isNotEmpty;
    int currentPage = 0;
    int start = 0;
    int end = filteredRows.length;
    List<RowDiff> pageRows = filteredRows;

    if (hasPagination) {
      final totalPages = (filteredRows.length / _rowsPerPage).ceil();
      currentPage = _currentPage.clamp(0, totalPages - 1);
      start = currentPage * _rowsPerPage;
      end = (start + _rowsPerPage).clamp(0, filteredRows.length);
      pageRows = filteredRows.sublist(start, end);
    }

    final totalPages = hasPagination
        ? (filteredRows.length / _rowsPerPage).ceil()
        : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: summary metrics (left) | rows per page (right)
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: DiffSummaryBar(summary: result.summary)),
            SizedBox(
              width: 160,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InputDecorator(
                  decoration: framedDropdownDecoration('Rows per page'),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _rowsPerPage,
                      isDense: true,
                      isExpanded: true,
                      focusColor: Colors.transparent,
                      items: _kRowsPerPageOptions
                          .map(
                            (v) =>
                                DropdownMenuItem(value: v, child: Text('$v')),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        FocusScope.of(context).unfocus();
                        setState(() {
                          _rowsPerPage = v;
                          _currentPage = 0;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Row 2: filter buttons (left) | pagination (right)
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: IntrinsicWidth(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: SegmentedButton<_DiffFilter>(
                      segments: const [
                        ButtonSegment(
                          value: _DiffFilter.all,
                          label: Text('All'),
                        ),
                        ButtonSegment(
                          value: _DiffFilter.differencesOnly,
                          label: Text('Differences only'),
                        ),
                        ButtonSegment(
                          value: _DiffFilter.missingOnly,
                          label: Text('Missing only'),
                        ),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _filter = selection.first;
                          _currentPage = 0;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ),
            if (hasPagination) ...[
              IconButton(
                icon: const Icon(Icons.first_page),
                tooltip: 'First page',
                onPressed: currentPage > 0
                    ? () => setState(() => _currentPage = 0)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: currentPage > 0
                    ? () => setState(() => _currentPage = currentPage - 1)
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '${start + 1}-$end of ${filteredRows.length}',
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: currentPage < totalPages - 1
                    ? () => setState(() => _currentPage = currentPage + 1)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.last_page),
                tooltip: 'Last page',
                onPressed: currentPage < totalPages - 1
                    ? () => setState(() => _currentPage = totalPages - 1)
                    : null,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        // Table
        Expanded(
          child: filteredRows.isEmpty
              ? const Center(child: Text('No rows match the current filter.'))
              : DiffTable(
                  rows: pageRows,
                  config: config,
                  leftFilePath: state.leftFilePath,
                  rightFilePath: state.rightFilePath,
                ),
        ),
      ],
    );
  }
}
