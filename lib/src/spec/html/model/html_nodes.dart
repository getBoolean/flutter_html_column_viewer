import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'html_style_data.dart';
import 'html_style_provenance.dart';
import 'html_table_nodes.dart';

typedef HtmlImageBuilder =
    Widget Function(BuildContext context, String src, String? alt);

typedef HtmlImageBytesBuilder =
    FutureOr<Uint8List?> Function(HtmlImageRef imageRef);

typedef HtmlRefTapCallback = void Function(HtmlReference reference);
typedef HtmlImageTapCallback =
    void Function(Uint8List bytes, HtmlImageRef imageRef);

@immutable
class HtmlReference {
  const HtmlReference({
    required this.raw,
    this.uri,
    this.path,
    this.fragmentId,
    this.isCfiLike = false,
    this.epubType,
    this.role,
  });

  final String raw;
  final Uri? uri;
  final String? path;
  final String? fragmentId;
  final bool isCfiLike;
  final String? epubType;
  final String? role;

  static HtmlReference fromRaw(String raw, {String? epubType, String? role}) {
    final trimmed = raw.trim();
    final uri = Uri.tryParse(trimmed);
    final hashIndex = trimmed.indexOf('#');
    final path = hashIndex >= 0
        ? trimmed.substring(0, hashIndex).trim()
        : trimmed.trim();
    final fragment = hashIndex >= 0 ? trimmed.substring(hashIndex + 1) : null;
    final normalizedPath = path.isEmpty ? null : path;
    final isCfi =
        fragment != null &&
        fragment.isNotEmpty &&
        fragment.toLowerCase().startsWith('epubcfi(');

    return HtmlReference(
      raw: trimmed,
      uri: uri,
      path: normalizedPath,
      fragmentId: isCfi || fragment == null || fragment.isEmpty
          ? null
          : fragment,
      isCfiLike: isCfi,
      epubType: epubType,
      role: role,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is HtmlReference &&
            runtimeType == other.runtimeType &&
            raw == other.raw &&
            path == other.path &&
            fragmentId == other.fragmentId &&
            isCfiLike == other.isCfiLike &&
            epubType == other.epubType &&
            role == other.role;
  }

  @override
  int get hashCode =>
      Object.hash(raw, path, fragmentId, isCfiLike, epubType, role);
}

double _measureTextHeight(
  String text, {
  required TextStyle style,
  required double maxWidth,
}) {
  if (text.trim().isEmpty) {
    return (style.fontSize ?? 16) * 1.2;
  }
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: null,
  )..layout(maxWidth: maxWidth);
  return painter.height;
}

double _edgeVertical(EdgeInsets? insets) {
  if (insets == null) {
    return 0;
  }
  return insets.top + insets.bottom;
}

double _edgeHorizontal(EdgeInsets? insets) {
  if (insets == null) {
    return 0;
  }
  return insets.left + insets.right;
}

double _styleVerticalExtras(HtmlStyleData style) {
  final resolvedPadding = style.boxStyle?.padding ?? style.padding;
  final resolvedMargin = style.boxStyle?.margin ?? style.margin;
  final borderVertical =
      (style.borderTopWidth ?? 0) + (style.borderBottomWidth ?? 0);
  return _edgeVertical(resolvedPadding) +
      _edgeVertical(resolvedMargin) +
      borderVertical;
}

double _styleHorizontalInsets(HtmlStyleData style) {
  final resolvedPadding = style.boxStyle?.padding ?? style.padding;
  final resolvedMargin = style.boxStyle?.margin ?? style.margin;
  final borderHorizontal =
      (style.borderLeftWidth ?? 0) + (style.borderRightWidth ?? 0);
  return _edgeHorizontal(resolvedPadding) +
      _edgeHorizontal(resolvedMargin) +
      borderHorizontal;
}

@immutable
class HtmlImageRef {
  const HtmlImageRef({required this.src, this.alt, this.id});

  final String src;
  final String? alt;
  final String? id;

  factory HtmlImageRef.fromNode(HtmlImageBlockNode node) {
    return HtmlImageRef(src: node.src, alt: node.alt, id: node.id);
  }
}

