import 'package:html/dom.dart' as dom;
import 'package:flutter/material.dart';

import '../diagnostics/html_css_diagnostics.dart';
import '../diagnostics/html_css_warning.dart';
import '../model/html_style_data.dart';
import '../model/html_style_provenance.dart';
import '../model/html_nodes.dart';
import 'css_ast_adapter.dart';
import 'css_cascade_engine.dart';
import 'css_selector_engine.dart';

@immutable
class CssStyleRule {
  const CssStyleRule({
    required this.selector,
    required this.selectorText,
    required this.declarations,
    required this.style,
    required this.provenance,
    required this.sourceOrder,
  });

  final CssSelector selector;
  final String selectorText;
  final List<CssDeclaration> declarations;
  final HtmlStyleData style;
  final HtmlStyleProvenance provenance;
  final int sourceOrder;

  int get specificity => selector.specificity;
}

class CssStyleParser {
  CssStyleParser({HtmlCssDiagnostics? diagnostics})
    : _diagnostics = diagnostics ?? const HtmlCssDiagnostics(),
      _selectorEngine = const CssSelectorEngine(),
      _cascadeEngine = const CssCascadeEngine(),
      _astAdapter = CssAstAdapter(diagnostics: diagnostics);

  final HtmlCssDiagnostics _diagnostics;
  final CssSelectorEngine _selectorEngine;
  final CssCascadeEngine _cascadeEngine;
  final CssAstAdapter _astAdapter;

  HtmlStyleData parseInlineStyle(String? style) {
    if (style == null || style.trim().isEmpty) {
      return HtmlStyleData.empty;
    }
    final declarations = _astAdapter.parseInlineDeclarations(style);
    if (declarations.isEmpty) {
      return HtmlStyleData.empty;
    }
    return _styleFromDeclarations(
      declarations,
      selectorText: '<inline>',
      sourceOrder: 0,
      origin: HtmlStyleOrigin.inline,
    );
  }

  List<CssStyleRule> parseStyleSheet(String? css, {int startSourceOrder = 0}) {
    if (css == null || css.trim().isEmpty) {
      return const <CssStyleRule>[];
    }

    final parsed = _astAdapter.parseStyleSheet(
      css,
      startSourceOrder: startSourceOrder,
    );
    return parsed
        .map(
          (rule) => CssStyleRule(
            selector: rule.selector,
            selectorText: rule.selectorText,
            declarations: rule.declarations,
            style: _styleFromDeclarations(
              rule.declarations,
              selectorText: rule.selectorText,
              sourceOrder: rule.sourceOrder,
              origin: HtmlStyleOrigin.stylesheet,
            ),
            provenance: _provenanceFromDeclarations(
              rule.declarations,
              selectorText: rule.selectorText,
              sourceOrder: rule.sourceOrder,
              origin: HtmlStyleOrigin.stylesheet,
            ),
            sourceOrder: rule.sourceOrder,
          ),
        )
        .toList(growable: false);
  }

  bool matchesRule(CssStyleRule rule, dom.Element node) {
    return _selectorEngine.matches(rule.selector, node);
  }

  HtmlStyleData resolveMatchedRules(List<CssStyleRule> rules) {
    if (rules.isEmpty) {
      return HtmlStyleData.empty;
    }
    final parsed = rules
        .map(
          (rule) => CssParsedRule(
            selector: rule.selector,
            selectorText: rule.selectorText,
            declarations: rule.declarations,
            sourceOrder: rule.sourceOrder,
          ),
        )
        .toList(growable: false);
    final winning = _cascadeEngine.resolveDeclarations(parsed);
    return _styleFromDeclarations(
      winning,
      selectorText: '<cascade>',
      sourceOrder: 0,
      origin: HtmlStyleOrigin.stylesheet,
    );
  }

