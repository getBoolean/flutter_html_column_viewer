import 'package:flutter/material.dart';

import 'html_block_widgets.dart';
import 'html_content_parser.dart';
import 'html_nodes.dart';
import 'html_reader_controller.dart';

class HtmlColumnReader extends StatelessWidget {
  const HtmlColumnReader({
    super.key,
    required this.html,
    this.columnsPerPage = 2,
    this.columnGap = 20,
    this.pagePadding = const EdgeInsets.all(16),
    this.textStyle,
    this.headingStyles = const <int, TextStyle>{},
    this.onRefTap,
    this.imageBuilder,
    this.parser,
    this.blockBuilder,
    this.controller,
    this.onPageCountChanged,
    this.onBookmarkIndexChanged,
  }) : assert(columnsPerPage > 0, 'columnsPerPage must be > 0');

  final String html;
  final int columnsPerPage;
  final double columnGap;
  final EdgeInsetsGeometry pagePadding;
  final TextStyle? textStyle;
  final Map<int, TextStyle> headingStyles;
  final HtmlRefTapCallback? onRefTap;
  final HtmlImageBuilder? imageBuilder;
  final HtmlContentParser? parser;

  /// Optional custom builder for blocks. Return null to use the default widget.
  final Widget? Function(BuildContext context, HtmlBlockNode block)?
  blockBuilder;

  /// Optional [HtmlReaderController] for programmatic page and reference control.
  final HtmlReaderController? controller;

  /// Called with the total page count when the reader has laid out. Use to enable/disable next/previous buttons or show "Page X of Y".
  final void Function(int pageCount)? onPageCountChanged;

  /// Called with a map of HTML id -> page index after layout.
  final void Function(Map<String, int> bookmarkIndex)? onBookmarkIndexChanged;

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
        final innerWidth = (availableWidth - resolvedPadding.horizontal).clamp(
          0.0,
          double.infinity,
        );
        final columnWidth =
            ((innerWidth - (columnGap * (columnsPerPage - 1))) / columnsPerPage)
                .clamp(1.0, double.infinity);
        final viewportHeight = (availableHeight - resolvedPadding.vertical)
            .clamp(140.0, double.infinity);

        final columns = _partitionIntoColumns(
          blocks,
          columnWidth: columnWidth,
          viewportHeight: viewportHeight,
          baseStyle: baseStyle,
        );
        final pages = _groupColumnsIntoPages(columns, columnsPerPage);
        final bookmarkIndex = _buildBookmarkIndex(pages);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          onPageCountChanged?.call(pages.length);
          onBookmarkIndexChanged?.call(bookmarkIndex);
          controller?.updateLayoutData(
            pageCount: pages.length,
            bookmarkIndex: bookmarkIndex,
          );
        });

        return PageView.builder(
          controller: controller?.pageController,
          itemCount: pages.length,
          itemBuilder: (context, pageIndex) {
            final pageColumns = pages[pageIndex];
            return RepaintBoundary(
              child: SizedBox(
                height: viewportHeight + resolvedPadding.vertical,
                child: Padding(
                  padding: resolvedPadding,
                  child: Row(
                    children: List<Widget>.generate(columnsPerPage, (
                      columnIndex,
                    ) {
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
                            viewportHeight: viewportHeight,
                            blockContext: HtmlBlockContext(
                              baseStyle: baseStyle,
                              headingStyles: headingStyles,
                              onRefTap: onRefTap,
                              imageBuilder: imageBuilder,
                            ),
                            blockBuilder: blockBuilder,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
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

  Map<String, int> _buildBookmarkIndex(List<List<List<HtmlBlockNode>>> pages) {
    final index = <String, int>{};
    for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      for (final column in pages[pageIndex]) {
        for (final block in column) {
          final id = block.id;
          if (id == null || id.trim().isEmpty || index.containsKey(id)) {
            continue;
          }
          index[id] = pageIndex;
        }
      }
    }
    return Map<String, int>.unmodifiable(index);
  }
}

class _ColumnWidget extends StatelessWidget {
  const _ColumnWidget({
    super.key,
    required this.blocks,
    required this.viewportHeight,
    required this.blockContext,
    this.blockBuilder,
  });

  final List<HtmlBlockNode> blocks;
  final double viewportHeight;
  final HtmlBlockContext blockContext;
  final Widget? Function(BuildContext context, HtmlBlockNode block)?
  blockBuilder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: viewportHeight,
      child: ListView.separated(
        itemCount: blocks.length,
        itemBuilder: (context, index) {
          return HtmlBlockView(
            block: blocks[index],
            blockContext: blockContext,
            builder: blockBuilder,
          );
        },
        separatorBuilder: (context, index) => const SizedBox(height: 12),
      ),
    );
  }
}