@immutable
class HtmlStyleData {
  const HtmlStyleData({
    this.color,
    this.backgroundColor,
    this.blockBackgroundColor,
    this.fontSize,
    this.fontWeight,
    this.fontStyle,
    this.fontVariant,
    this.fontFamily,
    this.decoration,
    this.textAlign,
    this.lineHeight,
    this.letterSpacing,
    this.wordSpacing,
    this.textIndent,
    this.textTransform,
    this.whiteSpace,
    this.margin,
    this.padding,
    this.listStyleType,
    this.listStylePosition,
    this.listStyleImage,
    this.borderLeftColor,
    this.borderLeftWidth,
    this.borderLeftStyle,
    this.borderTopColor,
    this.borderTopWidth,
    this.borderTopStyle,
    this.borderRightColor,
    this.borderRightWidth,
    this.borderRightStyle,
    this.borderBottomColor,
    this.borderBottomWidth,
    this.borderBottomStyle,
    this.boxStyle,
    this.textStyle,
    this.provenance = HtmlStyleProvenance.empty,
  });

  final Color? color;
  final Color? backgroundColor;
  final Color? blockBackgroundColor;
  final double? fontSize;
  final FontWeight? fontWeight;
  final FontStyle? fontStyle;
  final HtmlFontVariant? fontVariant;
  final String? fontFamily;
  final TextDecoration? decoration;
  final TextAlign? textAlign;
  final double? lineHeight;
  final double? letterSpacing;
  final double? wordSpacing;
  final double? textIndent;
  final HtmlTextTransform? textTransform;
  final HtmlWhiteSpace? whiteSpace;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final HtmlListStyleType? listStyleType;
  final HtmlListStylePosition? listStylePosition;
  final String? listStyleImage;
  final Color? borderLeftColor;
  final double? borderLeftWidth;
  final BorderStyle? borderLeftStyle;
  final Color? borderTopColor;
  final double? borderTopWidth;
  final BorderStyle? borderTopStyle;
  final Color? borderRightColor;
  final double? borderRightWidth;
  final BorderStyle? borderRightStyle;
  final Color? borderBottomColor;
  final double? borderBottomWidth;
  final BorderStyle? borderBottomStyle;
  final HtmlBoxStyle? boxStyle;
  final HtmlTextStyleSpec? textStyle;
  final HtmlStyleProvenance provenance;

  static const HtmlStyleData empty = HtmlStyleData();

  HtmlStyleData merge(HtmlStyleData? other) {
    if (other == null) {
      return this;
    }
    return HtmlStyleData(
      color: other.color ?? color,
      backgroundColor: other.backgroundColor ?? backgroundColor,
      blockBackgroundColor: other.blockBackgroundColor ?? blockBackgroundColor,
      fontSize: other.fontSize ?? fontSize,
      fontWeight: other.fontWeight ?? fontWeight,
      fontStyle: other.fontStyle ?? fontStyle,
      fontVariant: other.fontVariant ?? fontVariant,
      fontFamily: other.fontFamily ?? fontFamily,
      decoration: other.decoration ?? decoration,
      textAlign: other.textAlign ?? textAlign,
      lineHeight: other.lineHeight ?? lineHeight,
      letterSpacing: other.letterSpacing ?? letterSpacing,
      wordSpacing: other.wordSpacing ?? wordSpacing,
      textIndent: other.textIndent ?? textIndent,
      textTransform: other.textTransform ?? textTransform,
      whiteSpace: other.whiteSpace ?? whiteSpace,
      margin: other.margin ?? margin,
      padding: other.padding ?? padding,
      listStyleType: other.listStyleType ?? listStyleType,
      listStylePosition: other.listStylePosition ?? listStylePosition,
      listStyleImage: other.listStyleImage ?? listStyleImage,
      borderLeftColor: other.borderLeftColor ?? borderLeftColor,
      borderLeftWidth: other.borderLeftWidth ?? borderLeftWidth,
      borderLeftStyle: other.borderLeftStyle ?? borderLeftStyle,
      borderTopColor: other.borderTopColor ?? borderTopColor,
      borderTopWidth: other.borderTopWidth ?? borderTopWidth,
      borderTopStyle: other.borderTopStyle ?? borderTopStyle,
      borderRightColor: other.borderRightColor ?? borderRightColor,
      borderRightWidth: other.borderRightWidth ?? borderRightWidth,
      borderRightStyle: other.borderRightStyle ?? borderRightStyle,
      borderBottomColor: other.borderBottomColor ?? borderBottomColor,
      borderBottomWidth: other.borderBottomWidth ?? borderBottomWidth,
      borderBottomStyle: other.borderBottomStyle ?? borderBottomStyle,
      boxStyle: (boxStyle ?? const HtmlBoxStyle()).merge(other.boxStyle),
      textStyle: other.textStyle ?? textStyle,
      provenance: provenance.merge(other.provenance),
    );
  }

