import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:flutter/material.dart';

import 'css_style_parser.dart';
import 'html_inline_parser.dart';
import 'html_table_parser.dart';
import '../model/html_nodes.dart';

class HtmlContentParser {
  HtmlContentParser({
    CssStyleParser? styleParser,
    HtmlTableParser? tableParser,
    HtmlInlineParser? inlineParser,
  }) : _styleParser = styleParser ?? CssStyleParser(),
       _tableParser = tableParser ?? const HtmlTableParser(),
       _inlineParser = inlineParser ?? const HtmlInlineParser();

  final CssStyleParser _styleParser;
  final HtmlTableParser _tableParser;
  final HtmlInlineParser _inlineParser;

  List<HtmlBlockNode> parse(
    String html, {
    String? externalCss,
    String? Function(String href)? externalCssResolver,
  }) {
    final fragment = html_parser.parseFragment(html);
    final blocks = <HtmlBlockNode>[];
    final rules = _buildCssRules(
      fragment,
      externalCss: externalCss,
      externalCssResolver: externalCssResolver,
    );

    for (final child in fragment.nodes) {
      _parseNodeIntoBlocks(child, HtmlStyleData.empty, blocks, rules);
    }

    return blocks.where(_hasMeaningfulContent).toList(growable: false);
  }

  bool _hasMeaningfulContent(HtmlBlockNode node) {
    if (node is HtmlTextBlockNode) {
      return node.plainText.trim().isNotEmpty;
    }
    if (node is HtmlListBlockNode) {
      return node.items.isNotEmpty;
    }
    if (node is HtmlTableBlockNode) {
      return node.rows.isNotEmpty;
    }
    return true;
  }

  void _parseNodeIntoBlocks(
    dom.Node node,
    HtmlStyleData inheritedStyle,
    List<HtmlBlockNode> out,
    List<CssStyleRule> rules,
  ) {
    if (node is dom.Text) {
      final text = _normalizeWhitespace(
        node.text,
        whiteSpace: inheritedStyle.whiteSpace,
      );
      if (text.isNotEmpty) {
        out.add(
          HtmlTextBlockNode(
            segments: <HtmlInlineSegment>[
              HtmlInlineSegment(text: text, style: inheritedStyle),
            ],
            style: inheritedStyle,
          ),
        );
      }
      return;
    }

    if (node is! dom.Element) {
      return;
    }

    final tag = _tagName(node);
    if (tag == 'style' || tag == 'script' || tag == 'link') {
      return;
    }
    final mergedStyle = _resolveElementStyle(
      node: node,
      inheritedStyle: inheritedStyle,
      rules: rules,
    );

    if (tag == 'hr') {
      out.add(HtmlDividerBlockNode(id: _elementId(node)));
      return;
    }

    if (tag == 'column-break') {
      out.add(HtmlColumnBreakBlockNode(id: _elementId(node)));
      return;
    }

    if (tag == 'img') {
      final src = _cleanAttribute(_attribute(node, const <String>['src']));
      if (src != null && src.isNotEmpty) {
        out.add(
          HtmlImageBlockNode(
            src: src,
            alt: _cleanAttribute(_attribute(node, const <String>['alt'])),
            intrinsicAspectRatio: _inferImageAspectRatio(node),
            id: _elementId(node),
          ),
        );
      }
      return;
    }

    if (_isHeadingTag(tag)) {
      out.add(
        HtmlTextBlockNode(
          segments: _parseInlineNodes(node.nodes, mergedStyle, rules),
          id: _elementId(node),
          headingLevel: int.parse(tag.substring(1)),
          style: mergedStyle,
        ),
      );
      return;
    }

    if (_isParagraphLikeTag(tag)) {
      final segments = _parseInlineNodes(node.nodes, mergedStyle, rules);
      if (segments.isNotEmpty) {
        out.add(
          HtmlTextBlockNode(
            segments: segments,
            id: _elementId(node),
            style: mergedStyle,
          ),
        );
      } else {
        for (final child in node.nodes) {
          _parseNodeIntoBlocks(child, mergedStyle, out, rules);
        }
      }
      return;
    }

    if (tag == 'blockquote') {
      final segments = _parseInlineNodes(node.nodes, mergedStyle, rules);
      if (segments.isNotEmpty) {
        out.add(
          HtmlTextBlockNode(
            segments: segments,
            id: _elementId(node),
            style: mergedStyle,
            isBlockquote: true,
          ),
        );
      } else {
        for (final child in node.nodes) {
          _parseNodeIntoBlocks(child, mergedStyle, out, rules);
        }
      }
      return;
    }

    if (tag == 'pre') {
      final segments = _inlineParser.parseCodeLike(
        node,
        mergedStyle,
        isCode: true,
      );
      if (segments.isNotEmpty) {
        out.add(
          HtmlTextBlockNode(
            segments: segments,
            id: _elementId(node),
            style: mergedStyle,
            preformatted: true,
          ),
        );
      }
      return;
    }

    if (tag == 'ul' || tag == 'ol') {
      final ordered = tag == 'ol';
      final items = <List<HtmlInlineSegment>>[];
      for (final li in node.children.where(
        (child) => _tagName(child) == 'li',
      )) {
        final liStyle = _resolveElementStyle(
          node: li,
          inheritedStyle: mergedStyle,
          rules: rules,
        );
        final itemSegments = _parseInlineNodes(li.nodes, liStyle, rules);
        if (itemSegments.isNotEmpty) {
          items.add(itemSegments);
        }
        for (final child in li.children.where(
          (child) => _tagName(child) == 'ul' || _tagName(child) == 'ol',
        )) {
          _parseNodeIntoBlocks(child, liStyle, out, rules);
        }
      }
      if (items.isNotEmpty) {
        out.add(
          HtmlListBlockNode(
            ordered: ordered,
            items: items,
            id: _elementId(node),
            style: mergedStyle,
          ),
        );
      }
      return;
    }

    if (tag == 'table') {
      final tableModel = _tableParser.parse(node);
      final rows = tableModel.rows
          .map(
            (row) => row.cells.map((cell) => cell.text).toList(growable: false),
          )
          .toList(growable: false);
      final hasHeader = tableModel.head.rows.isNotEmpty;
      if (rows.isNotEmpty) {
        out.add(
          HtmlTableBlockNode(
            rows: rows,
            id: _elementId(node),
            hasHeader: hasHeader,
            tableModel: tableModel,
            style: mergedStyle,
          ),
        );
      }
      return;
    }

    if (tag == 'br') {
      out.add(
        HtmlTextBlockNode(
          segments: <HtmlInlineSegment>[
            HtmlInlineSegment(text: '\n', style: mergedStyle),
          ],
          id: _elementId(node),
          style: mergedStyle,
        ),
      );
      return;
    }

    final inlineSegments = _parseInlineNodes(node.nodes, mergedStyle, rules);
    if (inlineSegments.isNotEmpty) {
      out.add(
        HtmlTextBlockNode(
          segments: inlineSegments,
          id: _elementId(node),
          style: mergedStyle,
        ),
      );
      return;
    }
    for (final child in node.nodes) {
      _parseNodeIntoBlocks(child, mergedStyle, out, rules);
    }
  }

