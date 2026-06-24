import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/comparison_config.dart';
import '../models/diff_result.dart';

const double _kMinColWidth = 60;
const double _kDateColMinWidth = 180;
const double _kCellHPad = 8.0;
const double _kRowHeight = 40;
const double _kHeaderTier1Height = 44;
const double _kHeaderTier2Height = 36;
const double _kDividerWidth = 2;
const double _kRulerWidth = 14;
const double _kScrollbarHeight = 20;

class DiffTable extends StatefulWidget {
  final List<RowDiff> rows;
  final ComparisonConfig config;
  final String? leftFilePath;
  final String? rightFilePath;

  const DiffTable({
    super.key,
    required this.rows,
    required this.config,
    this.leftFilePath,
    this.rightFilePath,
  });

  @override
  State<DiffTable> createState() => _DiffTableState();
}

class _DiffTableState extends State<DiffTable> {
  final _vScrollController = ScrollController();
  final _hScrollLeft = ScrollController();
  final _hScrollRight = ScrollController();
  bool _hSyncing = false;

  List<double>? _colWidthsCache;
  double? _cachedHalfAvail;
  int? _cachedRowCount;

  @override
  void initState() {
    super.initState();
    _hScrollLeft.addListener(_syncLeftToRight);
    _hScrollRight.addListener(_syncRightToLeft);
  }

  void _syncLeftToRight() {
    if (_hSyncing) return;
    _hSyncing = true;
    if (_hScrollRight.hasClients) {
      _hScrollRight.jumpTo(
        _hScrollLeft.offset.clamp(0.0, _hScrollRight.position.maxScrollExtent),
      );
    }
    _hSyncing = false;
  }

  void _syncRightToLeft() {
    if (_hSyncing) return;
    _hSyncing = true;
    if (_hScrollLeft.hasClients) {
      _hScrollLeft.jumpTo(
        _hScrollRight.offset.clamp(0.0, _hScrollLeft.position.maxScrollExtent),
      );
    }
    _hSyncing = false;
  }

