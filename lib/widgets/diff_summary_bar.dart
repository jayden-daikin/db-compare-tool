import 'package:flutter/material.dart';

import '../models/diff_result.dart';

/// Shows counts of matched / different / missing rows, plus any
/// truncation or duplicate-key caveats.
class DiffSummaryBar extends StatelessWidget {
  final DiffSummary summary;

  const DiffSummaryBar({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _stat('Total', summary.total, Colors.black87),
        _stat('Match', summary.matched, Colors.green),
        _stat('Different', summary.different, Colors.orange.shade800),
        _stat('Only in Source', summary.missingInRight, Colors.red),
        _stat('Only in Target', summary.missingInLeft, Colors.blue),
        if (summary.leftTruncated)
          _warning('Source table truncated to row limit'),
        if (summary.rightTruncated)
          _warning('Target table truncated to row limit'),
      ],
    );
  }

  Widget _stat(String label, int value, Color color) {
    return Text(
      '$label: $value',
      style: TextStyle(color: color, fontWeight: FontWeight.bold),
    );
  }

  Widget _warning(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.orange)),
      ],
    );
  }
}
