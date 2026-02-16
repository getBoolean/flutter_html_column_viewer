import 'package:csslib/parser.dart' as css_parser;
import 'package:flutter/material.dart';

import '../model/html_nodes.dart';

@immutable
class CssSimpleSelector {
  const CssSimpleSelector({
    this.tag,
    this.id,
    this.classes = const <String>{},
  });

  final String? tag;
  final String? id;
  final Set<String> classes;

  int get specificity =>
      (id != null ? 100 : 0) + (classes.length * 10) + (tag != null ? 1 : 0);

  bool matches({
    required String tagName,
    required String? elementId,
    required Set<String> elementClasses,
  }) {
    if (tag != null && tag != tagName.toLowerCase()) {
      return false;
    }
    if (id != null && id != (elementId?.toLowerCase())) {
      return false;
    }
    for (final className in classes) {
      if (!elementClasses.contains(className)) {
        return false;
      }
    }
    return true;
  }
}

@immutable
class CssStyleRule {
  const CssStyleRule({
    required this.selector,
    required this.style,
    required this.sourceOrder,
  });

  final CssSimpleSelector selector;
  final HtmlStyleData style;
  final int sourceOrder;

  int get specificity => selector.specificity;
}

class CssStyleParser {
  const CssStyleParser();

  HtmlStyleData parseInlineStyle(String? style) {
    if (style == null || style.trim().isEmpty) {
      return HtmlStyleData.empty;
    }

    final declarations = _parseDeclarations(style);
    if (declarations.isEmpty) {
      return HtmlStyleData.empty;
    }

    return _styleFromDeclarations(declarations);
  }

  List<CssStyleRule> parseStyleSheet(String? css, {int startSourceOrder = 0}) {
    if (css == null || css.trim().isEmpty) {
      return const <CssStyleRule>[];
    }
    final parsedText = css.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
    final rules = <CssStyleRule>[];
    var sourceOrder = startSourceOrder;
    for (final match in RegExp(r'([^{}]+)\{([^{}]*)\}').allMatches(parsedText)) {
      final selectorGroup = match.group(1)?.trim() ?? '';
      final declarationsText = match.group(2)?.trim() ?? '';
      if (selectorGroup.isEmpty || declarationsText.isEmpty) {
        continue;
      }
      final declarations = _declarationMap(declarationsText);
      final styleData = _styleFromDeclarations(declarations);
      for (final selectorToken in selectorGroup.split(',')) {
        final selector = _parseSimpleSelector(selectorToken.trim());
        if (selector == null) {
          continue;
        }
        rules.add(
          CssStyleRule(
            selector: selector,
            style: styleData,
            sourceOrder: sourceOrder++,
          ),
        );
      }
    }
    return rules;
  }

