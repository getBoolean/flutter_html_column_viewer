import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show Theme, CircularProgressIndicator, Divider;
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;

import '../model/html_nodes.dart';
import 'blocks/html_blockquote_block.dart';
import 'blocks/html_table_block.dart';
import 'inline/html_inline_span_builder.dart';

/// Shared context passed to all HTML block widgets (styles, callbacks, image builder).
@immutable
class HtmlBlockContext {
  const HtmlBlockContext({
    required this.baseStyle,
    this.headingStyles = const <int, TextStyle>{},
    this.onRefTap,
    this.onImageTap,
    this.imageBuilder,
    this.imageBytesBuilder,
    this.viewportHeight,
  });

  final TextStyle baseStyle;
  final Map<int, TextStyle> headingStyles;
  final HtmlRefTapCallback? onRefTap;
  final HtmlImageTapCallback? onImageTap;
  final HtmlImageBuilder? imageBuilder;
  final HtmlImageBytesBuilder? imageBytesBuilder;
  final double? viewportHeight;

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
    if (block is HtmlColumnBreakBlockNode) {
      return const SizedBox.shrink();
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
  static const HtmlInlineSpanBuilder _inlineSpanBuilder =
      HtmlInlineSpanBuilder();

  @override
  Widget build(BuildContext context) {
    var effectiveStyle = node.style.applyToTextStyle(blockContext.baseStyle);
    if (node.headingLevel != null) {
      effectiveStyle = node.style.applyToTextStyle(
        blockContext.headingStyleFor(node.headingLevel!),
      );
    }

    if (node.preformatted) {
      final preformatted = _PreformattedBlock(
        node: node,
        effectiveStyle: effectiveStyle,
      );
      return _applyBlockDecorations(
        context: context,
        style: node.style,
        child: preformatted,
      );
    }

    final spans = _inlineSpanBuilder.buildTextSpans(
      node: node,
      baseStyle: effectiveStyle,
      onRefTap: blockContext.onRefTap,
    );
    final nowrap = node.style.whiteSpace == HtmlWhiteSpace.nowrap;

    Widget content = _buildSelectableRichText(
      context: context,
      textAlign: node.style.textAlign ?? TextAlign.start,
      softWrap: !nowrap,
      text: TextSpan(style: effectiveStyle, children: spans),
    );

    if (node.isBlockquote) {
      content = HtmlBlockquoteBlock(node: node, child: content);
    }
    return _applyBlockDecorations(
      context: context,
      style: node.style,
      child: content,
    );
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
    final textAlign = node.style.textAlign ?? TextAlign.start;
    final markerStyle = node.style.applyToTextStyle(blockContext.baseStyle);
    final insideMarker =
        node.style.listStylePosition == HtmlListStylePosition.inside;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List<Widget>.generate(node.items.length, (index) {
        final bullet = _markerForIndex(index);
        final segments = node.items[index];
        final itemText = _buildSelectableRichText(
          context: context,
          textAlign: textAlign,
          text: TextSpan(
            style: markerStyle,
            children: _inlineSpansForSegments(segments, markerStyle),
          ),
        );
        final child = insideMarker
            ? _buildSelectableRichText(
                context: context,
                textAlign: textAlign,
                text: TextSpan(
                  style: markerStyle,
                  children: <InlineSpan>[
                    TextSpan(text: '$bullet '),
                    ..._inlineSpansForSegments(segments, markerStyle),
                  ],
                ),
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(width: 20, child: Text(bullet, style: markerStyle)),
                  Expanded(child: itemText),
                ],
              );
        return Padding(padding: const EdgeInsets.only(bottom: 6), child: child);
      }),
    );
  }

  List<InlineSpan> _inlineSpansForSegments(
    List<HtmlInlineSegment> segments,
    TextStyle markerStyle,
  ) {
    return segments
        .map((segment) {
          final style = segment.style.applyToTextStyle(markerStyle);
          final reference = segment.reference;
          if (reference == null || blockContext.onRefTap == null) {
            return TextSpan(text: segment.text, style: style);
          }
          return TextSpan(
            text: segment.text,
            style: style,
            recognizer: TapGestureRecognizer()
              ..onTap = () => blockContext.onRefTap!(reference),
          );
        })
        .toList(growable: false);
  }

  String _markerForIndex(int index) {
    final type = node.style.listStyleType;
    if (type == HtmlListStyleType.none) {
      return '';
    }
    if (node.ordered) {
      switch (type) {
        case HtmlListStyleType.lowerAlpha:
        case HtmlListStyleType.lowerLatin:
          return '${_alpha(index, lower: true)}.';
        case HtmlListStyleType.upperAlpha:
        case HtmlListStyleType.upperLatin:
          return '${_alpha(index, lower: false)}.';
        case HtmlListStyleType.lowerRoman:
          return '${_roman(index + 1).toLowerCase()}.';
        case HtmlListStyleType.upperRoman:
          return '${_roman(index + 1).toUpperCase()}.';
        case HtmlListStyleType.decimalLeadingZero:
          return '${(index + 1).toString().padLeft(2, '0')}.';
        case HtmlListStyleType.none:
          return '';
        default:
          return '${index + 1}.';
      }
    }
    switch (type) {
      case HtmlListStyleType.circle:
        return '\u25E6';
      case HtmlListStyleType.square:
        return '\u25AA';
      case HtmlListStyleType.none:
        return '';
      default:
        return '\u2022';
    }
  }

  String _alpha(int index, {required bool lower}) {
    final value = (index % 26) + 97;
    final char = String.fromCharCode(value);
    return lower ? char : char.toUpperCase();
  }

  String _roman(int number) {
    final pairs = <MapEntry<int, String>>[
      const MapEntry<int, String>(1000, 'M'),
      const MapEntry<int, String>(900, 'CM'),
      const MapEntry<int, String>(500, 'D'),
      const MapEntry<int, String>(400, 'CD'),
      const MapEntry<int, String>(100, 'C'),
      const MapEntry<int, String>(90, 'XC'),
      const MapEntry<int, String>(50, 'L'),
      const MapEntry<int, String>(40, 'XL'),
      const MapEntry<int, String>(10, 'X'),
      const MapEntry<int, String>(9, 'IX'),
      const MapEntry<int, String>(5, 'V'),
      const MapEntry<int, String>(4, 'IV'),
      const MapEntry<int, String>(1, 'I'),
    ];
    var n = number;
    final out = StringBuffer();
    for (final pair in pairs) {
      while (n >= pair.key) {
        out.write(pair.value);
        n -= pair.key;
      }
    }
    return out.toString();
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
    if (node.tableModel != null) {
      final nestedContext = HtmlBlockContext(
        baseStyle: node.style.applyToTextStyle(blockContext.baseStyle),
        headingStyles: blockContext.headingStyles,
        onRefTap: blockContext.onRefTap,
        onImageTap: blockContext.onImageTap,
        imageBuilder: blockContext.imageBuilder,
        imageBytesBuilder: blockContext.imageBytesBuilder,
        viewportHeight: blockContext.viewportHeight,
      );
      return _applyBlockDecorations(
        context: context,
        style: node.style,
        child: HtmlSemanticTableBlock(
          node: node,
          baseStyle: blockContext.baseStyle,
          blockBuilder: (block) {
            return HtmlBlockView(block: block, blockContext: nestedContext);
          },
        ),
      );
    }
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
                  textAlign: node.style.textAlign,
                  style: rowIndex == 0 && node.hasHeader
                      ? node.style
                            .applyToTextStyle(blockContext.baseStyle)
                            .copyWith(fontWeight: FontWeight.w700)
                      : node.style.applyToTextStyle(blockContext.baseStyle),
                ),
              );
            }),
          );
        }),
      );
    }

    final table = LayoutBuilder(
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
    return _applyBlockDecorations(
      context: context,
      style: node.style,
      child: table,
    );
  }
}

