import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'html_content_parser.dart';
import 'html_nodes.dart';

typedef HtmlImageBuilder =
    Widget Function(BuildContext context, String src, String? alt);

typedef HtmlLinkTapCallback = void Function(String href);

class HtmlColumnReader extends StatelessWidget {
  const HtmlColumnReader({
    super.key,
    required this.html,
    this.columnsPerPage = 2,
    this.columnGap = 20,
    this.pagePadding = const EdgeInsets.all(16),
    this.textStyle,
    this.headingStyles = const <int, TextStyle>{},
    this.onLinkTap,
    this.imageBuilder,
    this.parser,
  }) : assert(columnsPerPage > 0, 'columnsPerPage must be > 0');

  final String html;
  final int columnsPerPage;
  final double columnGap;
  final EdgeInsetsGeometry pagePadding;
  final TextStyle? textStyle;
  final Map<int, TextStyle> headingStyles;
  final HtmlLinkTapCallback? onLinkTap;
  final HtmlImageBuilder? imageBuilder;
  final HtmlContentParser? parser;

  @override
  Widget build(BuildContext context) {
    final baseStyle = textStyle ?? Theme.of(context).textTheme.bodyMedium!;
    final blocks = (parser ?? HtmlContentParser()).parse(html);

    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedPadding = pagePadding.resolve(Directionality.of(context));
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final innerWidth = availableWidth - resolvedPadding.horizontal;
        final columnWidth =
            (innerWidth - (columnGap * (columnsPerPage - 1))) / columnsPerPage;
        final viewportHeight = (availableHeight - resolvedPadding.vertical)
            .clamp(140.0, double.infinity);

        final columns = _partitionIntoColumns(
          blocks,
          columnWidth: columnWidth,
          viewportHeight: viewportHeight,
          baseStyle: baseStyle,
        );
        final pages = _groupColumnsIntoPages(columns, columnsPerPage);

        return PageView.builder(
          itemCount: pages.length,
          itemBuilder: (context, pageIndex) {
            final pageColumns = pages[pageIndex];
            return Padding(
              padding: resolvedPadding,
              child: Row(
                children: List<Widget>.generate(columnsPerPage, (columnIndex) {
                  final blockNodes = columnIndex < pageColumns.length
                      ? pageColumns[columnIndex]
                      : const <HtmlBlockNode>[];
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: columnIndex == columnsPerPage - 1
                            ? 0
                            : columnGap,
                      ),
                      child: _ColumnWidget(
                        key: ValueKey<String>(
                          'html-column-page-$pageIndex-col-$columnIndex',
                        ),
                        blocks: blockNodes,
                        baseStyle: baseStyle,
                        headingStyles: headingStyles,
                        onLinkTap: onLinkTap,
                        imageBuilder: imageBuilder,
                      ),
                    ),
                  );
                }),
              ),
            );
          },
        );
      },
    );
  }

  List<List<HtmlBlockNode>> _partitionIntoColumns(
    List<HtmlBlockNode> blocks, {
    required double columnWidth,
    required double viewportHeight,
    required TextStyle baseStyle,
  }) {
    if (blocks.isEmpty) {
      return <List<HtmlBlockNode>>[<HtmlBlockNode>[]];
    }

    final columns = <List<HtmlBlockNode>>[];
    var currentColumn = <HtmlBlockNode>[];
    var currentHeight = 0.0;
    const interBlockSpacing = 8.0;
    final maxHeight = viewportHeight;

    for (final block in blocks) {
      final estimate = block.estimateHeight(
        columnWidth: columnWidth,
        baseTextStyle: baseStyle,
      );
      final projected = currentHeight + estimate + interBlockSpacing;
      if (currentColumn.isNotEmpty && projected > maxHeight) {
        columns.add(currentColumn);
        currentColumn = <HtmlBlockNode>[block];
        currentHeight = estimate + interBlockSpacing;
      } else {
        currentColumn.add(block);
        currentHeight = projected;
      }
    }
    if (currentColumn.isNotEmpty) {
      columns.add(currentColumn);
    }

    return columns;
  }

  List<List<List<HtmlBlockNode>>> _groupColumnsIntoPages(
    List<List<HtmlBlockNode>> columns,
    int columnsPerPage,
  ) {
    final pages = <List<List<HtmlBlockNode>>>[];
    for (var i = 0; i < columns.length; i += columnsPerPage) {
      final end = (i + columnsPerPage).clamp(0, columns.length);
      pages.add(columns.sublist(i, end));
    }
    if (pages.isEmpty) {
      pages.add(const <List<HtmlBlockNode>>[]);
    }
    return pages;
  }
}

class _ColumnWidget extends StatelessWidget {
  const _ColumnWidget({
    super.key,
    required this.blocks,
    required this.baseStyle,
    required this.headingStyles,
    required this.onLinkTap,
    required this.imageBuilder,
  });