  HtmlStyleData inheritableOnly() {
    return HtmlStyleData(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      fontVariant: fontVariant,
      fontFamily: fontFamily,
      textAlign: textAlign,
      lineHeight: lineHeight,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textIndent: textIndent,
      textTransform: textTransform,
      whiteSpace: whiteSpace,
      listStyleType: listStyleType,
      listStylePosition: listStylePosition,
      listStyleImage: listStyleImage,
      textStyle: textStyle,
    );
  }

  TextStyle applyToTextStyle(TextStyle base) {
    return base.copyWith(
      color: color ?? base.color,
      backgroundColor: backgroundColor ?? base.backgroundColor,
      fontSize: fontSize ?? base.fontSize,
      fontWeight: fontWeight ?? base.fontWeight,
      fontStyle: fontStyle ?? base.fontStyle,
      fontFeatures: _resolveFontFeatures(base.fontFeatures, fontVariant),
      fontFamily: fontFamily ?? base.fontFamily,
      decoration: decoration ?? base.decoration,
      height: lineHeight ?? base.height,
      letterSpacing: letterSpacing ?? base.letterSpacing,
      wordSpacing: wordSpacing ?? base.wordSpacing,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is HtmlStyleData &&
            runtimeType == other.runtimeType &&
            color == other.color &&
            backgroundColor == other.backgroundColor &&
            blockBackgroundColor == other.blockBackgroundColor &&
            fontSize == other.fontSize &&
            fontWeight == other.fontWeight &&
            fontStyle == other.fontStyle &&
            fontVariant == other.fontVariant &&
            fontFamily == other.fontFamily &&
            decoration == other.decoration &&
            textAlign == other.textAlign &&
            lineHeight == other.lineHeight &&
            letterSpacing == other.letterSpacing &&
            wordSpacing == other.wordSpacing &&
            textIndent == other.textIndent &&
            textTransform == other.textTransform &&
            whiteSpace == other.whiteSpace &&
            margin == other.margin &&
            padding == other.padding &&
            listStyleType == other.listStyleType &&
            listStylePosition == other.listStylePosition &&
            listStyleImage == other.listStyleImage &&
            borderLeftColor == other.borderLeftColor &&
            borderLeftWidth == other.borderLeftWidth &&
            borderLeftStyle == other.borderLeftStyle &&
            borderTopColor == other.borderTopColor &&
            borderTopWidth == other.borderTopWidth &&
            borderTopStyle == other.borderTopStyle &&
            borderRightColor == other.borderRightColor &&
            borderRightWidth == other.borderRightWidth &&
            borderRightStyle == other.borderRightStyle &&
            borderBottomColor == other.borderBottomColor &&
            borderBottomWidth == other.borderBottomWidth &&
            borderBottomStyle == other.borderBottomStyle &&
            boxStyle == other.boxStyle &&
            textStyle == other.textStyle;
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
    color,
    backgroundColor,
    blockBackgroundColor,
    fontSize,
    fontWeight,
    fontStyle,
    fontVariant,
    fontFamily,
    decoration,
    textAlign,
    lineHeight,
    letterSpacing,
    wordSpacing,
    textIndent,
    textTransform,
    whiteSpace,
    margin,
    padding,
    listStyleType,
    listStylePosition,
    listStyleImage,
    borderLeftColor,
    borderLeftWidth,
    borderLeftStyle,
    borderTopColor,
    borderTopWidth,
    borderTopStyle,
    borderRightColor,
    borderRightWidth,
    borderRightStyle,
    borderBottomColor,
    borderBottomWidth,
    borderBottomStyle,
    boxStyle,
    textStyle,
  ]);
}