/// Renders [HtmlImageBlockNode]; uses [HtmlBlockContext.imageBuilder] when provided.
class HtmlImageBlock extends StatefulWidget {
  const HtmlImageBlock({
    super.key,
    required this.node,
    required this.blockContext,
  });

  final HtmlImageBlockNode node;
  final HtmlBlockContext blockContext;

  @override
  State<HtmlImageBlock> createState() => _HtmlImageBlockState();
}

class _HtmlImageBlockState extends State<HtmlImageBlock> {
  static const double _fallbackAspectRatio = 16 / 9;

  Future<Uint8List?>? _bytesFuture;
  Uint8List? _resolvedBytes;

  @override
  void initState() {
    super.initState();
    _bytesFuture = _resolveBytesFuture();
  }

  @override
  void didUpdateWidget(covariant HtmlImageBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nodeChanged =
        oldWidget.node.src != widget.node.src ||
        oldWidget.node.alt != widget.node.alt ||
        oldWidget.node.id != widget.node.id;
    if (nodeChanged) {
      _resolvedBytes = null;
      _bytesFuture = _resolveBytesFuture();
    }
  }

  Future<Uint8List?>? _resolveBytesFuture() {
    final imageBytesBuilder = widget.blockContext.imageBytesBuilder;
    if (imageBytesBuilder == null) {
      return null;
    }
    final imageRef = HtmlImageRef.fromNode(widget.node);
    return Future<Uint8List?>.value(imageBytesBuilder(imageRef));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.blockContext.imageBuilder != null) {
      return widget.blockContext.imageBuilder!(
        context,
        widget.node.src,
        widget.node.alt,
      );
    }
    final imageRef = HtmlImageRef.fromNode(widget.node);
    final imageUrl = imageRef.src.trim();
    final onImageTap = widget.blockContext.onImageTap;

