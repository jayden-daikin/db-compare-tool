import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/comparison_state.dart';
import '../widgets/side_picker_card.dart';
import 'column_mapping_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _pickFile(
    BuildContext context,
    Future<void> Function(String path) onPicked,
  ) async {
    const typeGroup = XTypeGroup(
      label: 'SQLite databases',
      extensions: ['db', 'sqlite', 'sqlite3', 'db3'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file != null && context.mounted) {
      await onPicked(file.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ComparisonState>();

    return Scaffold(
      appBar: AppBar(title: const Text('DB Compare Tool')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select a SQLite database and table for each side to compare.',
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SidePickerCard(
                      title: 'Source',
                      filePath: state.leftFilePath,
                      tables: state.leftTables,
                      selectedTable: state.leftSchema?.tableName,
                      schema: state.leftSchema,
                      isLoading: state.isLeftLoading,
                      onPickFile: () => _pickFile(
                        context,
                        (path) => state.openLeftDatabase(path),
                      ),
                      onTableSelected: state.selectLeftTable,
                    ),
                  ),
                  Expanded(
                    child: SidePickerCard(
                      title: 'Target',
                      filePath: state.rightFilePath,
                      tables: state.rightTables,
                      selectedTable: state.rightSchema?.tableName,
                      schema: state.rightSchema,
                      isLoading: state.isRightLoading,
                      onPickFile: () => _pickFile(
                        context,
                        (path) => state.openRightDatabase(path),
                      ),
                      onTableSelected: state.selectRightTable,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed:
                    state.canProceedToMapping &&
                        !state.isLeftLoading &&
                        !state.isRightLoading
                    ? () {
                        state.buildInitialConfig();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ColumnMappingScreen(),
                          ),
                        );
                      }
                    : null,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  child: Text('Map Columns'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