List<FontFeature>? _resolveFontFeatures(
  List<FontFeature>? base,
  HtmlFontVariant? variant,
) {
  if (variant == null) {
    return base;
  }
  final existing = <FontFeature>[...?base];
  existing.removeWhere((feature) => feature.feature == 'smcp');
  if (variant == HtmlFontVariant.smallCaps) {
    existing.add(const FontFeature.enable('smcp'));
  }
  if (existing.isEmpty) {
    return null;
  }
  return existing;
}

enum HtmlTextTransform { capitalize, uppercase, lowercase, none }

enum HtmlWhiteSpace { normal, pre, nowrap, preWrap, preLine }

enum HtmlListStylePosition { inside, outside }

enum HtmlListStyleType {
  disc,
  circle,
  square,
  decimal,
  decimalLeadingZero,
  lowerRoman,
  upperRoman,
  lowerLatin,
  upperLatin,
  lowerAlpha,
  upperAlpha,
  none,
}

@immutable
class HtmlInlineSegment {
  const HtmlInlineSegment({
    required this.text,
    this.reference,
    this.style = HtmlStyleData.empty,
    this.isCode = false,
  });

  final String text;
  final HtmlReference? reference;
  final HtmlStyleData style;
  final bool isCode;
}

abstract class HtmlBlockNode {
  const HtmlBlockNode({this.id});

  final String? id;

  double estimateHeight({
    required double columnWidth,
    required TextStyle baseTextStyle,
    required double viewportHeight,
  });
}

@immutable
class HtmlTextBlockNode extends HtmlBlockNode {
  const HtmlTextBlockNode({
    required this.segments,
    super.id,
    this.headingLevel,
    this.style = HtmlStyleData.empty,
    this.isBlockquote = false,
    this.preformatted = false,
  });

  final List<HtmlInlineSegment> segments;
  final int? headingLevel;
  final HtmlStyleData style;
  final bool isBlockquote;
  final bool preformatted;

  String get plainText => segments.map((segment) => segment.text).join();

  @override
  double estimateHeight({
    required double columnWidth,
    required TextStyle baseTextStyle,
    required double viewportHeight,
  }) {
    final text = preformatted ? plainText : plainText.trim();
    if (text.trim().isEmpty) {
      return 20;
    }
    final headingSize = switch (headingLevel?.clamp(1, 6)) {
      1 => 32.0,
      2 => 28.0,
      3 => 24.0,
      4 => 21.0,
      5 => 18.0,
      6 => 16.0,
      _ => null,
    };
    final effectiveStyle = style.applyToTextStyle(
      baseTextStyle.copyWith(
        fontSize: headingSize ?? baseTextStyle.fontSize,
        fontWeight: headingLevel != null
            ? FontWeight.w700
            : baseTextStyle.fontWeight,
        height: style.lineHeight ?? (preformatted ? 1.35 : 1.45),
      ),
    );
    final preformattedHorizontalInset = preformatted ? 20.0 : 0.0;
    final preformattedVerticalInset = preformatted ? 20.0 : 0.0;
    final blockquoteHorizontalInset = isBlockquote
        ? 12.0 + (style.borderLeftWidth ?? 3.0)
        : 0.0;
    final textMaxWidth =
        (columnWidth -
                _styleHorizontalInsets(style) -
                blockquoteHorizontalInset -
                preformattedHorizontalInset)
            .clamp(40.0, double.infinity);
    final measuredStyle = preformatted
        ? effectiveStyle.copyWith(fontFamily: 'monospace')
        : effectiveStyle;
    final measured = _measureTextHeight(
      text,
      style: measuredStyle,
      maxWidth: textMaxWidth,
    );
    // Matches HtmlBlockquoteBlock's exact vertical margin (8 top + 8 bottom).
    final blockquoteVerticalMargin = isBlockquote ? 16.0 : 0.0;
    return measured +
        preformattedVerticalInset +
        blockquoteVerticalMargin +
        _styleVerticalExtras(style);
  }
}