  HtmlStyleData _styleFromDeclarations(Map<String, String> declarations) {
    final border = _parseBorderDeclaration(declarations['border']);
    final borderLeft = _parseBorderDeclaration(declarations['border-left']);
    return HtmlStyleData(
      color: _parseColor(declarations['color']),
      backgroundColor: _parseColor(declarations['background-color']),
      blockBackgroundColor: _parseColor(declarations['background-color']),
      fontSize: _parseFontSize(declarations['font-size']),
      fontWeight: _parseFontWeight(declarations['font-weight']),
      fontStyle: _parseFontStyle(declarations['font-style']),
      fontFamily: _parseFontFamily(declarations['font-family']),
      decoration: _parseTextDecoration(declarations['text-decoration']),
      textAlign: _parseTextAlign(declarations['text-align']),
      lineHeight: _parseLineHeight(declarations['line-height']),
      letterSpacing: _parseLength(
        declarations['letter-spacing'],
        percentBase: 16,
      ),
      wordSpacing: _parseLength(
        declarations['word-spacing'],
        percentBase: 16,
      ),
      textIndent: _parseLength(declarations['text-indent']),
      textTransform: _parseTextTransform(declarations['text-transform']),
      whiteSpace: _parseWhiteSpace(declarations['white-space']),
      margin: _parseBoxShorthand(
        shorthand: declarations['margin'],
        top: declarations['margin-top'],
        right: declarations['margin-right'],
        bottom: declarations['margin-bottom'],
        left: declarations['margin-left'],
      ),
      padding: _parseBoxShorthand(
        shorthand: declarations['padding'],
        top: declarations['padding-top'],
        right: declarations['padding-right'],
        bottom: declarations['padding-bottom'],
        left: declarations['padding-left'],
      ),
      listStyleType: _parseListStyleType(
        declarations['list-style-type'],
        listStyle: declarations['list-style'],
      ),
      listStylePosition: _parseListStylePosition(
        declarations['list-style-position'],
        listStyle: declarations['list-style'],
      ),
      listStyleImage: _parseListStyleImage(
        declarations['list-style-image'],
        listStyle: declarations['list-style'],
      ),
      borderLeftColor:
          _parseColor(declarations['border-left-color']) ??
          borderLeft?.color ??
          _parseColor(declarations['border-color']) ??
          border?.color,
      borderLeftWidth:
          _parseLength(declarations['border-left-width']) ??
          borderLeft?.width ??
          _parseLength(declarations['border-width']) ??
          border?.width,
      borderLeftStyle:
          _parseBorderStyle(declarations['border-left-style']) ??
          borderLeft?.style ??
          _parseBorderStyle(declarations['border-style']) ??
          border?.style,
    );
  }

  Map<String, String> _parseDeclarations(String style) {
    final sheet = css_parser.parse('* { $style }');
    final normalized = sheet.toString();
    final openBrace = normalized.indexOf('{');
    final closeBrace = normalized.lastIndexOf('}');
    if (openBrace == -1 || closeBrace == -1 || closeBrace <= openBrace) {
      return _fallbackParse(style);
    }

    final body = normalized.substring(openBrace + 1, closeBrace);
    return _declarationMap(body);
  }

  Map<String, String> _fallbackParse(String style) {
    return _declarationMap(style);
  }

  Map<String, String> _declarationMap(String text) {
    final out = <String, String>{};
    final parts = text.split(';');
    for (final part in parts) {
      final token = part.trim();
      if (token.isEmpty) {
        continue;
      }
      final colonIndex = token.indexOf(':');
      if (colonIndex <= 0) {
        continue;
      }
      final key = token.substring(0, colonIndex).trim().toLowerCase();
      final value = token.substring(colonIndex + 1).trim();
      if (key.isNotEmpty && value.isNotEmpty) {
        out[key] = value;
      }
    }
    return out;
  }

  double? _parseFontSize(String? value) {
    if (value == null) {
      return null;
    }
    return _parseLength(value, percentBase: 16);
  }

  double? _parseLineHeight(String? value) {
    if (value == null) {
      return null;
    }
    final v = value.trim().toLowerCase();
    if (v == 'normal') {
      return null;
    }
    if (v.endsWith('%')) {
      final pct = double.tryParse(v.substring(0, v.length - 1));
      return pct == null ? null : pct / 100;
    }
    final unitless = double.tryParse(v);
    if (unitless != null) {
      return unitless;
    }
    final length = _parseLength(v);
    if (length == null) {
      return null;
    }
    return length / 16;
  }

  FontWeight? _parseFontWeight(String? value) {
    if (value == null) {
      return null;
    }
    final v = value.trim().toLowerCase();
    if (v == 'bold') {
      return FontWeight.w700;
    }
    final n = int.tryParse(v);
    if (n == null) {
      return null;
    }
    if (n >= 700) {
      return FontWeight.w700;
    }
    if (n >= 600) {
      return FontWeight.w600;
    }
    if (n >= 500) {
      return FontWeight.w500;
    }
    if (n >= 400) {
      return FontWeight.w400;
    }
    return FontWeight.w300;
  }