  @override
  void didUpdateWidget(DiffTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rows != widget.rows || oldWidget.config != widget.config) {
      _colWidthsCache = null;
      _cachedHalfAvail = null;
      _cachedRowCount = null;
    }
  }

  @override
  void dispose() {
    _hScrollLeft.removeListener(_syncLeftToRight);
    _hScrollRight.removeListener(_syncRightToLeft);
    _vScrollController.dispose();
    _hScrollLeft.dispose();
    _hScrollRight.dispose();
    super.dispose();
  }

  double _measureText(String text, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    tp.layout();
    return tp.width;
  }

  static String _formatValue(Object? value) {
    if (value == null) return 'NULL';
    if (value is int) return value.toString();
    if (value is double) {
      if (value % 1 == 0) return value.toInt().toString();
      return double.parse(value.toStringAsPrecision(7)).toString();
    }
    return value.toString();
  }

  // Returns one width per column: [keyCol0, keyCol1, ..., cmpCol0, cmpCol1, ...]
  List<double> _computeColWidths(BuildContext context, double halfAvail) {
    if (_colWidthsCache != null &&
        _cachedHalfAvail == halfAvail &&
        _cachedRowCount == widget.rows.length) {
      return _colWidthsCache!;
    }

    final theme = Theme.of(context);
    final bodyStyle = theme.textTheme.bodyMedium ?? const TextStyle();
    final boldStyle = bodyStyle.copyWith(fontWeight: FontWeight.bold);

    final keyMaps = widget.config.keyMappings;
    final cmpMaps = widget.config.compareMappings;
    final n = keyMaps.length + cmpMaps.length;

    if (n == 0) {
      _colWidthsCache = [];
      _cachedHalfAvail = halfAvail;
      _cachedRowCount = widget.rows.length;
      return [];
    }

    final widths = List<double>.filled(n, 0.0);

    // Key columns — width = max of both-side header + all key values
    for (int i = 0; i < keyMaps.length; i++) {
      final m = keyMaps[i];
      double w = math.max(
        _measureText(m.leftColumn, boldStyle),
        _measureText(m.rightColumn ?? m.leftColumn, boldStyle),
      );
      for (final row in widget.rows) {
        final v = row.keyValues[m.leftColumn];
        w = math.max(w, _measureText(_formatValue(v), bodyStyle));
      }
      final isDateLike =
          m.leftColumn.toLowerCase().contains('date') ||
          (m.rightColumn?.toLowerCase().contains('date') ?? false);
      final minWidth = isDateLike ? _kDateColMinWidth : _kMinColWidth;
      widths[i] = math.max(minWidth, w + _kCellHPad * 2 + 12);
    }

    // Compare columns — width = max of both headers + left and right values
    for (int i = 0; i < cmpMaps.length; i++) {
      final m = cmpMaps[i];
      double w = math.max(
        _measureText(m.leftColumn, boldStyle),
        _measureText(m.rightColumn ?? m.leftColumn, boldStyle),
      );
      for (final row in widget.rows) {
        final cell = row.cells[m.leftColumn];
        if (cell != null) {
          w = math.max(w, _measureText(_formatValue(cell.leftValue), bodyStyle));
          w = math.max(w, _measureText(_formatValue(cell.rightValue), bodyStyle));
        }
      }
      // +12 for the 6px×2 highlight padding; +4 safety margin for sub-pixel rendering
      widths[keyMaps.length + i] = math.max(_kMinColWidth, w + _kCellHPad * 2 + 16);
    }

    // Expand proportionally to fill halfAvail when content is narrower
    final total = widths.fold(0.0, (a, b) => a + b);
    if (total < halfAvail && halfAvail > 0) {
      final scale = halfAvail / total;
      for (int i = 0; i < widths.length; i++) {
        widths[i] *= scale;
      }
    }

    _colWidthsCache = widths;
    _cachedHalfAvail = halfAvail;
    _cachedRowCount = widget.rows.length;
    return widths;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalW = constraints.maxWidth;
        // halfAvail = space available for one side (source or target columns)
        final halfAvail = math.max(
          0.0,
          (totalW - _kDividerWidth - _kRulerWidth) / 2,
        );
        final colWidths = _computeColWidths(context, halfAvail);
        final sideW = colWidths.isEmpty
            ? halfAvail
            : colWidths.fold(0.0, (a, b) => a + b);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sticky header
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade400)),
              ),
              child: _buildHeaders(context, colWidths, sideW, halfAvail),
            ),
            // Data rows + overview ruler
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(
                        context,
                      ).copyWith(scrollbars: false),
                      child: ListView.builder(
                        controller: _vScrollController,
                        itemCount: widget.rows.length,
                        itemExtent: _kRowHeight,
                        itemBuilder: (ctx, i) => _buildDataRow(
                          ctx,
                          widget.rows[i],
                          colWidths,
                          sideW,
                          halfAvail,
                        ),
                      ),
                    ),
                  ),
                  _OverviewRuler(
                    rows: widget.rows,
                    scrollController: _vScrollController,
                  ),
                ],
              ),
            ),
            // Two synced horizontal scrollbars
            _buildScrollbars(sideW, halfAvail),
          ],
        );
      },
    );
  }

  void _handleHorizontalScroll(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (event.scrollDelta.dx == 0) return;
    if (!_hScrollLeft.hasClients) return;

    final position = _hScrollLeft.position;
    final nextOffset = (_hScrollLeft.offset + event.scrollDelta.dx).clamp(
      0.0,
      position.maxScrollExtent,
    );
    if (nextOffset != _hScrollLeft.offset) {
      _hScrollLeft.jumpTo(nextOffset);
    }
  }

  Widget _scrollPane({
    required ScrollController controller,
    required double viewportWidth,
    required double contentWidth,
    required Widget child,
  }) {
    return SizedBox(
      width: viewportWidth,
      child: Listener(
        onPointerSignal: _handleHorizontalScroll,
        child: ClipRect(
          child: AnimatedBuilder(
            animation: controller,
            builder: (ctx, animatedChild) {
              final offset = controller.hasClients ? controller.offset : 0.0;
              return Transform.translate(
                offset: Offset(-offset, 0.0),
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  minWidth: contentWidth,
                  maxWidth: contentWidth,
                  child: animatedChild,
                ),
              );
            },
            child: SizedBox(width: contentWidth, child: child),
          ),
        ),
      ),
    );
  }

  // ── Headers ──────────────────────────────────────────────────────────────

  Widget _buildHeaders(
    BuildContext context,
    List<double> colWidths,
    double sideW,
    double halfAvail,
  ) {
    final boldStyle = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold);
    final keyMaps = widget.config.keyMappings;
    final cmpMaps = widget.config.compareMappings;

    Widget sourceColumnHeader = SizedBox(
      width: sideW,
      height: _kHeaderTier2Height,
      child: Row(
        children: [
          for (int i = 0; i < keyMaps.length; i++)
            _headerCell(
              keyMaps[i].leftColumn,
              colWidths[i],
              boldStyle,
              bg: Colors.blue.shade50,
            ),
          for (int i = 0; i < cmpMaps.length; i++)
            _headerCell(
              cmpMaps[i].leftColumn,
              colWidths[keyMaps.length + i],
              boldStyle,
              bg: Colors.blue.shade50,
            ),
        ],
      ),
    );

    Widget targetColumnHeader = SizedBox(
      width: sideW,
      height: _kHeaderTier2Height,
      child: Row(
        children: [
          for (int i = 0; i < keyMaps.length; i++)
            _headerCell(
              keyMaps[i].rightColumn ?? keyMaps[i].leftColumn,
              colWidths[i],
              boldStyle,
              bg: Colors.green.shade50,
            ),
          for (int i = 0; i < cmpMaps.length; i++)
            _headerCell(
              cmpMaps[i].rightColumn ?? cmpMaps[i].leftColumn,
              colWidths[keyMaps.length + i],
              boldStyle,
              bg: Colors.green.shade50,
            ),
        ],
      ),
    );

    return SizedBox(
      height: _kHeaderTier1Height + _kHeaderTier2Height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: halfAvail,
            child: Column(
              children: [
                SizedBox(
                  height: _kHeaderTier1Height,
                  child: _groupLabel(
                    'Source',
                    widget.config.leftTable,
                    widget.leftFilePath,
                    Colors.blue.shade100,
                    boldStyle,
                  ),
                ),
                SizedBox(
                  height: _kHeaderTier2Height,
                  child: _scrollPane(
                    controller: _hScrollLeft,
                    viewportWidth: halfAvail,
                    contentWidth: sideW,
                    child: sourceColumnHeader,
                  ),
                ),
              ],
            ),
          ),
          // Fixed center divider
          Container(width: _kDividerWidth, color: Colors.grey.shade400),
          SizedBox(
            width: halfAvail,
            child: Column(
              children: [
                SizedBox(
                  height: _kHeaderTier1Height,
                  child: _groupLabel(
                    'Target',
                    widget.config.rightTable,
                    widget.rightFilePath,
                    Colors.green.shade100,
                    boldStyle,
                  ),
                ),
                SizedBox(
                  height: _kHeaderTier2Height,
                  child: _scrollPane(
                    controller: _hScrollRight,
                    viewportWidth: halfAvail,
                    contentWidth: sideW,
                    child: targetColumnHeader,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: _kRulerWidth),
        ],
      ),
    );
  }

  // ── Data row ─────────────────────────────────────────────────────────────

  Widget _buildDataRow(
    BuildContext context,
    RowDiff row,
    List<double> colWidths,
    double sideW,
    double halfAvail,
  ) {
    final isSourceMissing = row.status == RowStatus.missingInLeft;
    final isTargetMissing = row.status == RowStatus.missingInRight;

    Color? sourceBg;
    Color? targetBg;
    switch (row.status) {
      case RowStatus.matched:
        break;
      case RowStatus.different:
        sourceBg = Colors.orange.shade50;
        targetBg = Colors.orange.shade50;
        break;
      case RowStatus.missingInRight:
        sourceBg = Colors.red.shade50;
        targetBg = Colors.grey.shade100;
        break;
      case RowStatus.missingInLeft:
        sourceBg = Colors.grey.shade100;
        targetBg = Colors.blue.shade50;
        break;
    }

    final keyMaps = widget.config.keyMappings;
    final cmpMaps = widget.config.compareMappings;

    Widget sourceContent = Container(
      width: sideW,
      color: sourceBg,
      child: Row(
        children: [
          for (int i = 0; i < keyMaps.length; i++)
            _bodyCell(
              colWidths[i],
              isSourceMissing
                  ? const SizedBox.shrink()
                  : _valueText(row.keyValues[keyMaps[i].leftColumn]),
            ),
          for (int i = 0; i < cmpMaps.length; i++)
            _bodyCell(
              colWidths[keyMaps.length + i],
              _valueCell(
                row.cells[cmpMaps[i].leftColumn]?.leftValue,
                highlight:
                    row.cells[cmpMaps[i].leftColumn]?.isDifferent ?? false,
                empty: isSourceMissing,
              ),
            ),
        ],
      ),
    );

    Widget targetContent = Container(
      width: sideW,
      color: targetBg,
      child: Row(
        children: [
          for (int i = 0; i < keyMaps.length; i++)
            _bodyCell(
              colWidths[i],
              isTargetMissing
                  ? const SizedBox.shrink()
                  : _valueText(row.keyValues[keyMaps[i].leftColumn]),
            ),
          for (int i = 0; i < cmpMaps.length; i++)
            _bodyCell(
              colWidths[keyMaps.length + i],
              _valueCell(
                row.cells[cmpMaps[i].leftColumn]?.rightValue,
                highlight:
                    row.cells[cmpMaps[i].leftColumn]?.isDifferent ?? false,
                empty: isTargetMissing,
              ),
            ),
        ],
      ),
    );

    return Container(
      height: _kRowHeight,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Source cells — translate by left scroll offset
          _scrollPane(
            controller: _hScrollLeft,
            viewportWidth: halfAvail,
            contentWidth: sideW,
            child: sourceContent,
          ),
          // Fixed center divider
          Container(width: _kDividerWidth, color: Colors.grey.shade300),
          // Target cells — translate by right scroll offset (synced)
          _scrollPane(
            controller: _hScrollRight,
            viewportWidth: halfAvail,
            contentWidth: sideW,
            child: targetContent,
          ),
        ],
      ),
    );
  }

  // ── Scrollbars ───────────────────────────────────────────────────────────

  Widget _buildScrollbars(double sideW, double halfAvail) {
    return SizedBox(
      height: _kScrollbarHeight,
      child: Row(
        children: [
          // Source scrollbar
          SizedBox(
            width: halfAvail,
            child: Scrollbar(
              controller: _hScrollLeft,
              thumbVisibility: true,
              trackVisibility: true,
              child: SingleChildScrollView(
                controller: _hScrollLeft,
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: sideW, height: _kScrollbarHeight),
              ),
            ),
          ),
          SizedBox(width: _kDividerWidth),
          // Target scrollbar (synced with source)
          SizedBox(
            width: halfAvail,
            child: Scrollbar(
              controller: _hScrollRight,
              thumbVisibility: true,
              trackVisibility: true,
              child: SingleChildScrollView(
                controller: _hScrollRight,
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: sideW, height: _kScrollbarHeight),
              ),
            ),
          ),
          SizedBox(width: _kRulerWidth),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _groupLabel(
    String sideLabel,
    String tableName,
    String? filePath,
    Color bg,
    TextStyle? style,
  ) {
    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$sideLabel: $tableName',
            style: style,
            overflow: TextOverflow.ellipsis,
          ),
          if (filePath != null)
            Text(
              filePath,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _headerCell(String text, double width, TextStyle? style, {Color? bg}) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: bg,
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      alignment: Alignment.centerLeft,
      child: Text(text, style: style, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _bodyCell(double width, Widget child) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      child: child,
    );
  }

  Widget _valueCell(
    Object? value, {
    required bool highlight,
    required bool empty,
  }) {
    if (empty) return const SizedBox.shrink();
    final content = _valueText(value);
    if (!highlight) return content;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.amber.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
      child: content,
    );
  }

  Widget _valueText(Object? value) {
    if (value == null) {
      return const Text(
        'NULL',
        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
        overflow: TextOverflow.ellipsis,
      );
    }
    return Text(_formatValue(value), overflow: TextOverflow.ellipsis);
  }
}