  HtmlStyleData _styleFromDeclarations(
    List<CssDeclaration> declarations, {
    required String selectorText,
    required int sourceOrder,
    required HtmlStyleOrigin origin,
  }) {
    final map = <String, String>{
      for (final declaration in declarations)
        declaration.property: declaration.value,
    };
    final border = _parseBorderDeclaration(map['border']);
    final borderLeft = _parseBorderDeclaration(map['border-left']);
    final borderTop = _parseBorderDeclaration(map['border-top']);
    final borderRight = _parseBorderDeclaration(map['border-right']);
    final borderBottom = _parseBorderDeclaration(map['border-bottom']);
    final sharedBorderColor = _parseColor(map['border-color']) ?? border?.color;
    final sharedBorderWidth =
        _parseLength(map['border-width']) ?? border?.width;
    final sharedBorderStyle =
        _parseBorderStyle(map['border-style']) ?? border?.style;
    final resolvedTop = _resolveBorderSide(
      explicit: _parseBorderDeclaration(map['border-top']),
      fallback: borderTop ?? border,
      colorOverride: _parseColor(map['border-top-color']),
      widthOverride: _parseLength(map['border-top-width']),
      styleOverride: _parseBorderStyle(map['border-top-style']),
      sharedColor: sharedBorderColor,
      sharedWidth: sharedBorderWidth,
      sharedStyle: sharedBorderStyle,
    );
    final resolvedRight = _resolveBorderSide(
      explicit: _parseBorderDeclaration(map['border-right']),
      fallback: borderRight ?? border,
      colorOverride: _parseColor(map['border-right-color']),
      widthOverride: _parseLength(map['border-right-width']),
      styleOverride: _parseBorderStyle(map['border-right-style']),
      sharedColor: sharedBorderColor,
      sharedWidth: sharedBorderWidth,
      sharedStyle: sharedBorderStyle,
    );
    final resolvedBottom = _resolveBorderSide(
      explicit: _parseBorderDeclaration(map['border-bottom']),
      fallback: borderBottom ?? border,
      colorOverride: _parseColor(map['border-bottom-color']),
      widthOverride: _parseLength(map['border-bottom-width']),
      styleOverride: _parseBorderStyle(map['border-bottom-style']),
      sharedColor: sharedBorderColor,
      sharedWidth: sharedBorderWidth,
      sharedStyle: sharedBorderStyle,
    );
    final resolvedLeft = _resolveBorderSide(
      explicit: borderLeft,
      fallback: borderLeft ?? border,
      colorOverride: _parseColor(map['border-left-color']),
      widthOverride: _parseLength(map['border-left-width']),
      styleOverride: _parseBorderStyle(map['border-left-style']),
      sharedColor: sharedBorderColor,
      sharedWidth: sharedBorderWidth,
      sharedStyle: sharedBorderStyle,
    );

    return HtmlStyleData(
      color: _parseColor(map['color']),
      backgroundColor: _parseColor(map['background-color']),
      blockBackgroundColor: _parseColor(map['background-color']),
      fontSize: _parseFontSize(map['font-size']),
      fontWeight: _parseFontWeight(map['font-weight']),
      fontStyle: _parseFontStyle(map['font-style']),
      fontVariant: _parseFontVariant(map['font-variant']),
      fontFamily: _parseFontFamily(map['font-family']),
      decoration: _parseTextDecoration(map['text-decoration']),
      textAlign: _parseTextAlign(map['text-align']),
      lineHeight: _parseLineHeight(map['line-height']),
      letterSpacing: _parseLength(map['letter-spacing'], percentBase: 16),
      wordSpacing: _parseLength(map['word-spacing'], percentBase: 16),
      textIndent: _parseLength(map['text-indent']),
      textTransform: _parseTextTransform(map['text-transform']),
      whiteSpace: _parseWhiteSpace(map['white-space']),
      margin: _parseBoxShorthand(
        shorthand: map['margin'],
        top: map['margin-top'],
        right: map['margin-right'],
        bottom: map['margin-bottom'],
        left: map['margin-left'],
      ),
      padding: _parseBoxShorthand(
        shorthand: map['padding'],
        top: map['padding-top'],
        right: map['padding-right'],
        bottom: map['padding-bottom'],
        left: map['padding-left'],
      ),
      listStyleType: _parseListStyleType(
        map['list-style-type'],
        listStyle: map['list-style'],
      ),
      listStylePosition: _parseListStylePosition(
        map['list-style-position'],
        listStyle: map['list-style'],
      ),
      listStyleImage: _parseListStyleImage(
        map['list-style-image'],
        listStyle: map['list-style'],
      ),
      borderTopColor: resolvedTop.color,
      borderTopWidth: resolvedTop.width,
      borderTopStyle: resolvedTop.style,
      borderRightColor: resolvedRight.color,
      borderRightWidth: resolvedRight.width,
      borderRightStyle: resolvedRight.style,
      borderBottomColor: resolvedBottom.color,
      borderBottomWidth: resolvedBottom.width,
      borderBottomStyle: resolvedBottom.style,
      borderLeftColor: resolvedLeft.color,
      borderLeftWidth: resolvedLeft.width,
      borderLeftStyle: resolvedLeft.style,
      boxStyle: HtmlBoxStyle(
        margin: _parseBoxShorthand(
          shorthand: map['margin'],
          top: map['margin-top'],
          right: map['margin-right'],
          bottom: map['margin-bottom'],
          left: map['margin-left'],
        ),
        padding: _parseBoxShorthand(
          shorthand: map['padding'],
          top: map['padding-top'],
          right: map['padding-right'],
          bottom: map['padding-bottom'],
          left: map['padding-left'],
        ),
        backgroundColor: _parseColor(map['background-color']),
        border: HtmlBorderStyle(
          top: HtmlStyleSide(
            color: resolvedTop.color,
            width: resolvedTop.width,
            style: resolvedTop.style,
          ),
          right: HtmlStyleSide(
            color: resolvedRight.color,
            width: resolvedRight.width,
            style: resolvedRight.style,
          ),
          bottom: HtmlStyleSide(
            color: resolvedBottom.color,
            width: resolvedBottom.width,
            style: resolvedBottom.style,
          ),
          left: HtmlStyleSide(
            color: resolvedLeft.color,
            width: resolvedLeft.width,
            style: resolvedLeft.style,
          ),
        ),
      ),
      textStyle: HtmlTextStyleSpec(
        color: _parseColor(map['color']),
        backgroundColor: _parseColor(map['background-color']),
        fontSize: _parseFontSize(map['font-size']),
        fontWeight: _parseFontWeight(map['font-weight']),
        fontStyle: _parseFontStyle(map['font-style']),
        fontVariant: _parseFontVariant(map['font-variant']),
        fontFamily: _parseFontFamily(map['font-family']),
        decoration: _parseTextDecoration(map['text-decoration']),
        textAlign: _parseTextAlign(map['text-align']),
        lineHeight: _parseLineHeight(map['line-height']),
        letterSpacing: _parseLength(map['letter-spacing'], percentBase: 16),
        wordSpacing: _parseLength(map['word-spacing'], percentBase: 16),
        textIndent: _parseLength(map['text-indent']),
      ),
      provenance: _provenanceFromDeclarations(
        declarations,
        selectorText: selectorText,
        sourceOrder: sourceOrder,
        origin: origin,
      ),
    );
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
    if (v == 'normal') {
      return FontWeight.w400;
    }
    if (v == 'bold') {
      return FontWeight.w700;
    }
    if (v == 'bolder') {
      return FontWeight.w700;
    }
    if (v == 'lighter') {
      return FontWeight.w300;
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

  HtmlFontVariant? _parseFontVariant(String? value) {
    if (value == null) {
      return null;
    }
    switch (value.trim().toLowerCase()) {
      case 'normal':
        return HtmlFontVariant.normal;
      case 'small-caps':
        return HtmlFontVariant.smallCaps;
      default:
        return null;
    }
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
    final decorations = <TextDecoration>[];
    if (v.contains('underline')) {
      decorations.add(TextDecoration.underline);
    }
    if (v.contains('line-through')) {
      decorations.add(TextDecoration.lineThrough);
    }
    if (v.contains('overline')) {
      decorations.add(TextDecoration.overline);
    }
    if (decorations.isNotEmpty) {
      return TextDecoration.combine(decorations);
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
    final match = RegExp(
      r'url\((.+)\)',
      caseSensitive: false,
    ).firstMatch(candidate);
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
      case 'initial':
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
    final match = RegExp(
      r'^(-?[\d.]+)\s*(px|pt|em|rem|%|vh|vw|vmin|vmax|ch|ex|cm|mm|in)?$',
    ).firstMatch(v);
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
      case 'vh':
      case 'vw':
      case 'vmin':
      case 'vmax':
        _diagnostics.warn(
          const HtmlCssWarning(
            code: 'viewport-unit-fallback',
            message:
                'Viewport unit parsed without viewport context; using px value.',
          ),
        );
        return number;
      case 'ch':
      case 'ex':
        return number * 8;
      case 'cm':
        return number * 37.7952755906;
      case 'mm':
        return number * 3.7795275591;
      case 'in':
        return number * 96;
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
    if (v == 'currentcolor') {
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
    'aqua': Color(0xFF00FFFF),
    'cyan': Color(0xFF00FFFF),
    'fuchsia': Color(0xFFFF00FF),
    'lime': Color(0xFF00FF00),
    'maroon': Color(0xFF800000),
    'navy': Color(0xFF000080),
    'olive': Color(0xFF808000),
    'silver': Color(0xFFC0C0C0),
  };

  _BorderParts _resolveBorderSide({
    required _BorderParts? explicit,
    required _BorderParts? fallback,
    required Color? colorOverride,
    required double? widthOverride,
    required BorderStyle? styleOverride,
    required Color? sharedColor,
    required double? sharedWidth,
    required BorderStyle? sharedStyle,
  }) {
    return _BorderParts(
      color: colorOverride ?? explicit?.color ?? fallback?.color ?? sharedColor,
      width: widthOverride ?? explicit?.width ?? fallback?.width ?? sharedWidth,
      style: styleOverride ?? explicit?.style ?? fallback?.style ?? sharedStyle,
    );
  }

  HtmlStyleProvenance _provenanceFromDeclarations(
    List<CssDeclaration> declarations, {
    required String selectorText,
    required int sourceOrder,
    required HtmlStyleOrigin origin,
  }) {
    final out = <String, HtmlStyleProvenanceEntry>{};
    for (final declaration in declarations) {
      out[declaration.property] = HtmlStyleProvenanceEntry(
        property: declaration.property,
        value: declaration.value,
        origin: origin,
        selector: selectorText,
        important: declaration.important,
        sourceOrder: sourceOrder,
      );
      if (!_supportedProperties.contains(declaration.property)) {
        _diagnostics.warn(
          HtmlCssWarning(
            code: 'unsupported-property',
            message: 'Property is currently unsupported.',
            selector: selectorText,
            property: declaration.property,
            value: declaration.value,
          ),
        );
      }
    }
    return HtmlStyleProvenance(out);
  }

  static const Set<String> _supportedProperties = <String>{
    'color',
    'background-color',
    'font-size',
    'font-weight',
    'font-style',
    'font-variant',
    'font-family',
    'text-decoration',
    'text-align',
    'line-height',
    'letter-spacing',
    'word-spacing',
    'text-indent',
    'text-transform',
    'white-space',
    'margin',
    'margin-top',
    'margin-right',
    'margin-bottom',
    'margin-left',
    'padding',
    'padding-top',
    'padding-right',
    'padding-bottom',
    'padding-left',
    'list-style',
    'list-style-type',
    'list-style-position',
    'list-style-image',
    'border',
    'border-color',
    'border-style',
    'border-width',
    'border-top',
    'border-right',
    'border-bottom',
    'border-left',
    'border-top-color',
    'border-right-color',
    'border-bottom-color',
    'border-left-color',
    'border-top-width',
    'border-right-width',
    'border-bottom-width',
    'border-left-width',
    'border-top-style',
    'border-right-style',
    'border-bottom-style',
    'border-left-style',
  };
}

class _BorderParts {
  const _BorderParts({this.color, this.width, this.style});

  final Color? color;
  final double? width;
  final BorderStyle? style;
}