  bool _isHeadingTag(String tag) {
    return tag == 'h1' ||
        tag == 'h2' ||
        tag == 'h3' ||
        tag == 'h4' ||
        tag == 'h5' ||
        tag == 'h6';
  }

  bool _isParagraphLikeTag(String tag) {
    return tag == 'p' ||
        tag == 'span' ||
        tag == 'div' ||
        tag == 'article' ||
        tag == 'section' ||
        tag == 'nav' ||
        tag == 'aside' ||
        tag == 'header' ||
        tag == 'footer' ||
        tag == 'figure' ||
        tag == 'figcaption' ||
        tag == 'summary' ||
        tag == 'details' ||
        tag == 'address' ||
        tag == 'main';
  }

  List<HtmlInlineSegment> _parseInlineNodes(
    List<dom.Node> nodes,
    HtmlStyleData inheritedStyle,
    List<CssStyleRule> rules,
  ) {
    final segments = <HtmlInlineSegment>[];
    for (final node in nodes) {
      if (node is dom.Text) {
        final text = _normalizeWhitespace(
          node.text,
          trim: false,
          whiteSpace: inheritedStyle.whiteSpace,
        );
        if (text.isNotEmpty) {
          segments.add(HtmlInlineSegment(text: text, style: inheritedStyle));
        }
        continue;
      }
      if (node is! dom.Element) {
        continue;
      }

      final tag = _tagName(node);
      if (tag == 'style' || tag == 'script' || tag == 'link') {
        continue;
      }
      var childStyle = _resolveElementStyle(
        node: node,
        inheritedStyle: inheritedStyle,
        rules: rules,
      );
      HtmlReference? reference;

      if (tag == 'strong' || tag == 'b') {
        childStyle = childStyle.merge(
          const HtmlStyleData(fontWeight: FontWeight.w700),
        );
      } else if (tag == 'em' || tag == 'i') {
        childStyle = childStyle.merge(
          const HtmlStyleData(fontStyle: FontStyle.italic),
        );
      } else if (tag == 'u') {
        childStyle = childStyle.merge(
          const HtmlStyleData(decoration: TextDecoration.underline),
        );
      } else if (tag == 'sub') {
        childStyle = childStyle.merge(
          HtmlStyleData(
            fontSize:
                (childStyle.fontSize ?? inheritedStyle.fontSize ?? 16) * 0.8,
          ),
        );
      } else if (tag == 'sup') {
        childStyle = childStyle.merge(
          HtmlStyleData(
            fontSize:
                (childStyle.fontSize ?? inheritedStyle.fontSize ?? 16) * 0.8,
          ),
        );
      } else if (tag == 'mark') {
        childStyle = childStyle.merge(
          const HtmlStyleData(backgroundColor: Color(0xFFFFFF8D)),
        );
      } else if (tag == 'small') {
        childStyle = childStyle.merge(
          HtmlStyleData(
            fontSize:
                (childStyle.fontSize ?? inheritedStyle.fontSize ?? 16) * 0.85,
          ),
        );
      } else if (tag == 's' || tag == 'strike' || tag == 'del') {
        childStyle = childStyle.merge(
          const HtmlStyleData(decoration: TextDecoration.lineThrough),
        );
      } else if (tag == 'ins') {
        childStyle = childStyle.merge(
          const HtmlStyleData(decoration: TextDecoration.underline),
        );
      } else if (tag == 'a') {
        final href = _cleanAttribute(_attribute(node, const <String>['href']));
        if (href != null && href.isNotEmpty) {
          reference = HtmlReference.fromRaw(
            href,
            epubType: _cleanAttribute(
              _attribute(node, const <String>['epub:type']),
            ),
            role: _cleanAttribute(_attribute(node, const <String>['role'])),
          );
          childStyle = childStyle.merge(
            const HtmlStyleData(
              color: Color(0xFF1565C0),
              decoration: TextDecoration.underline,
            ),
          );
        }
      } else if (tag == 'br') {
        segments.add(HtmlInlineSegment(text: '\n', style: childStyle));
        continue;
      } else if (tag == 'wbr') {
        // Preserve explicit line-break opportunities in HTML5 content.
        segments.add(HtmlInlineSegment(text: '\u200B', style: childStyle));
        continue;
      } else if (tag == 'code') {
        final codeSegments = _inlineParser.parseCodeLike(
          node,
          childStyle,
          isCode: true,
        );
        if (codeSegments.isNotEmpty) {
          segments.addAll(codeSegments);
        }
        continue;
      }

      final children = _parseInlineNodes(node.nodes, childStyle, rules);
      if (reference != null) {
        for (final segment in children) {
          segments.add(
            HtmlInlineSegment(
              text: segment.text,
              style: segment.style,
              reference: reference,
              isCode: segment.isCode,
            ),
          );
        }
      } else {
        segments.addAll(children);
      }
    }
    return _mergeNeighborTextSegments(segments);
  }

