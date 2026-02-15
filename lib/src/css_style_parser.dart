import 'package:csslib/parser.dart' as css_parser;
import 'package:flutter/material.dart';

import 'html_nodes.dart';

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

    return HtmlStyleData(
      color: _parseColor(declarations['color']),
      backgroundColor: _parseColor(declarations['background-color']),
      fontSize: _parseFontSize(declarations['font-size']),
      fontWeight: _parseFontWeight(declarations['font-weight']),
      fontStyle: _parseFontStyle(declarations['font-style']),
      decoration: _parseTextDecoration(declarations['text-decoration']),
      textAlign: _parseTextAlign(declarations['text-align']),
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
    final match = RegExp(r'([\d.]+)\s*px').firstMatch(value.toLowerCase());
    if (match == null) {
      return null;
    }
    return double.tryParse(match.group(1)!);
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
    return value.trim().toLowerCase() == 'italic' ? FontStyle.italic : null;
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
  };
}
