import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/table_schema.dart';
import 'framed_field.dart';

class SidePickerCard extends StatelessWidget {
  final String title;
  final String? folderPath;
  final List<String> dbFiles;
  final String? selectedFilePath;
  final List<String> tables;
  final String? selectedTable;
  final TableSchema? schema;
  final bool isLoading;
  final VoidCallback onPickFolder;
  final ValueChanged<String> onDbFileSelected;
  final ValueChanged<String> onTableSelected;

  const SidePickerCard({
    super.key,
    required this.title,
    required this.folderPath,
    required this.dbFiles,
    required this.selectedFilePath,
    required this.tables,
    required this.selectedTable,
    required this.isLoading,
    required this.onPickFolder,
    required this.onDbFileSelected,
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
              onPressed: isLoading ? null : onPickFolder,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.folder_open),
              label: Text(isLoading ? 'Loading...' : 'Browse Folder...'),
            ),
            if (isLoading) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(minHeight: 2),
            ],
            if (folderPath != null) ...[
              const SizedBox(height: 8),
              FramedInfoField(
                title: 'Folder',
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  folderPath!,
                  style: greyStyle,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              const SizedBox(height: 8),
              _DbFileList(
                dbFiles: dbFiles,
                selectedFilePath: selectedFilePath,
                onDbFileSelected: onDbFileSelected,
                isLoading: isLoading,
              ),
            ],
            if (selectedFilePath != null) ...[
              const SizedBox(height: 8),
              Text(
                '${tables.length} table${tables.length == 1 ? '' : 's'} in database',
                style: greyStyle,
              ),
              const SizedBox(height: 12),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: DropdownButtonFormField<String>(
                  value: selectedTable,
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
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: sectionBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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

class _DbFileList extends StatelessWidget {
  final List<String> dbFiles;
  final String? selectedFilePath;
  final ValueChanged<String> onDbFileSelected;
  final bool isLoading;

  const _DbFileList({
    required this.dbFiles,
    required this.selectedFilePath,
    required this.onDbFileSelected,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (dbFiles.isEmpty) {
      return Text(
        'No DB files found in folder',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade500,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < dbFiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _DbButton(
              path: dbFiles[i],
              isSelected: dbFiles[i] == selectedFilePath,
              isLoading: isLoading,
              onTap: () => onDbFileSelected(dbFiles[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _DbButton extends StatelessWidget {
  final String path;
  final bool isSelected;
  final bool isLoading;
  final VoidCallback onTap;

  const _DbButton({
    required this.path,
    required this.isSelected,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = p.basename(path);
    if (isSelected) {
      return FilledButton.icon(
        onPressed: isLoading ? null : onTap,
        icon: const Icon(Icons.storage_rounded, size: 14),
        label: Text(name),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: const TextStyle(fontSize: 13),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: isLoading ? null : onTap,
      icon: Icon(Icons.storage_rounded, size: 14, color: Colors.grey.shade600),
      label: Text(name),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle: const TextStyle(fontSize: 13),
      ),
    );
  }
}
