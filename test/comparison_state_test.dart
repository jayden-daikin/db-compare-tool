import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:db_diff_tool/state/comparison_state.dart';

void main() {
  test('runDiff computes sample comparison in a background isolate', () async {
    final state = ComparisonState();

    try {
      await state.openLeftDatabase(File('sample_data/left.db').absolute.path);
      await state.openRightDatabase(File('sample_data/right.db').absolute.path);
      state.buildInitialConfig();

      await state.runDiff();

      expect(state.errorMessage, isNull);
      expect(state.result, isNotNull);
      expect(state.result!.summary.total, greaterThan(0));
    } finally {
      state.dispose();
    }
  });
}