// ---------------------------------------------------------------------------
// Overview ruler
// ---------------------------------------------------------------------------

class _OverviewRuler extends StatefulWidget {
  final List<RowDiff> rows;
  final ScrollController scrollController;

  const _OverviewRuler({required this.rows, required this.scrollController});

  @override
  State<_OverviewRuler> createState() => _OverviewRulerState();
}

class _OverviewRulerState extends State<_OverviewRuler> {
  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(_OverviewRuler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_rebuild);
      widget.scrollController.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _seekTo(Offset localPos, Size size) {
    if (!widget.scrollController.hasClients || size.height == 0) return;
    final totalContent = widget.rows.length * _kRowHeight;
    final viewportH = widget.scrollController.position.viewportDimension;
    final maxScroll = widget.scrollController.position.maxScrollExtent;
    final contentY = (localPos.dy / size.height) * totalContent;
    final target = (contentY - viewportH / 2).clamp(0.0, maxScroll);
    widget.scrollController.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (d) => _seekTo(d.localPosition, context.size ?? Size.zero),
      onVerticalDragUpdate: (d) =>
          _seekTo(d.localPosition, context.size ?? Size.zero),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: _kRulerWidth,
          color: Colors.grey.shade200,
          child: CustomPaint(
            painter: _RulerPainter(
              rows: widget.rows,
              scrollController: widget.scrollController,
            ),
          ),
        ),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  final List<RowDiff> rows;
  final ScrollController scrollController;

