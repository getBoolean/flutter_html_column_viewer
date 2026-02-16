import 'package:flutter/material.dart';

@immutable
class HtmlStyleSide {
  const HtmlStyleSide({this.color, this.width, this.style});

  final Color? color;
  final double? width;
  final BorderStyle? style;

  bool get hasValue => color != null || width != null || style != null;

  HtmlStyleSide merge(HtmlStyleSide? other) {
    if (other == null) {
      return this;
    }
    return HtmlStyleSide(
      color: other.color ?? color,
      width: other.width ?? width,
      style: other.style ?? style,
    );
  }
}

@immutable
class HtmlBorderStyle {
  const HtmlBorderStyle({
    this.top = const HtmlStyleSide(),
    this.right = const HtmlStyleSide(),
    this.bottom = const HtmlStyleSide(),
    this.left = const HtmlStyleSide(),
  });

  final HtmlStyleSide top;
  final HtmlStyleSide right;
  final HtmlStyleSide bottom;
  final HtmlStyleSide left;

  bool get hasValue =>
      top.hasValue || right.hasValue || bottom.hasValue || left.hasValue;

  HtmlBorderStyle merge(HtmlBorderStyle? other) {
    if (other == null) {
      return this;
    }
    return HtmlBorderStyle(
      top: top.merge(other.top),
      right: right.merge(other.right),
      bottom: bottom.merge(other.bottom),
      left: left.merge(other.left),
    );
  }
}

@immutable
class HtmlBoxStyle {
  const HtmlBoxStyle({
    this.margin,
    this.padding,
    this.backgroundColor,
    this.border = const HtmlBorderStyle(),
  });

  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final HtmlBorderStyle border;

  HtmlBoxStyle merge(HtmlBoxStyle? other) {
    if (other == null) {
      return this;
    }
    return HtmlBoxStyle(
      margin: other.margin ?? margin,
      padding: other.padding ?? padding,
      backgroundColor: other.backgroundColor ?? backgroundColor,
      border: border.merge(other.border),
    );
  }
}

@immutable
class HtmlTextStyleSpec {
  const HtmlTextStyleSpec({
    this.color,
    this.backgroundColor,
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
  });

  final Color? color;
  final Color? backgroundColor;
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
}

enum HtmlFontVariant { normal, smallCaps }
