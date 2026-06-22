import 'package:flutter/material.dart';

import '../models/comparison_config.dart';
import 'framed_field.dart';

class ColumnMappingRow extends StatelessWidget {
  final ColumnMapping mapping;
  final String leftType;
  final List<String> rightColumnOptions;
  final ValueChanged<String?> onMappingChanged;
  final ValueChanged<ColumnRole> onRoleChanged;

  const ColumnMappingRow({
    super.key,
    required this.mapping,
    required this.leftType,
    required this.rightColumnOptions,
    required this.onMappingChanged,
    required this.onRoleChanged,
  });

  static const String _noneValue = '__none__';

  @override
  Widget build(BuildContext context) {
    final isMapped = mapping.isMapped;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              mapping.leftColumn,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(leftType, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            flex: 3,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: mapping.rightColumn ?? _noneValue,
                decoration: framedDropdownDecoration('Target column'),
                items: [
                  const DropdownMenuItem(
                    value: _noneValue,
                    child: Text('— None —'),
                  ),
                  ...rightColumnOptions.map(
                    (c) => DropdownMenuItem(value: c, child: Text(c)),
                  ),
                ],
                onChanged: (value) {
                  onMappingChanged(value == _noneValue ? null : value);
                },
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _roleOption(ColumnRole.key, 'Key', isMapped),
                const SizedBox(width: 12), // spacing
                _roleOption(ColumnRole.compare, 'Compare', isMapped),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleOption(ColumnRole role, String label, bool enabled) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Radio<ColumnRole>(
              value: role,
              groupValue: mapping.role,
              onChanged: enabled ? (v) => onRoleChanged(v!) : null,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
