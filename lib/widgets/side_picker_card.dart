import 'package:flutter/material.dart';

import '../models/table_schema.dart';
import 'framed_field.dart';

class SidePickerCard extends StatelessWidget {
  final String title;
  final String? filePath;
  final List<String> tables;
  final String? selectedTable;
  final TableSchema? schema;
  final bool isLoading;
  final VoidCallback onPickFile;
  final ValueChanged<String> onTableSelected;

  const SidePickerCard({
    super.key,
    required this.title,
    required this.filePath,
    required this.tables,
    required this.selectedTable,
    required this.isLoading,
    required this.onPickFile,
    required this.onTableSelected,
    this.schema,
  });

  static String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelLarge;
    final greyStyle = TextStyle(fontSize: 12, color: Colors.grey.shade600);
    final sectionBorder = Colors.grey.shade300;
    final sectionHeaderBg = Colors.grey.shade100;

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: isLoading ? null : onPickFile,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.folder_open),
              label: Text(isLoading ? 'Loading...' : 'Browse...'),
            ),
            if (isLoading) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(minHeight: 2),
            ],
            const SizedBox(height: 8),
            FramedInfoField(
              title: 'Database File',
              child: Text(
                filePath ?? 'No file selected',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            if (filePath != null) ...[
              const SizedBox(height: 8),
              Text(
                '${tables.length} table${tables.length == 1 ? '' : 's'} in database',
                style: greyStyle,
              ),
              const SizedBox(height: 12),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: DropdownButtonFormField<String>(
                  initialValue: selectedTable,
                  isExpanded: true,
                  decoration: framedDropdownDecoration('Table'),
                  hint: const Text('Select a table'),
                  items: tables
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: isLoading
                      ? null
                      : (value) {
                          if (value != null) onTableSelected(value);
                        },
                ),
              ),
              if (tables.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'No tables found in this database.',
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
              if (schema != null) ...[
                const SizedBox(height: 16),
                // Section frame
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: sectionBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section header bar
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: sectionHeaderBg,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(7),
                              topRight: Radius.circular(7),
                            ),
                            border: Border(
                              bottom: BorderSide(color: sectionBorder),
                            ),
                          ),
                          child: Text('Table Info', style: labelStyle),
                        ),
                        // Stats row
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                          child: Row(
                            children: [
                              _statChip(
                                Icons.table_rows_outlined,
                                '${_fmt(schema!.rowCount)} rows',
                                theme,
                              ),
                              const SizedBox(width: 12),
                              _statChip(
                                Icons.view_column_outlined,
                                '${schema!.columns.length} col${schema!.columns.length == 1 ? '' : 's'}',
                                theme,
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: sectionBorder),
                        // Column list
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            itemCount: schema!.columns.length,
                            itemBuilder: (context, i) {
                              final col = schema!.columns[i];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        col.name,
                                        style: const TextStyle(fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      col.declaredType,
                                      style: greyStyle.copyWith(
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String label, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }
}