    void handleImageTap() {
      final bytes = _resolvedBytes;
      if (bytes == null || bytes.isEmpty || onImageTap == null) {
        return;
      }
      onImageTap(bytes, imageRef);
    }

    final constrainedImage = _bytesFuture == null
        ? AspectRatio(
            aspectRatio: _fallbackAspectRatio,
            child: _buildNetworkOrUnavailable(
              context: context,
              imageUrl: imageUrl,
              imageRef: imageRef,
            ),
          )
        : FutureBuilder<Uint8List?>(
            future: _bytesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const AspectRatio(
                  aspectRatio: _fallbackAspectRatio,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final bytes = snapshot.data;
              if (bytes != null && bytes.isNotEmpty) {
                _resolvedBytes = bytes;
                final aspectRatio =
                    _decodeAspectRatioFromBytes(bytes) ?? _fallbackAspectRatio;
                return AspectRatio(
                  aspectRatio: aspectRatio,
                  child: Image.memory(bytes, fit: BoxFit.contain),
                );
              }
              _resolvedBytes = null;
              return AspectRatio(
                aspectRatio: _fallbackAspectRatio,
                child: _buildUnavailable(context: context, imageRef: imageRef),
              );
            },
          );
    final maxImageHeight = widget.blockContext.viewportHeight;
    final image = maxImageHeight != null && maxImageHeight.isFinite
        ? ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxImageHeight),
            child: constrainedImage,
          )
        : constrainedImage;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onImageTap == null ? null : handleImageTap,
      child: image,
    );
  }

  double? _decodeAspectRatioFromBytes(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
      return null;
    }
    return decoded.width / decoded.height;
  }

  Widget _buildNetworkOrUnavailable({
    required BuildContext context,
    required String imageUrl,
    required HtmlImageRef imageRef,
  }) {
    final uri = Uri.tryParse(imageUrl);
    final isNetwork =
        uri != null &&
        (uri.scheme.toLowerCase() == 'http' ||
            uri.scheme.toLowerCase() == 'https');
    if (!isNetwork) {
      return _buildUnavailable(context: context, imageRef: imageRef);
    }
    return Image.network(
      imageUrl,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return const Center(child: CircularProgressIndicator());
      },
      errorBuilder: (context, error, stackTrace) {
        return _buildUnavailable(context: context, imageRef: imageRef);
      },
    );
  }

  Widget _buildUnavailable({
    required BuildContext context,
    required HtmlImageRef imageRef,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final altText = imageRef.alt?.trim();
    return ColoredBox(
      color: colorScheme.tertiaryContainer,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (altText != null && altText.isNotEmpty) ...<Widget>[
                Text(
                  altText,
                  style: TextStyle(
                    color: colorScheme.onTertiaryContainer,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
              ],
              Text(
                imageRef.src,
                style: TextStyle(color: colorScheme.onTertiaryContainer),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
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

RichText _buildSelectableRichText({
  required BuildContext context,
  required InlineSpan text,
  TextAlign textAlign = TextAlign.start,
  bool softWrap = true,
}) {
  return RichText(
    textAlign: textAlign,
    softWrap: softWrap,
    text: text,
    selectionRegistrar: SelectionContainer.maybeOf(context),
    selectionColor: DefaultSelectionStyle.of(context).selectionColor,
  );
}

Widget _applyBlockDecorations({
  required BuildContext context,
  required HtmlStyleData style,
  required Widget child,
}) {
  Widget current = child;
  final resolvedPadding = style.boxStyle?.padding ?? style.padding;
  final resolvedMargin = style.boxStyle?.margin ?? style.margin;
  final resolvedBackground =
      style.boxStyle?.backgroundColor ?? style.blockBackgroundColor;
  final resolvedWidthPx = style.boxStyle?.widthPx;
  final resolvedWidthFactor = style.boxStyle?.widthFactor;
  final border = _resolveBoxBorder(context, style);
  final hasContainerStyle =
      resolvedPadding != null || resolvedBackground != null || border != null;
  if (hasContainerStyle) {
    current = Container(
      padding: resolvedPadding,
      decoration: BoxDecoration(color: resolvedBackground, border: border),
      child: current,
    );
  }
  if (resolvedWidthPx != null && resolvedWidthPx > 0) {
    current = SizedBox(width: resolvedWidthPx, child: current);
  } else if (resolvedWidthFactor != null && resolvedWidthFactor > 0) {
    current = FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: resolvedWidthFactor,
      child: current,
    );
  }
  if (resolvedMargin != null) {
    current = Padding(padding: resolvedMargin, child: current);
  }
  return current;
}

Border? _resolveBoxBorder(BuildContext context, HtmlStyleData style) {
  BorderSide? side(Color? color, double? width, BorderStyle? borderStyle) {
    if ((width ?? 0) <= 0) {
      return null;
    }
    return BorderSide(
      width: width ?? 0,
      color: color ?? Theme.of(context).dividerColor,
      style: borderStyle ?? BorderStyle.solid,
    );
  }

  final top = side(
    style.borderTopColor,
    style.borderTopWidth,
    style.borderTopStyle,
  );
  final right = side(
    style.borderRightColor,
    style.borderRightWidth,
    style.borderRightStyle,
  );
  final bottom = side(
    style.borderBottomColor,
    style.borderBottomWidth,
    style.borderBottomStyle,
  );
  final left = side(
    style.borderLeftColor,
    style.borderLeftWidth,
    style.borderLeftStyle,
  );
  if (top == null && right == null && bottom == null && left == null) {
    return null;
  }
  return Border(
    top: top ?? BorderSide.none,
    right: right ?? BorderSide.none,
    bottom: bottom ?? BorderSide.none,
    left: left ?? BorderSide.none,
  );
}
