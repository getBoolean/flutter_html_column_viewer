import 'css_cascade_engine.dart';
import '../diagnostics/html_css_diagnostics.dart';
import '../diagnostics/html_css_warning.dart';
import 'css_selector_engine.dart';

class CssAstAdapter {
  const CssAstAdapter({
    CssSelectorParser? selectorParser,
    HtmlCssDiagnostics? diagnostics,
  }) : _selectorParser = selectorParser ?? const CssSelectorParser(),
       _diagnostics = diagnostics;

  final CssSelectorParser _selectorParser;
  final HtmlCssDiagnostics? _diagnostics;

  List<CssParsedRule> parseStyleSheet(
    String css, {
    int startSourceOrder = 0,
    String source = 'stylesheet',
  }) {
    final normalized = _stripComments(css);
    final rules = <CssParsedRule>[];
    var sourceOrder = startSourceOrder;
    var cursor = 0;
    while (cursor < normalized.length) {
      final openBrace = normalized.indexOf('{', cursor);
      if (openBrace == -1) {
        break;
      }
      final selectorText = _normalizeSelectorPrelude(
        normalized.substring(cursor, openBrace),
      ).trim();
      final closeBrace = _matchingBrace(normalized, openBrace);
      if (closeBrace == -1) {
        break;
      }
      final body = normalized.substring(openBrace + 1, closeBrace).trim();
      cursor = closeBrace + 1;
      if (selectorText.isEmpty) {
        continue;
      }

      if (selectorText.startsWith('@')) {
        final lower = selectorText.toLowerCase();
        if (lower.startsWith('@media') || lower.startsWith('@supports')) {
          rules.addAll(
            parseStyleSheet(
              body,
              startSourceOrder: sourceOrder,
              source: selectorText,
            ),
          );
          sourceOrder += rules.length;
          continue;
        }
        _diagnostics?.warn(
          HtmlCssWarning(
            code: 'unsupported-at-rule',
            message: 'Unsupported at-rule encountered.',
            selector: selectorText,
            source: source,
          ),
        );
        continue;
      }

      final declarations = _parseDeclarations(body);
      if (declarations.isEmpty) {
        continue;
      }
      for (final token in selectorText.split(',')) {
        final selectorRaw = token.trim();
        if (selectorRaw.isEmpty) {
          continue;
        }
        final selector = _selectorParser.parse(selectorRaw);
        if (selector == null) {
          _diagnostics?.warn(
            HtmlCssWarning(
              code: 'unsupported-selector',
              message: 'Selector is not supported and was ignored.',
              selector: selectorRaw,
              source: source,
            ),
          );
          continue;
        }
        rules.add(
          CssParsedRule(
            selector: selector,
            selectorText: selectorRaw,
            declarations: declarations,
            sourceOrder: sourceOrder++,
          ),
        );
      }
    }
    return rules;
  }

  String _normalizeSelectorPrelude(String prelude) {
    // Preserve the trailing selector when invalid/ignored semicolon at-rules
    // (for example late @import) appear before it.
    final segments = prelude.split(';');
    return segments.isEmpty ? prelude : segments.last;
  }

  List<CssDeclaration> parseInlineDeclarations(String inlineCss) {
    return _parseDeclarations(inlineCss);
  }

  List<CssDeclaration> _parseDeclarations(String body) {
    final parts = body.split(';');
    final out = <CssDeclaration>[];
    for (final part in parts) {
      final token = part.trim();
      if (token.isEmpty) {
        continue;
      }
      final colon = token.indexOf(':');
      if (colon <= 0) {
        continue;
      }
      final property = token.substring(0, colon).trim().toLowerCase();
      var value = token.substring(colon + 1).trim();
      var important = false;
      if (value.toLowerCase().endsWith('!important')) {
        value = value.substring(0, value.length - '!important'.length).trim();
        important = true;
      }
      if (property.isEmpty || value.isEmpty) {
        continue;
      }
      out.add(
        CssDeclaration(property: property, value: value, important: important),
      );
    }
    return out;
  }

  int _matchingBrace(String source, int openBrace) {
    var depth = 0;
    for (var i = openBrace; i < source.length; i++) {
      if (source[i] == '{') {
        depth++;
      } else if (source[i] == '}') {
        depth--;
        if (depth == 0) {
          return i;
        }
      }
    }
    return -1;
  }

  String _stripComments(String css) {
    return css
        // CSS block comments.
        .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
        // Legacy HTML comment wrappers used inside <style> blocks.
        .replaceAll('<!--', ' ')
        .replaceAll('-->', ' ');
  }
}