  final List<HtmlBlockNode> blocks;
  final TextStyle baseStyle;
  final Map<int, TextStyle> headingStyles;
  final HtmlLinkTapCallback? onLinkTap;
  final HtmlImageBuilder? imageBuilder;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: blocks.length,
      itemBuilder: (context, index) {
        return _buildBlock(context, blocks[index]);
      },
      separatorBuilder: (context, index) => const SizedBox(height: 12),
    );
  }

  Widget _buildBlock(BuildContext context, HtmlBlockNode block) {
    if (block is HtmlTextBlockNode) {
      return _buildTextBlock(context, block);
    }
    if (block is HtmlListBlockNode) {
      return _buildListBlock(context, block);
    }
    if (block is HtmlTableBlockNode) {
      return _buildTableBlock(context, block);
    }
    if (block is HtmlImageBlockNode) {
      return _buildImageBlock(context, block);
    }
    if (block is HtmlDividerBlockNode) {
      return const Divider(height: 1);
    }
    return const SizedBox.shrink();
  }

  Widget _buildTextBlock(BuildContext context, HtmlTextBlockNode block) {
    var effectiveStyle = block.style.applyTo(baseStyle);
    if (block.headingLevel != null) {
      effectiveStyle =
          headingStyles[block.headingLevel] ??
          _defaultHeadingStyle(baseStyle, block.headingLevel!);
    }

    if (block.preformatted) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            block.plainText,
            style: effectiveStyle.copyWith(fontFamily: 'monospace'),
          ),
        ),
      );
    }

    final spans = <InlineSpan>[];
    for (final segment in block.segments) {
      final segmentStyle = segment.style.applyTo(
        segment.isCode
            ? effectiveStyle.copyWith(fontFamily: 'monospace')
            : effectiveStyle,
      );

      if (segment.href != null && onLinkTap != null) {
        spans.add(
          TextSpan(
            text: segment.text,
            style: segmentStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => onLinkTap!(segment.href!),
          ),
        );
      } else {
        spans.add(TextSpan(text: segment.text, style: segmentStyle));
      }
    }

    Widget content = RichText(
      textAlign: block.style.textAlign ?? TextAlign.start,
      text: TextSpan(style: effectiveStyle, children: spans),
    );

    if (block.isBlockquote) {
      content = Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: Theme.of(context).dividerColor, width: 4),
          ),
        ),
        padding: const EdgeInsets.only(left: 12),
        child: content,
      );
    }
    return content;
  }

  Widget _buildListBlock(BuildContext context, HtmlListBlockNode block) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List<Widget>.generate(block.items.length, (index) {
        final bullet = block.ordered ? '${index + 1}.' : '\u2022';
        final segments = block.items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(width: 20, child: Text(bullet, style: baseStyle)),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: block.style.applyTo(baseStyle),
                    children: segments
                        .map(
                          (segment) => TextSpan(
                            text: segment.text,
                            style: segment.style.applyTo(baseStyle),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildTableBlock(BuildContext context, HtmlTableBlockNode block) {
    final borderColor = Theme.of(context).dividerColor;
    final rows = block.rows;
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxColumns = rows.fold<int>(
      0,
      (previousValue, row) =>
          row.length > previousValue ? row.length : previousValue,
    );

    return Table(
      border: TableBorder.all(color: borderColor),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: List<TableRow>.generate(rows.length, (rowIndex) {
        final row = rows[rowIndex];
        return TableRow(
          decoration: block.hasHeader && rowIndex == 0
              ? BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                )
              : null,
          children: List<Widget>.generate(maxColumns, (colIndex) {
            final text = colIndex < row.length ? row[colIndex] : '';
            return Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                text,
                style: rowIndex == 0 && block.hasHeader
                    ? baseStyle.copyWith(fontWeight: FontWeight.w700)
                    : baseStyle,
              ),
            );
          }),
        );
      }),
    );
  }

  Widget _buildImageBlock(BuildContext context, HtmlImageBlockNode block) {
    if (imageBuilder != null) {
      return imageBuilder!(context, block.src, block.alt);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(
            block.src,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                padding: const EdgeInsets.all(10),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Text('Unable to load image: ${block.src}'),
              );
            },
          ),
        ),
        if (block.alt != null && block.alt!.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            block.alt!,
            style: baseStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ],
    );
  }

  TextStyle _defaultHeadingStyle(TextStyle base, int level) {
    final size = switch (level.clamp(1, 6)) {
      1 => 32.0,
      2 => 28.0,
      3 => 24.0,
      4 => 21.0,
      5 => 18.0,
      _ => 16.0,
    };
    return base.copyWith(
      fontSize: size,
      fontWeight: FontWeight.w700,
      height: 1.25,
    );
  }
}