  List<HtmlInlineSegment> _mergeNeighborTextSegments(
    List<HtmlInlineSegment> segments,
  ) {
    if (segments.isEmpty) {
      return segments;
    }

    final merged = <HtmlInlineSegment>[];
    for (final segment in segments) {
      if (merged.isEmpty) {
        merged.add(segment);
        continue;
      }
      final last = merged.last;
      if (last.reference == segment.reference &&
          last.style == segment.style &&
          last.isCode == segment.isCode) {
        merged.removeLast();
        merged.add(
          HtmlInlineSegment(
            text: '${last.text}${segment.text}',
            reference: last.reference,
            style: last.style,
            isCode: last.isCode,
          ),
        );
      } else {
        merged.add(segment);
      }
    }
    return merged;
  }

  String _normalizeWhitespace(
    String input, {
    bool trim = true,
    HtmlWhiteSpace? whiteSpace,
  }) {
    final mode = whiteSpace ?? HtmlWhiteSpace.normal;
    final normalizedNewlines = input
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final output = switch (mode) {
      HtmlWhiteSpace.pre || HtmlWhiteSpace.preWrap => normalizedNewlines,
      HtmlWhiteSpace.preLine => normalizedNewlines.replaceAll(
        RegExp(r'[ \t\f]+'),
        ' ',
      ),
      HtmlWhiteSpace.nowrap || HtmlWhiteSpace.normal =>
        normalizedNewlines.replaceAll(RegExp(r'[ \t\n\f]+'), ' '),
    };
    return trim ? output.trim() : output;
  }

