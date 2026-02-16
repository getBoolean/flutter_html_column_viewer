import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

typedef HtmlImageBuilder =
    Widget Function(BuildContext context, String src, String? alt);

typedef HtmlImageBytesBuilder =
    FutureOr<Uint8List?> Function(HtmlImageRef imageRef);

typedef HtmlRefTapCallback = void Function(HtmlReference reference);

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
    this.fontSize,
    this.fontWeight,
    this.fontStyle,
    this.decoration,
    this.textAlign,
  });

  final Color? color;
  final Color? backgroundColor;
  final double? fontSize;
  final FontWeight? fontWeight;
  final FontStyle? fontStyle;
  final TextDecoration? decoration;
  final TextAlign? textAlign;

  static const HtmlStyleData empty = HtmlStyleData();

  HtmlStyleData merge(HtmlStyleData? other) {
    if (other == null) {
      return this;
    }
    return HtmlStyleData(
      color: other.color ?? color,
      backgroundColor: other.backgroundColor ?? backgroundColor,
      fontSize: other.fontSize ?? fontSize,
      fontWeight: other.fontWeight ?? fontWeight,
      fontStyle: other.fontStyle ?? fontStyle,
      decoration: other.decoration ?? decoration,
      textAlign: other.textAlign ?? textAlign,
    );
  }

  TextStyle applyTo(TextStyle base) {
    return base.copyWith(
      color: color ?? base.color,
      backgroundColor: backgroundColor ?? base.backgroundColor,
      fontSize: fontSize ?? base.fontSize,
      fontWeight: fontWeight ?? base.fontWeight,
      fontStyle: fontStyle ?? base.fontStyle,
      decoration: decoration ?? base.decoration,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is HtmlStyleData &&
            runtimeType == other.runtimeType &&
            color == other.color &&
            backgroundColor == other.backgroundColor &&
            fontSize == other.fontSize &&
            fontWeight == other.fontWeight &&
            fontStyle == other.fontStyle &&
            decoration == other.decoration &&
            textAlign == other.textAlign;
  }

  @override
  int get hashCode => Object.hash(
    color,
    backgroundColor,
    fontSize,
    fontWeight,
    fontStyle,
    decoration,
    textAlign,
  );
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
  }) {
    final text = plainText.trim();
    if (text.isEmpty) {
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
    final effectiveStyle = style.applyTo(
      baseTextStyle.copyWith(
        fontSize: headingSize ?? baseTextStyle.fontSize,
        fontWeight: headingLevel != null
            ? FontWeight.w700
            : baseTextStyle.fontWeight,
        height: preformatted ? 1.35 : 1.45,
      ),
    );
    final measured = _measureTextHeight(
      text,
      style: effectiveStyle,
      maxWidth: columnWidth,
    );
    return measured + (headingLevel != null ? 12 : 8);
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
  }) {
    var total = 0.0;
    final itemWidth = (columnWidth - 22).clamp(40.0, double.infinity);
    final itemBaseStyle = style.applyTo(baseTextStyle).copyWith(height: 1.4);
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
    return total + 10;
  }
}

@immutable
class HtmlTableBlockNode extends HtmlBlockNode {
  const HtmlTableBlockNode({
    required this.rows,
    super.id,
    this.hasHeader = false,
  });

  final List<List<String>> rows;
  final bool hasHeader;

  @override
  double estimateHeight({
    required double columnWidth,
    required TextStyle baseTextStyle,
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
          style: baseTextStyle.copyWith(height: 1.3),
          maxWidth: (colWidth - 16).clamp(1.0, double.infinity),
        );
        if (h > rowHeight) {
          rowHeight = h;
        }
      }
      total += rowHeight + 16;
    }
    return total + 2;
  }
}

@immutable
class HtmlImageBlockNode extends HtmlBlockNode {
  const HtmlImageBlockNode({required this.src, this.alt, super.id});

  final String src;
  final String? alt;

  @override
  double estimateHeight({
    required double columnWidth,
    required TextStyle baseTextStyle,
  }) {
    final imageHeight = columnWidth * (9 / 16);
    final altText = alt?.trim();
    final altHeight = (altText == null || altText.isEmpty)
        ? 0.0
        : _measureTextHeight(
                altText,
                style: baseTextStyle.copyWith(
                  fontStyle: FontStyle.italic,
                  height: 1.35,
                ),
                maxWidth: columnWidth,
              ) +
              8;
    const verticalContainerPadding = 10.0 * 2;
    const metadataGap = 6.0;
    const metadataLineHeight = 16.0;
    const safetyBuffer = 2.0;
    return imageHeight +
        altHeight +
        verticalContainerPadding +
        metadataGap +
        metadataLineHeight +
        safetyBuffer;
  }
}

@immutable
class HtmlDividerBlockNode extends HtmlBlockNode {
  const HtmlDividerBlockNode({super.id});

  @override
  double estimateHeight({
    required double columnWidth,
    required TextStyle baseTextStyle,
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
  }) {
    return 0;
  }
}