@immutable
class HtmlListBlockNode extends HtmlBlockNode {
  const HtmlListBlockNode({
    required this.ordered,
    required this.items,
    super.id,
    this.style = HtmlStyleData.empty,
  });

  final bool ordered;
  final List<List<HtmlInlineSegment>> items;
  final HtmlStyleData style;

  @override
  double estimateHeight({
    required double columnWidth,
    required TextStyle baseTextStyle,
    required double viewportHeight,
  }) {
    var total = 0.0;
    final itemWidth = (columnWidth - 22).clamp(40.0, double.infinity);
    final itemBaseStyle = style
        .applyToTextStyle(baseTextStyle)
        .copyWith(height: style.lineHeight ?? 1.4);
    for (final item in items) {
      final text = item.map((segment) => segment.text).join().trim();
      total +=
          _measureTextHeight(
            text.isEmpty ? '•' : text,
            style: itemBaseStyle,
            maxWidth: itemWidth,
          ) +
          6;
    }
    return total + _styleVerticalExtras(style);
  }
}

@immutable
class HtmlTableBlockNode extends HtmlBlockNode {
  const HtmlTableBlockNode({
    required this.rows,
    super.id,
    this.hasHeader = false,
    this.tableModel,
    this.style = HtmlStyleData.empty,
  });

  final List<List<String>> rows;
  final bool hasHeader;
  final HtmlTableModel? tableModel;
  final HtmlStyleData style;

  @override
  double estimateHeight({
    required double columnWidth,
    required TextStyle baseTextStyle,
    required double viewportHeight,
  }) {
    if (rows.isEmpty) {
      return 0;
    }
    final maxCols = rows.fold<int>(
      0,
      (prev, row) => row.length > prev ? row.length : prev,
    );
    final minColWidth = columnWidth < 40.0 ? 0.0 : 40.0;
    final colWidth = maxCols == 0
        ? columnWidth
        : (columnWidth / maxCols).clamp(minColWidth, columnWidth);
    var total = 0.0;
    for (final row in rows) {
      var rowHeight = 0.0;
      for (final cell in row) {
        final h = _measureTextHeight(
          cell,
          style: style
              .applyToTextStyle(baseTextStyle)
              .copyWith(height: style.lineHeight ?? 1.3),
          maxWidth: (colWidth - 16).clamp(1.0, double.infinity),
        );
        if (h > rowHeight) {
          rowHeight = h;
        }
      }
      total += rowHeight + 16;
    }
    return total + 2 + _styleVerticalExtras(style);
  }
}

@immutable
class HtmlImageBlockNode extends HtmlBlockNode {
  const HtmlImageBlockNode({
    required this.src,
    this.alt,
    this.intrinsicAspectRatio,
    super.id,
  });

  final String src;
  final String? alt;
  final double? intrinsicAspectRatio;

  @override
  double estimateHeight({
    required double columnWidth,
    required TextStyle baseTextStyle,
    required double viewportHeight,
  }) {
    final aspectRatio = intrinsicAspectRatio;
    final imageHeight = aspectRatio != null && aspectRatio > 0
        ? columnWidth / aspectRatio
        : viewportHeight;
    const safetyBuffer = 2.0;
    return imageHeight + safetyBuffer;
  }
}

@immutable
class HtmlDividerBlockNode extends HtmlBlockNode {
  const HtmlDividerBlockNode({super.id});

  @override
  double estimateHeight({
    required double columnWidth,
    required TextStyle baseTextStyle,
    required double viewportHeight,
  }) {
    return 28;
  }
}

@immutable
class HtmlColumnBreakBlockNode extends HtmlBlockNode {
  const HtmlColumnBreakBlockNode({super.id});

  @override
  double estimateHeight({
    required double columnWidth,
    required TextStyle baseTextStyle,
    required double viewportHeight,
  }) {
    return 0;
  }
}