  String? _cleanAttribute(String? input) {
    final trimmed = input?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String? _elementId(dom.Element node) {
    return _cleanAttribute(_attribute(node, const <String>['id']));
  }

  double? _inferImageAspectRatio(dom.Element node) {
    final width =
        _extractDimension(_attribute(node, const <String>['width'])) ??
        _extractStylePropertyDimension(
          _attribute(node, const <String>['style']),
          'width',
        );
    final height =
        _extractDimension(_attribute(node, const <String>['height'])) ??
        _extractStylePropertyDimension(
          _attribute(node, const <String>['style']),
          'height',
        );
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return width / height;
  }

  double? _extractStylePropertyDimension(String? style, String property) {
    if (style == null || style.trim().isEmpty) {
      return null;
    }
    final match = RegExp(
      '(?:^|;)\\s*${RegExp.escape(property)}\\s*:\\s*([^;]+)',
      caseSensitive: false,
    ).firstMatch(style);
    if (match == null) {
      return null;
    }
    return _extractDimension(match.group(1));
  }

  double? _extractDimension(String? input) {
    if (input == null) {
      return null;
    }
    final match = RegExp(r'-?\d+(\.\d+)?').firstMatch(input);
    if (match == null) {
      return null;
    }
    return double.tryParse(match.group(0)!);
  }

  String _tagName(dom.Element node) => node.localName?.toLowerCase() ?? '';

  String? _attribute(dom.Element node, List<String> names) {
    for (final rawName in names) {
      final name = rawName.trim();
      if (name.isEmpty) {
        continue;
      }
      final direct = node.attributes[name];
      if (direct != null) {
        return direct;
      }

      final loweredName = name.toLowerCase();
      for (final entry in node.attributes.entries) {
        if ('${entry.key}'.toLowerCase() == loweredName) {
          return entry.value;
        }
      }

      final colonIndex = loweredName.indexOf(':');
      if (colonIndex > 0 && colonIndex < loweredName.length - 1) {
        final localPart = loweredName.substring(colonIndex + 1);
        for (final entry in node.attributes.entries) {
          if ('${entry.key}'.toLowerCase().endsWith(':$localPart')) {
            return entry.value;
          }
        }
      }
    }
    return null;
  }

  HtmlStyleData _resolveElementStyle({
    required dom.Element node,
    required HtmlStyleData inheritedStyle,
    required List<CssStyleRule> rules,
  }) {
    var merged = inheritedStyle.inheritableOnly();
    final matched = rules
        .where((rule) => _styleParser.matchesRule(rule, node))
        .toList(growable: false);
    merged = merged.merge(_styleParser.resolveMatchedRules(matched));

    merged = merged.merge(
      _styleParser.parseInlineStyle(_attribute(node, const <String>['style'])),
    );
    return merged;
  }

  List<CssStyleRule> _buildCssRules(
    dom.DocumentFragment fragment, {
    String? externalCss,
    String? Function(String href)? externalCssResolver,
  }) {
    final styleSheets = <String>[];
    if (externalCss != null && externalCss.trim().isNotEmpty) {
      styleSheets.add(externalCss);
    }

    if (externalCssResolver != null) {
      for (final link in fragment.querySelectorAll('link')) {
        final rel = _attribute(link, const <String>['rel']);
        if (!_isPreferredStylesheetRel(rel)) {
          continue;
        }
        final href = _cleanAttribute(_attribute(link, const <String>['href']));
        if (href == null || href.isEmpty) {
          continue;
        }
        final css = externalCssResolver(href);
        if (css != null && css.trim().isNotEmpty) {
          styleSheets.add(
            _expandLeadingCssImports(
              css,
              externalCssResolver: externalCssResolver,
              activeImports: <String>{href},
            ),
          );
        }
      }
    }

    for (final styleElement in fragment.querySelectorAll('style')) {
      final css = styleElement.text;
      if (css.trim().isNotEmpty) {
        styleSheets.add(
          _expandLeadingCssImports(
            css,
            externalCssResolver: externalCssResolver,
            activeImports: <String>{},
          ),
        );
      }
    }

    final rules = <CssStyleRule>[];
    var sourceOrder = 0;
    for (final sheet in styleSheets) {
      final parsed = _styleParser.parseStyleSheet(
        sheet,
        startSourceOrder: sourceOrder,
      );
      rules.addAll(parsed);
      sourceOrder += parsed.length;
    }
    return rules;
  }

  bool _isPreferredStylesheetRel(String? relRaw) {
    final rel = relRaw?.trim().toLowerCase();
    if (rel == null || rel.isEmpty) {
      return false;
    }
    final relTokens = rel.split(RegExp(r'\s+'));
    return relTokens.contains('stylesheet') &&
        !relTokens.contains('alternate');
  }

  String _expandLeadingCssImports(
    String css, {
    required String? Function(String href)? externalCssResolver,
    required Set<String> activeImports,
  }) {
    if (externalCssResolver == null || css.trim().isEmpty) {
      return css;
    }

    final directives = _parseLeadingImportDirectives(css);
    if (directives.isEmpty) {
      return css;
    }

    final buffer = StringBuffer();
    for (final directive in directives.directives) {
      final href = directive.href.trim();
      if (href.isEmpty || activeImports.contains(href)) {
        continue;
      }
      final importedCss = externalCssResolver(href);
      if (importedCss == null || importedCss.trim().isEmpty) {
        continue;
      }
      activeImports.add(href);
      buffer.writeln(
        _expandLeadingCssImports(
          importedCss,
          externalCssResolver: externalCssResolver,
          activeImports: activeImports,
        ),
      );
      activeImports.remove(href);
    }
    buffer.write(css.substring(directives.consumedOffset));
    return buffer.toString();
  }

  _ImportParseResult _parseLeadingImportDirectives(String css) {
    var offset = 0;
    final directives = <_CssImportDirective>[];
    while (offset < css.length) {
      offset = _skipCssWhitespaceAndComments(css, offset);
      if (offset >= css.length) {
        break;
      }
      if (_startsWithIgnoreCase(css, offset, '@charset')) {
        final statementEnd = css.indexOf(';', offset);
        if (statementEnd < 0) {
          break;
        }
        offset = statementEnd + 1;
        continue;
      }
      if (!_startsWithIgnoreCase(css, offset, '@import')) {
        break;
      }
      final statementEnd = css.indexOf(';', offset);
      if (statementEnd < 0) {
        break;
      }
      final statement = css.substring(offset, statementEnd + 1);
      final href = _extractImportHref(statement);
      if (href != null && href.isNotEmpty) {
        directives.add(_CssImportDirective(href));
      }
      offset = statementEnd + 1;
    }
    return _ImportParseResult(
      directives: directives,
      consumedOffset: directives.isEmpty ? 0 : offset,
    );
  }

  int _skipCssWhitespaceAndComments(String css, int start) {
    var offset = start;
    while (offset < css.length) {
      if (offset + 4 <= css.length && css.substring(offset, offset + 4) == '<!--') {
        offset += 4;
        continue;
      }
      if (offset + 3 <= css.length && css.substring(offset, offset + 3) == '-->') {
        offset += 3;
        continue;
      }
      final current = css.codeUnitAt(offset);
      if (current == 0x2f &&
          offset + 1 < css.length &&
          css.codeUnitAt(offset + 1) == 0x2a) {
        final commentEnd = css.indexOf('*/', offset + 2);
        if (commentEnd < 0) {
          return css.length;
        }
        offset = commentEnd + 2;
        continue;
      }
      if (current == 0x20 ||
          current == 0x09 ||
          current == 0x0a ||
          current == 0x0d ||
          current == 0x0c) {
        offset += 1;
        continue;
      }
      break;
    }
    return offset;
  }

  bool _startsWithIgnoreCase(String text, int offset, String needle) {
    if (offset + needle.length > text.length) {
      return false;
    }
    final segment = text.substring(offset, offset + needle.length);
    return segment.toLowerCase() == needle.toLowerCase();
  }

  String? _extractImportHref(String importStatement) {
    final urlMatch = RegExp(
      '@import\\s+url\\(\\s*(["\\\']?)([^)"\\\']+)\\1\\s*\\)',
      caseSensitive: false,
    ).firstMatch(importStatement);
    if (urlMatch != null) {
      return urlMatch.group(2)?.trim();
    }

    final quotedMatch = RegExp(
      '@import\\s+(["\\\'])([^"\\\']+)\\1',
      caseSensitive: false,
    ).firstMatch(importStatement);
    return quotedMatch?.group(2)?.trim();
  }
}

class _ImportParseResult {
  const _ImportParseResult({required this.directives, required this.consumedOffset});

  final List<_CssImportDirective> directives;
  final int consumedOffset;

  bool get isEmpty => directives.isEmpty;
}

class _CssImportDirective {
  const _CssImportDirective(this.href);

  final String href;
}
