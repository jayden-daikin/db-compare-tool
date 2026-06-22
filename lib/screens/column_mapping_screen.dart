import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/comparison_state.dart';
import '../widgets/column_mapping_row.dart';
import 'diff_result_screen.dart';

class ColumnMappingScreen extends StatelessWidget {
  const ColumnMappingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ComparisonState>();
    final config = state.config!;
    final leftSchema = state.leftSchema!;
    final rightColumns = state.rightSchema!.columnNames;

    final hasKey = config.keyMappings.isNotEmpty;
    final hasCompare = config.compareMappings.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Map Columns')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Source table: ${config.leftTable}   →   Target table: ${config.rightTable}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'For each source column, choose the matching target column (if any), '
              'then choose whether it forms the join "Key" or should be '
              '"Compared" side-by-side.',
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Source column',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Type',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Maps to (target)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Role',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.separated(
                itemCount: config.mappings.length,
                separatorBuilder: (_, _) => const Divider(height: 8),
                itemBuilder: (context, index) {
                  final mapping = config.mappings[index];
                  final leftType = leftSchema.columns[index].declaredType;
                  return ColumnMappingRow(
                    mapping: mapping,
                    leftType: leftType,
                    rightColumnOptions: rightColumns,
                    onMappingChanged: (value) {
                      mapping.rightColumn = value;
                      if (value == null) {
                        mapping.isKey = false;
                        mapping.isCompare = false;
                      }
                      state.notifyConfigChanged();
                    },
                    onRoleChanged: (role) {
                      mapping.role = role;
                      state.notifyConfigChanged();
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            if (!hasKey)
              const Text(
                'Select at least one "Key" column to match rows between the two tables.',
                style: TextStyle(color: Colors.red),
              ),
            if (hasKey && !hasCompare)
              const Text(
                'Select at least one "Compare" column to see side-by-side values.',
                style: TextStyle(color: Colors.orange),
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: state.canRunDiff && !state.isLoading
                    ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const DiffResultScreen(runOnOpen: true),
                          ),
                        );
                      }
                    : null,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  child: Text('Compare'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