  static const _colourDifferent = Color(0xFFFF8C00);
  static const _colourMissingRight = Color(0xFFE53935);
  static const _colourMissingLeft = Color(0xFF1E88E5);

  _RulerPainter({required this.rows, required this.scrollController});

  @override
  void paint(Canvas canvas, Size size) {
    if (rows.isEmpty) return;

    final markPaint = Paint()..style = PaintingStyle.fill;
    final n = rows.length.toDouble();
    final minMarkH = math.max(1.5, size.height / n);

    for (int i = 0; i < rows.length; i++) {
      Color? colour;
      switch (rows[i].status) {
        case RowStatus.different:
          colour = _colourDifferent;
          break;
        case RowStatus.missingInRight:
          colour = _colourMissingRight;
          break;
        case RowStatus.missingInLeft:
          colour = _colourMissingLeft;
          break;
        case RowStatus.matched:
          break;
      }
      if (colour == null) continue;

      markPaint.color = colour;
      final y = (i / n) * size.height;
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, minMarkH), markPaint);
    }

    if (scrollController.hasClients &&
        scrollController.position.hasContentDimensions) {
      final totalContent = rows.length * _kRowHeight;
      final viewportH = scrollController.position.viewportDimension;
      final offset = scrollController.offset;

      if (totalContent > viewportH) {
        final indicatorH = (viewportH / totalContent * size.height).clamp(
          2.0,
          size.height,
        );
        final top = (offset / totalContent * size.height).clamp(
          0.0,
          size.height - indicatorH,
        );

        canvas.drawRect(
          Rect.fromLTWH(0, top, size.width, indicatorH),
          Paint()..color = const Color(0x26000000),
        );
        canvas.drawRect(
          Rect.fromLTWH(0, top, size.width, indicatorH),
          Paint()
            ..color = const Color(0x80000000)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RulerPainter old) => true;
}
