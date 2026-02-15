import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'html_nodes.dart';

/// Shared context passed to all HTML block widgets (styles, callbacks, image builder).
@immutable
class HtmlBlockContext {
  const HtmlBlockContext({
    required this.baseStyle,
    this.headingStyles = const <int, TextStyle>{},
    this.onRefTap,
    this.imageBuilder,
  });

  final TextStyle baseStyle;
  final Map<int, TextStyle> headingStyles;
  final HtmlRefTapCallback? onRefTap;
  final HtmlImageBuilder? imageBuilder;

  TextStyle headingStyleFor(int level) {
    return headingStyles[level] ?? _defaultHeadingStyle(baseStyle, level);
  }

  static TextStyle _defaultHeadingStyle(TextStyle base, int level) {
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

/// Composable widget that renders a single [HtmlBlockNode] using [HtmlBlockContext].
class HtmlBlockView extends StatelessWidget {
  const HtmlBlockView({
    super.key,
    required this.block,
    required this.blockContext,
    this.builder,
  });

  final HtmlBlockNode block;
  final HtmlBlockContext blockContext;
  final Widget? Function(BuildContext context, HtmlBlockNode block)? builder;

  @override
  Widget build(BuildContext context) {
    if (builder != null) {
      final custom = builder!(context, block);
      if (custom != null) return custom;
    }
    if (block is HtmlTextBlockNode) {
      return HtmlTextBlock(
        node: block as HtmlTextBlockNode,
        blockContext: blockContext,
      );
    }
    if (block is HtmlListBlockNode) {
      return HtmlListBlock(
        node: block as HtmlListBlockNode,
        blockContext: blockContext,
      );
    }
    if (block is HtmlTableBlockNode) {
      return HtmlTableBlock(
        node: block as HtmlTableBlockNode,
        blockContext: blockContext,
      );
    }
    if (block is HtmlImageBlockNode) {
      return HtmlImageBlock(
        node: block as HtmlImageBlockNode,
        blockContext: blockContext,
      );
    }
    if (block is HtmlDividerBlockNode) {
      return const HtmlDividerBlock();
    }
    return const SizedBox.shrink();
  }
}

/// Renders [HtmlTextBlockNode]: paragraphs, headings, blockquotes, preformatted text.
class HtmlTextBlock extends StatelessWidget {
  const HtmlTextBlock({
    super.key,
    required this.node,
    required this.blockContext,
  });

  final HtmlTextBlockNode node;
  final HtmlBlockContext blockContext;

  @override
  Widget build(BuildContext context) {
    var effectiveStyle = node.style.applyTo(blockContext.baseStyle);
    if (node.headingLevel != null) {
      effectiveStyle = blockContext.headingStyleFor(node.headingLevel!);
    }

    if (node.preformatted) {
      return _PreformattedBlock(node: node, effectiveStyle: effectiveStyle);
    }

    final spans = _buildSpans(effectiveStyle);

    Widget content = RichText(
      textAlign: node.style.textAlign ?? TextAlign.start,
      text: TextSpan(style: effectiveStyle, children: spans),
    );

    if (node.isBlockquote) {
      content = _BlockquoteWrapper(child: content);
    }
    return content;
  }

  List<InlineSpan> _buildSpans(TextStyle effectiveStyle) {
    final spans = <InlineSpan>[];
    for (final segment in node.segments) {
      final segmentStyle = segment.style.applyTo(
        segment.isCode
            ? effectiveStyle.copyWith(fontFamily: 'monospace')
            : effectiveStyle,
      );

      if (segment.reference != null && blockContext.onRefTap != null) {
        spans.add(
          TextSpan(
            text: segment.text,
            style: segmentStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => blockContext.onRefTap!(segment.reference!),
          ),
        );
      } else {
        spans.add(TextSpan(text: segment.text, style: segmentStyle));
      }
    }
    return spans;
  }
}

class _PreformattedBlock extends StatelessWidget {
  const _PreformattedBlock({required this.node, required this.effectiveStyle});

  final HtmlTextBlockNode node;
  final TextStyle effectiveStyle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Text(
          node.plainText,
          style: effectiveStyle.copyWith(fontFamily: 'monospace'),
        ),
      ),
    );
  }
}