  FontStyle? _parseFontStyle(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'italic' || normalized == 'oblique') {
      return FontStyle.italic;
    }
    if (normalized == 'normal') {
      return FontStyle.normal;
    }
    return null;
  }

  String? _parseFontFamily(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final first = value.split(',').first.trim();
    if (first.isEmpty) {
      return null;
    }
    if ((first.startsWith('"') && first.endsWith('"')) ||
        (first.startsWith("'") && first.endsWith("'"))) {
      return first.substring(1, first.length - 1);
    }
    return first;
  }

  TextDecoration? _parseTextDecoration(String? value) {
    if (value == null) {
      return null;
    }
    final v = value.toLowerCase();
    if (v.contains('underline')) {
      return TextDecoration.underline;
    }
    if (v.contains('line-through')) {
      return TextDecoration.lineThrough;
    }
    if (v.contains('overline')) {
      return TextDecoration.overline;
    }
    if (v.contains('none')) {
      return TextDecoration.none;
    }
    return null;
  }

  TextAlign? _parseTextAlign(String? value) {
    if (value == null) {
      return null;
    }
    switch (value.trim().toLowerCase()) {
      case 'left':
        return TextAlign.left;
      case 'right':
        return TextAlign.right;
      case 'center':
        return TextAlign.center;
      case 'justify':
        return TextAlign.justify;
      default:
        return null;
    }
  }

  HtmlTextTransform? _parseTextTransform(String? value) {
    if (value == null) {
      return null;
    }
    switch (value.trim().toLowerCase()) {
      case 'capitalize':
        return HtmlTextTransform.capitalize;
      case 'uppercase':
        return HtmlTextTransform.uppercase;
      case 'lowercase':
        return HtmlTextTransform.lowercase;
      case 'none':
        return HtmlTextTransform.none;
      default:
        return null;
    }
  }

  HtmlWhiteSpace? _parseWhiteSpace(String? value) {
    if (value == null) {
      return null;
    }
    switch (value.trim().toLowerCase()) {
      case 'normal':
        return HtmlWhiteSpace.normal;
      case 'pre':
        return HtmlWhiteSpace.pre;
      case 'nowrap':
        return HtmlWhiteSpace.nowrap;
      case 'pre-wrap':
        return HtmlWhiteSpace.preWrap;
      case 'pre-line':
        return HtmlWhiteSpace.preLine;
      default:
        return null;
    }
  }

  HtmlListStyleType? _parseListStyleType(String? value, {String? listStyle}) {
    final candidate = value ?? listStyle;
    if (candidate == null) {
      return null;
    }
    final v = candidate.trim().toLowerCase();
    if (v.contains('disc')) return HtmlListStyleType.disc;
    if (v.contains('circle')) return HtmlListStyleType.circle;
    if (v.contains('square')) return HtmlListStyleType.square;
    if (v.contains('decimal-leading-zero')) {
      return HtmlListStyleType.decimalLeadingZero;
    }
    if (v.contains('decimal')) return HtmlListStyleType.decimal;
    if (v.contains('lower-roman')) return HtmlListStyleType.lowerRoman;
    if (v.contains('upper-roman')) return HtmlListStyleType.upperRoman;
    if (v.contains('lower-alpha')) return HtmlListStyleType.lowerAlpha;
    if (v.contains('upper-alpha')) return HtmlListStyleType.upperAlpha;
    if (v.contains('lower-latin')) return HtmlListStyleType.lowerLatin;
    if (v.contains('upper-latin')) return HtmlListStyleType.upperLatin;
    if (v.contains('none')) return HtmlListStyleType.none;
    return null;
  }

  HtmlListStylePosition? _parseListStylePosition(
    String? value, {
    String? listStyle,
  }) {
    final candidate = value ?? listStyle;
    if (candidate == null) {
      return null;
    }
    final v = candidate.trim().toLowerCase();
    if (v.contains('inside')) return HtmlListStylePosition.inside;
    if (v.contains('outside')) return HtmlListStylePosition.outside;
    return null;
  }

  String? _parseListStyleImage(String? value, {String? listStyle}) {
    final candidate = value ?? listStyle;
    if (candidate == null) {
      return null;
    }
    final match = RegExp(r'url\((.+)\)', caseSensitive: false).firstMatch(
      candidate,
    );
    if (match == null) {
      return null;
    }
    var raw = match.group(1)?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    if ((raw.startsWith('"') && raw.endsWith('"')) ||
        (raw.startsWith("'") && raw.endsWith("'"))) {
      raw = raw.substring(1, raw.length - 1);
    }
    return raw;
  }

  EdgeInsets? _parseBoxShorthand({
    required String? shorthand,
    required String? top,
    required String? right,
    required String? bottom,
    required String? left,
  }) {
    final explicitTop = _parseLength(top);
    final explicitRight = _parseLength(right);
    final explicitBottom = _parseLength(bottom);
    final explicitLeft = _parseLength(left);
    if (explicitTop != null ||
        explicitRight != null ||
        explicitBottom != null ||
        explicitLeft != null) {
      return EdgeInsets.only(
        top: explicitTop ?? 0,
        right: explicitRight ?? 0,
        bottom: explicitBottom ?? 0,
        left: explicitLeft ?? 0,
      );
    }
    if (shorthand == null) {
      return null;
    }
    final tokens = shorthand
        .trim()
        .split(RegExp(r'\s+'))
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) {
      return null;
    }
    final values = tokens.map(_parseLength).toList(growable: false);
    if (values.any((value) => value == null)) {
      return null;
    }
    final v = values.cast<double>();
    if (v.length == 1) {
      return EdgeInsets.all(v[0]);
    }
    if (v.length == 2) {
      return EdgeInsets.symmetric(vertical: v[0], horizontal: v[1]);
    }
    if (v.length == 3) {
      return EdgeInsets.fromLTRB(v[1], v[0], v[1], v[2]);
    }
    return EdgeInsets.fromLTRB(v[3], v[0], v[1], v[2]);
  }

  _BorderParts? _parseBorderDeclaration(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final tokens = value.split(RegExp(r'\s+'));
    Color? color;
    double? width;
    BorderStyle? style;
    for (final token in tokens) {
      color ??= _parseColor(token);
      width ??= _parseLength(token);
      style ??= _parseBorderStyle(token);
    }
    if (color == null && width == null && style == null) {
      return null;
    }
    return _BorderParts(color: color, width: width, style: style);
  }

  BorderStyle? _parseBorderStyle(String? value) {
    if (value == null) {
      return null;
    }
    switch (value.trim().toLowerCase()) {
      case 'solid':
      case 'double':
      case 'dashed':
      case 'dotted':
      case 'groove':
      case 'ridge':
      case 'inset':
      case 'outset':
        return BorderStyle.solid;
      case 'none':
      case 'hidden':
        return BorderStyle.none;
      default:
        return null;
    }
  }

  double? _parseLength(String? value, {double? percentBase}) {
    if (value == null) {
      return null;
    }
    final v = value.trim().toLowerCase();
    if (v == '0') {
      return 0;
    }
    final match = RegExp(r'^(-?[\d.]+)\s*(px|pt|em|rem|%)?$').firstMatch(v);
    if (match == null) {
      return null;
    }
    final number = double.tryParse(match.group(1)!);
    if (number == null) {
      return null;
    }
    final unit = match.group(2) ?? 'px';
    switch (unit) {
      case 'px':
        return number;
      case 'pt':
        return number * (96 / 72);
      case 'em':
      case 'rem':
        return number * 16;
      case '%':
        if (percentBase == null) {
          return null;
        }
        return (number / 100) * percentBase;
      default:
        return null;
    }
  }

  Color? _parseColor(String? value) {
    if (value == null) {
      return null;
    }
    final v = value.trim().toLowerCase();
    if (v.startsWith('#')) {
      final hex = v.substring(1);
      if (hex.length == 3) {
        final expanded =
            '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}';
        return Color(int.parse('ff$expanded', radix: 16));
      }
      if (hex.length == 6) {
        return Color(int.parse('ff$hex', radix: 16));
      }
      if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
      return null;
    }

    final rgb = RegExp(r'rgb\(\s*(\d+),\s*(\d+),\s*(\d+)\s*\)').firstMatch(v);
    if (rgb != null) {
      return Color.fromRGBO(
        int.parse(rgb.group(1)!),
        int.parse(rgb.group(2)!),
        int.parse(rgb.group(3)!),
        1,
      );
    }

    final rgba = RegExp(
      r'rgba\(\s*(\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\s*\)',
    ).firstMatch(v);
    if (rgba != null) {
      return Color.fromRGBO(
        int.parse(rgba.group(1)!),
        int.parse(rgba.group(2)!),
        int.parse(rgba.group(3)!),
        double.parse(rgba.group(4)!),
      );
    }

    final hsl = RegExp(
      r'hsl\(\s*([\d.]+),\s*([\d.]+)%\s*,\s*([\d.]+)%\s*\)',
    ).firstMatch(v);
    if (hsl != null) {
      final h = double.parse(hsl.group(1)!);
      final s = double.parse(hsl.group(2)!) / 100;
      final l = double.parse(hsl.group(3)!) / 100;
      return HSLColor.fromAHSL(1, h, s, l).toColor();
    }

    final hsla = RegExp(
      r'hsla\(\s*([\d.]+),\s*([\d.]+)%\s*,\s*([\d.]+)%\s*,\s*([\d.]+)\s*\)',
    ).firstMatch(v);
    if (hsla != null) {
      final h = double.parse(hsla.group(1)!);
      final s = double.parse(hsla.group(2)!) / 100;
      final l = double.parse(hsla.group(3)!) / 100;
      final a = double.parse(hsla.group(4)!);
      return HSLColor.fromAHSL(a, h, s, l).toColor();
    }

    return _namedColors[v];
  }

  CssSimpleSelector? _parseSimpleSelector(String selector) {
    if (selector.isEmpty ||
        selector.contains(RegExp(r'[\s>+~:\[\*]')) ||
        selector.contains('::')) {
      return null;
    }
    final tagMatch = RegExp(r'^[a-zA-Z][\w-]*').firstMatch(selector);
    final tag = tagMatch?.group(0)?.toLowerCase();
    final tail = selector.substring(tag?.length ?? 0);
    final matches = RegExp(r'([#.])([\w-]+)').allMatches(tail).toList();
    var consumedLength = 0;
    String? id;
    final classes = <String>{};
    for (final match in matches) {
      consumedLength += match.group(0)!.length;
      final prefix = match.group(1)!;
      final value = match.group(2)!.toLowerCase();
      if (prefix == '#') {
        if (id != null) {
          return null;
        }
        id = value;
      } else {
        classes.add(value);
      }
    }
    if (consumedLength != tail.length) {
      return null;
    }
    if (tag == null && id == null && classes.isEmpty) {
      return null;
    }
    return CssSimpleSelector(tag: tag, id: id, classes: classes);
  }

  static const Map<String, Color> _namedColors = <String, Color>{
    'black': Colors.black,
    'white': Colors.white,
    'red': Colors.red,
    'green': Colors.green,
    'blue': Colors.blue,
    'yellow': Colors.yellow,
    'orange': Colors.orange,
    'purple': Colors.purple,
    'gray': Colors.grey,
    'grey': Colors.grey,
    'brown': Colors.brown,
    'teal': Colors.teal,
    'pink': Colors.pink,
  };
}

class _BorderParts {
  const _BorderParts({this.color, this.width, this.style});

  final Color? color;
  final double? width;
  final BorderStyle? style;
}
