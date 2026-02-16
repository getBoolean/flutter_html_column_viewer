import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';

import '../spec/html/rendering/html_block_widgets.dart';
import '../spec/html/parsing/html_content_parser.dart';
import '../spec/html/model/html_nodes.dart';
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
    this.onImageTap,
    this.imageBuilder,
    this.imageBytesBuilder,
    this.parser,
    this.externalCss,
    this.externalCssResolver,
    this.blockBuilder,
    this.controller,
    this.onPageCountChanged,
    this.onColumnCountChanged,
    this.onBookmarkIndexChanged,
    this.onBookmarkColumnIndexChanged,
    this.onBookmarkPageCandidatesChanged,
  }) : assert(columnsPerPage > 0, 'columnsPerPage must be > 0');

  final String html;
  final int columnsPerPage;
  final double columnGap;
  final EdgeInsetsGeometry pagePadding;
  final TextStyle? textStyle;
  final Map<int, TextStyle> headingStyles;
  final HtmlRefTapCallback? onRefTap;
  final HtmlImageTapCallback? onImageTap;
  final HtmlImageBuilder? imageBuilder;
  final HtmlImageBytesBuilder? imageBytesBuilder;
  final HtmlContentParser? parser;
  final String? externalCss;
  final String? Function(String href)? externalCssResolver;

  /// Optional custom builder for blocks. Return null to use the default widget.
  final Widget? Function(BuildContext context, HtmlBlockNode block)?
  blockBuilder;

  /// Optional [HtmlReaderController] for programmatic page and reference control.
  final HtmlReaderController? controller;

  /// Called with the total page count when the reader has laid out. Use to enable/disable next/previous buttons or show "Page X of Y".
  final void Function(int pageCount)? onPageCountChanged;

  /// Called with the total column count when the reader has laid out.
  final void Function(int columnCount)? onColumnCountChanged;

  /// Called with a map of HTML id -> page index after layout.
  final void Function(Map<String, int> bookmarkIndex)? onBookmarkIndexChanged;

  /// Called with a map of HTML id -> absolute column index after layout.
  final void Function(Map<String, int> bookmarkColumnIndex)?
  onBookmarkColumnIndexChanged;

  /// Called with a map of HTML id -> all matching page indexes after layout.
  final void Function(Map<String, List<int>> bookmarkPageCandidates)?
  onBookmarkPageCandidatesChanged;

  @override
  Widget build(BuildContext context) {
    final baseStyle = textStyle ?? Theme.of(context).textTheme.bodyMedium!;
    final effectiveParser = parser ?? HtmlContentParser();
    final blocks = effectiveParser.parse(
      html,
      externalCss: externalCss,
      externalCssResolver: externalCssResolver,
    );
    final documentStyle = effectiveParser.parseDocumentStyle(
      html,
      externalCss: externalCss,
      externalCssResolver: externalCssResolver,
    );
    final documentBackgroundColor =
        documentStyle.blockBackgroundColor ?? documentStyle.backgroundColor;

    final content = LayoutBuilder(
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
            .clamp(1.0, double.infinity);

        final columns = _partitionIntoColumns(
          blocks,
          columnWidth: columnWidth,
          viewportHeight: viewportHeight,
          baseStyle: baseStyle,
        );
        final pages = _groupColumnsIntoPages(columns, columnsPerPage);
        final bookmarkIndex = _buildBookmarkIndex(pages);
        final bookmarkColumnIndex = _buildBookmarkColumnIndex(columns);
        final bookmarkPageCandidates = _buildBookmarkPageCandidates(pages);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          onPageCountChanged?.call(pages.length);
          onColumnCountChanged?.call(columns.length);
          onBookmarkIndexChanged?.call(bookmarkIndex);
          onBookmarkColumnIndexChanged?.call(bookmarkColumnIndex);
          onBookmarkPageCandidatesChanged?.call(bookmarkPageCandidates);
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
                              onImageTap: onImageTap,
                              imageBuilder: imageBuilder,
                              imageBytesBuilder: imageBytesBuilder,
                              viewportHeight: viewportHeight,
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
    if (documentBackgroundColor == null) {
      return content;
    }
    return ColoredBox(color: documentBackgroundColor, child: content);
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
    const interBlockSpacing = 12.0;
    final maxHeight = viewportHeight;

    for (final block in blocks) {
      if (block is HtmlColumnBreakBlockNode) {
        if (currentColumn.isNotEmpty) {
          columns.add(currentColumn);
          currentColumn = <HtmlBlockNode>[];
          currentHeight = 0;
        }
        continue;
      }

      final estimate = block.estimateHeight(
        columnWidth: columnWidth,
        baseTextStyle: baseStyle,
        viewportHeight: viewportHeight,
      );
      final spacingBefore = currentColumn.isEmpty ? 0.0 : interBlockSpacing;
      final projected = currentHeight + spacingBefore + estimate;
      if (currentColumn.isNotEmpty && projected > maxHeight) {
        columns.add(currentColumn);
        currentColumn = <HtmlBlockNode>[block];
        currentHeight = estimate;
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

  Map<String, int> _buildBookmarkColumnIndex(
    List<List<HtmlBlockNode>> columns,
  ) {
    final index = <String, int>{};
    for (var columnIndex = 0; columnIndex < columns.length; columnIndex++) {
      for (final block in columns[columnIndex]) {
        final id = block.id;
        if (id == null || id.trim().isEmpty || index.containsKey(id)) {
          continue;
        }
        index[id] = columnIndex;
      }
    }
    return Map<String, int>.unmodifiable(index);
  }

  Map<String, List<int>> _buildBookmarkPageCandidates(
    List<List<List<HtmlBlockNode>>> pages,
  ) {
    final candidates = <String, List<int>>{};
    for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      for (final column in pages[pageIndex]) {
        for (final block in column) {
          final id = block.id;
          if (id == null || id.trim().isEmpty) {
            continue;
          }
          candidates.putIfAbsent(id, () => <int>[]).add(pageIndex);
        }
      }
    }
    return Map<String, List<int>>.unmodifiable(
      candidates.map(
        (key, value) =>
            MapEntry<String, List<int>>(key, List<int>.unmodifiable(value)),
      ),
    );
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
        // physics: const NeverScrollableScrollPhysics(),
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