class _BlockquoteWrapper extends StatelessWidget {
  const _BlockquoteWrapper({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Theme.of(context).dividerColor, width: 4),
        ),
      ),
      padding: const EdgeInsets.only(left: 12),
      child: child,
    );
  }
}

/// Renders [HtmlListBlockNode]: ordered and unordered lists.
class HtmlListBlock extends StatelessWidget {
  const HtmlListBlock({
    super.key,
    required this.node,
    required this.blockContext,
  });

  final HtmlListBlockNode node;
  final HtmlBlockContext blockContext;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List<Widget>.generate(node.items.length, (index) {
        final bullet = node.ordered ? '${index + 1}.' : '\u2022';
        final segments = node.items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 20,
                child: Text(bullet, style: blockContext.baseStyle),
              ),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: node.style.applyTo(blockContext.baseStyle),
                    children: segments
                        .map(
                          (segment) => TextSpan(
                            text: segment.text,
                            style: segment.style.applyTo(
                              blockContext.baseStyle,
                            ),
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
}

/// Renders [HtmlTableBlockNode].
class HtmlTableBlock extends StatelessWidget {
  const HtmlTableBlock({
    super.key,
    required this.node,
    required this.blockContext,
  });

  final HtmlTableBlockNode node;
  final HtmlBlockContext blockContext;

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).dividerColor;
    final rows = node.rows;
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxColumns = rows.fold<int>(
      0,
      (previousValue, row) =>
          row.length > previousValue ? row.length : previousValue,
    );

    Widget buildTable(Map<int, TableColumnWidth> columnWidths) {
      return Table(
        border: TableBorder.all(color: borderColor),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: columnWidths,
        children: List<TableRow>.generate(rows.length, (rowIndex) {
          final row = rows[rowIndex];
          return TableRow(
            decoration: node.hasHeader && rowIndex == 0
                ? BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  )
                : null,
            children: List<Widget>.generate(maxColumns, (colIndex) {
              final text = colIndex < row.length ? row[colIndex] : '';
              return Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  text,
                  softWrap: true,
                  style: rowIndex == 0 && node.hasHeader
                      ? blockContext.baseStyle.copyWith(
                          fontWeight: FontWeight.w700,
                        )
                      : blockContext.baseStyle,
                ),
              );
            }),
          );
        }),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (maxWidth.isFinite && maxWidth > 0 && maxColumns > 0) {
          final columnWidth = (maxWidth / maxColumns).clamp(
            48.0,
            double.infinity,
          );
          return buildTable({
            for (var i = 0; i < maxColumns; i++)
              i: FixedColumnWidth(columnWidth),
          });
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: buildTable({
            for (var i = 0; i < maxColumns; i++)
              i: const IntrinsicColumnWidth(),
          }),
        );
      },
    );
  }
}

/// Renders [HtmlImageBlockNode]; uses [HtmlBlockContext.imageBuilder] when provided.
class HtmlImageBlock extends StatelessWidget {
  const HtmlImageBlock({
    super.key,
    required this.node,
    required this.blockContext,
  });

  final HtmlImageBlockNode node;
  final HtmlBlockContext blockContext;

  @override
  Widget build(BuildContext context) {
    if (blockContext.imageBuilder != null) {
      return blockContext.imageBuilder!(context, node.src, node.alt);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(
            node.src,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                padding: const EdgeInsets.all(10),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Text('Unable to load image: ${node.src}'),
              );
            },
          ),
        ),
        if (node.alt != null && node.alt!.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            node.alt!,
            style: blockContext.baseStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ],
    );
  }
}

/// Renders [HtmlDividerBlockNode].
class HtmlDividerBlock extends StatelessWidget {
  const HtmlDividerBlock({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1);
  }
}
