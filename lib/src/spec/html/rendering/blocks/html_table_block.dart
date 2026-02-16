import 'package:flutter/material.dart' show Theme, Colors;
import 'package:flutter/widgets.dart';

import '../../model/html_nodes.dart';
import '../../model/html_table_nodes.dart';
import '../../parsing/html_content_parser.dart';

class HtmlSemanticTableBlock extends StatelessWidget {
  const HtmlSemanticTableBlock({
    super.key,
    required this.node,
    required this.baseStyle,
    this.blockBuilder,
  });

  final HtmlTableBlockNode node;
  final TextStyle baseStyle;
  final Widget Function(HtmlBlockNode block)? blockBuilder;

  @override
  Widget build(BuildContext context) {
    final table = node.tableModel;
    if (table == null || table.rows.isEmpty) {
      return const SizedBox.shrink();
    }
    final sections = <HtmlTableSectionNode>[
      if (table.head.rows.isNotEmpty) table.head,
      ...table.bodies,
      if (table.foot.rows.isNotEmpty) table.foot,
    ];
    final parser = HtmlContentParser();
    final parsedCellCache = <String, List<HtmlBlockNode>>{};
    final flattenedRows = sections
        .expand((section) => section.rows.map((row) => (section, row)))
        .toList(growable: false);
    final columnFlexes = _computeColumnFlexes(flattenedRows.map((e) => e.$2));
    final borderColor = Theme.of(context).dividerColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (table.caption != null && table.caption!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              table.caption!,
              style: node.style.applyToTextStyle(
                baseStyle.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: borderColor)),
          child: Column(
            children: List<Widget>.generate(flattenedRows.length, (rowIndex) {
              final entry = flattenedRows[rowIndex];
              return _buildRow(
                context,
                entry.$2,
                entry.$1,
                parser: parser,
                parsedCellCache: parsedCellCache,
                columnFlexes: columnFlexes,
                rowIndex: rowIndex,
                totalRows: flattenedRows.length,
                borderColor: borderColor,
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(
    BuildContext context,
    HtmlTableRowNode row,
    HtmlTableSectionNode section, {
    required HtmlContentParser parser,
    required Map<String, List<HtmlBlockNode>> parsedCellCache,
    required List<int> columnFlexes,
    required int rowIndex,
    required int totalRows,
    required Color borderColor,
  }) {
    final isHeader =
        section.kind == HtmlTableSectionKind.head ||
        row.cells.any((cell) => cell.isHeader);
    final isLastRow = rowIndex == totalRows - 1;
    return IntrinsicHeight(
      child: ColoredBox(
        color: isHeader
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Colors.transparent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: () {
            final cells = <Widget>[];
            var columnCursor = 0;
            for (var cellIndex = 0; cellIndex < row.cells.length; cellIndex++) {
              final cell = row.cells[cellIndex];
              final isLastCell = cellIndex == row.cells.length - 1;
              final span = cell.colSpan.clamp(1, 1000);
              final start = columnCursor;
              final end = (start + span).clamp(0, columnFlexes.length);
              final flex = start < end
                  ? columnFlexes
                        .sublist(start, end)
                        .fold<int>(0, (sum, value) => sum + value)
                  : span;
              cells.add(
                Expanded(
                  flex: flex,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: borderColor),
                        top: BorderSide(color: borderColor),
                        right: isLastCell
                            ? BorderSide(color: borderColor)
                            : BorderSide.none,
                        bottom: isLastRow
                            ? BorderSide(color: borderColor)
                            : BorderSide.none,
                      ),
                    ),
                    child: _buildCellContent(
                      cell,
                      parser: parser,
                      parsedCellCache: parsedCellCache,
                      textStyle: node.style
                          .applyToTextStyle(baseStyle)
                          .copyWith(fontWeight: isHeader ? FontWeight.w700 : null),
                    ),
                  ),
                ),
              );
              columnCursor += span;
            }
            return cells;
          }(),
        ),
      ),
    );
  }

  Widget _buildCellContent(
    HtmlTableCellNode cell, {
    required HtmlContentParser parser,
    required Map<String, List<HtmlBlockNode>> parsedCellCache,
    required TextStyle textStyle,
  }) {
    final rawHtml = cell.html.trim();
    if (rawHtml.isEmpty || blockBuilder == null) {
      return Text(cell.text, style: textStyle);
    }
    final blocks = parsedCellCache.putIfAbsent(rawHtml, () => parser.parse(rawHtml));
    if (blocks.isEmpty) {
      return Text(cell.text, style: textStyle);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List<Widget>.generate(blocks.length, (index) {
        final block = blocks[index];
        return Padding(
          padding: EdgeInsets.only(bottom: index == blocks.length - 1 ? 0 : 6),
          child: blockBuilder!(block),
        );
      }),
    );
  }

  List<int> _computeColumnFlexes(Iterable<HtmlTableRowNode> rows) {
    var columnCount = 0;
    for (final row in rows) {
      final count = row.cells.fold<int>(0, (sum, cell) => sum + cell.colSpan);
      if (count > columnCount) {
        columnCount = count;
      }
    }
    if (columnCount <= 0) {
      return const <int>[1];
    }
    final flexes = List<int>.filled(columnCount, 1);
    for (final row in rows) {
      var col = 0;
      for (final cell in row.cells) {
        final span = cell.colSpan.clamp(1, 1000);
        if (span > 1) {
          // A spanning cell does not tell us how width should be split
          // between covered columns, so skip it for per-column inference.
          col += span;
          continue;
        }
        final cellWeight = _textWeight(cell.text);
        final distributedWeight = (cellWeight / span).ceil().clamp(1, 24);
        for (var i = 0; i < span && (col + i) < flexes.length; i++) {
          if (distributedWeight > flexes[col + i]) {
            flexes[col + i] = distributedWeight;
          }
        }
        col += span;
      }
    }
    return flexes;
  }

  int _textWeight(String text) {
    final normalized = text
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final length = normalized.runes.length;
    if (length <= 1) {
      return 1;
    }
    if (length <= 8) {
      return 2;
    }
    if (length <= 24) {
      return 3;
    }
    if (length <= 60) {
      return 8;
    }
    if (length <= 120) {
      return 12;
    }
    if (length <= 220) {
      return 16;
    }
    return 24;
  }
}
