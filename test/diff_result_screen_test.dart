import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:db_diff_tool/models/comparison_config.dart';
import 'package:db_diff_tool/models/diff_result.dart';
import 'package:db_diff_tool/screens/diff_result_screen.dart';
import 'package:db_diff_tool/state/comparison_state.dart';

void main() {
  testWidgets('shows loading spinner while diff is running', (tester) async {
    final state = ComparisonState();
    state.isLoading = true;

    await tester.pumpWidget(
      ChangeNotifierProvider<ComparisonState>.value(
        value: state,
        child: const MaterialApp(home: DiffResultScreen()),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No diff result available.'), findsNothing);
  });

  testWidgets('shows rows-per-page dropdown and paginates with default 100', (
    tester,
  ) async {
    final mappings = [
      ColumnMapping(leftColumn: 'id', rightColumn: 'id', isKey: true),
      ColumnMapping(leftColumn: 'value', rightColumn: 'value', isCompare: true),
    ];
    final config = ComparisonConfig(
      leftTable: 'left_table',
      rightTable: 'right_table',
      mappings: mappings,
    );

    final rows = List.generate(
      250,
      (i) => RowDiff(
        keyValues: {'id': i},
        status: RowStatus.matched,
        cells: {
          'value': CellDiff(leftValue: i, rightValue: i, isDifferent: false),
        },
      ),
    );

    final result = DiffResult(
      rows: rows,
      summary: DiffSummary(
        total: rows.length,
        matched: rows.length,
        different: 0,
        missingInLeft: 0,
        missingInRight: 0,
        duplicateKeysLeft: 0,
        duplicateKeysRight: 0,
        leftTruncated: false,
        rightTruncated: false,
      ),
    );

    final state = ComparisonState();
    state.config = config;
    state.result = result;

    await tester.pumpWidget(
      ChangeNotifierProvider<ComparisonState>.value(
        value: state,
        child: const MaterialApp(home: DiffResultScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // Rows-per-page dropdown is present with default 100.
    expect(find.text('Rows per page'), findsOneWidget);
    expect(find.text('100'), findsWidgets);

    // With 250 rows and 100/page, pagination shows "1-100 of 250".
    expect(find.text('1-100 of 250'), findsOneWidget);

    // Next page button should be enabled; tapping it moves to page 2.
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('101-200 of 250'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Missing only view is sorted by key and renders gap cells instead of dashes',
    (tester) async {
      final mappings = [
        ColumnMapping(leftColumn: 'id', rightColumn: 'id', isKey: true),
        ColumnMapping(
          leftColumn: 'value',
          rightColumn: 'value',
          isCompare: true,
        ),
      ];
      final config = ComparisonConfig(
        leftTable: 'left_table',
        rightTable: 'right_table',
        mappings: mappings,
      );

      final rows = [
        // Only in left, higher key - should sort after the missingInLeft row.
        const RowDiff(
          keyValues: {'id': 30},
          status: RowStatus.missingInRight,
          cells: {
            'value': CellDiff(
              leftValue: 300,
              rightValue: null,
              isDifferent: false,
            ),
          },
        ),
        // Matched row - excluded from "Missing only".
        const RowDiff(
          keyValues: {'id': 20},
          status: RowStatus.matched,
          cells: {
            'value': CellDiff(
              leftValue: 200,
              rightValue: 200,
              isDifferent: false,
            ),
          },
        ),
        // Only in right, lower key - should sort first.
        const RowDiff(
          keyValues: {'id': 10},
          status: RowStatus.missingInLeft,
          cells: {
            'value': CellDiff(
              leftValue: null,
              rightValue: 100,
              isDifferent: false,
            ),
          },
        ),
      ];

      final result = DiffResult(
        rows: rows,
        summary: const DiffSummary(
          total: 3,
          matched: 1,
          different: 0,
          missingInLeft: 1,
          missingInRight: 1,
          duplicateKeysLeft: 0,
          duplicateKeysRight: 0,
          leftTruncated: false,
          rightTruncated: false,
        ),
      );

      final state = ComparisonState();
      state.config = config;
      state.result = result;

      await tester.pumpWidget(
        ChangeNotifierProvider<ComparisonState>.value(
          value: state,
          child: const MaterialApp(home: DiffResultScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Missing only'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Matched row (id 20) is excluded.
      expect(find.text('20'), findsNothing);

      // Sorted by key: id 10 (missing in left) appears above id 30 (missing in right).
      final id10Pos = tester.getTopLeft(find.text('10'));
      final id30Pos = tester.getTopLeft(find.text('30'));
      expect(id10Pos.dy, lessThan(id30Pos.dy));

      // Gap cells are blank (no dash placeholder) rather than showing '—'.
      expect(find.text('—'), findsNothing);

      // Present-side cells get a light green highlight; gap cells stay blank.
      final containers = tester.widgetList<Container>(find.byType(Container));
      final colors = containers
          .map((c) => c.color)
          .where((c) => c != null)
          .toSet();
      expect(colors, contains(Colors.green.shade50));
    },
  );

  testWidgets(
    'wide result table omits status column and renders without overflow',
    (tester) async {
      final mappings = [
        ColumnMapping(leftColumn: 'date', rightColumn: 'date', isKey: true),
        ColumnMapping(leftColumn: 'id', rightColumn: 'id', isKey: true),
        for (final name in [
          'coolp',
          'heatp',
          'sbp',
          'cl',
          'hl',
          'fp',
          'lp',
          'sp',
          'pp',
          'qp',
        ])
          ColumnMapping(leftColumn: name, rightColumn: name, isCompare: true),
      ];
      final config = ComparisonConfig(
        leftTable: 'left_table',
        rightTable: 'right_table',
        mappings: mappings,
      );

      const longDate = '20260203123456';
      final cells = {
        for (final mapping in config.compareMappings)
          mapping.leftColumn: const CellDiff(
            leftValue: 0.0,
            rightValue: 0.0,
            isDifferent: false,
          ),
      };
      final rows = List.generate(
        20,
        (i) => RowDiff(
          keyValues: {'date': longDate, 'id': i},
          status: RowStatus.matched,
          cells: cells,
        ),
      );

      final state = ComparisonState();
      state.config = config;
      state.result = DiffResult(
        rows: rows,
        summary: const DiffSummary(
          total: 20,
          matched: 20,
          different: 0,
          missingInLeft: 0,
          missingInRight: 0,
          duplicateKeysLeft: 0,
          duplicateKeysRight: 0,
          leftTruncated: false,
          rightTruncated: false,
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<ComparisonState>.value(
          value: state,
          child: const MaterialApp(home: DiffResultScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Status'), findsNothing);
      expect(find.text(longDate), findsWidgets);
    },
  );
}
