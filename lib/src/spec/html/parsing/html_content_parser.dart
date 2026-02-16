import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:flutter/material.dart';

import 'css_style_parser.dart';
import '../model/html_nodes.dart';

class HtmlContentParser {
  HtmlContentParser({CssStyleParser? styleParser})
    : _styleParser = styleParser ?? const CssStyleParser();

  final CssStyleParser _styleParser;

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
      }
      return;
    }

    if (tag == 'pre') {
      final text = node.text;
      if (text.trim().isNotEmpty) {
        out.add(
          HtmlTextBlockNode(
            segments: <HtmlInlineSegment>[
              HtmlInlineSegment(text: text, style: mergedStyle, isCode: true),
            ],
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
        items.add(_parseInlineNodes(li.nodes, mergedStyle, rules));
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
      final rows = <List<String>>[];
      bool hasHeader = false;
      for (final tr in node.getElementsByTagName('tr')) {
        final row = <String>[];
        final cells = tr.children
            .where((cell) => _tagName(cell) == 'th' || _tagName(cell) == 'td')
            .toList(growable: false);
        if (cells.isEmpty) {
          continue;
        }
        if (cells.any((cell) => _tagName(cell) == 'th')) {
          hasHeader = true;
        }
        for (final cell in cells) {
          row.add(_normalizeWhitespace(cell.text));
        }
        rows.add(row);
      }
      if (rows.isNotEmpty) {
        out.add(
          HtmlTableBlockNode(
            rows: rows,
            id: _elementId(node),
            hasHeader: hasHeader,
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
        tag == 'div' ||
        tag == 'article' ||
        tag == 'section' ||
        tag == 'nav' ||
        tag == 'aside' ||
        tag == 'header' ||
        tag == 'footer' ||
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
        final codeText = node.text;
        if (codeText.isNotEmpty) {
          segments.add(
            HtmlInlineSegment(text: codeText, style: childStyle, isCode: true),
          );
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
    final normalizedNewlines = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final output = switch (mode) {
      HtmlWhiteSpace.pre || HtmlWhiteSpace.preWrap => normalizedNewlines,
      HtmlWhiteSpace.preLine => normalizedNewlines.replaceAll(
          RegExp(r'[ \t\f]+'),
          ' ',
        ),
      HtmlWhiteSpace.nowrap || HtmlWhiteSpace.normal => normalizedNewlines
          .replaceAll(RegExp(r'[ \t\n\f]+'), ' '),
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
    final tagName = _tagName(node);
    final elementId = _cleanAttribute(_attribute(node, const <String>['id']));
    final classNames =
        (_cleanAttribute(_attribute(node, const <String>['class'])) ?? '')
            .split(RegExp(r'\s+'))
            .where((value) => value.trim().isNotEmpty)
            .map((value) => value.trim().toLowerCase())
            .toSet();

    final matched = rules
        .where(
          (rule) => rule.selector.matches(
            tagName: tagName,
            elementId: elementId,
            elementClasses: classNames,
          ),
        )
        .toList(growable: false)
      ..sort((a, b) {
        final specificityCompare = a.specificity.compareTo(b.specificity);
        if (specificityCompare != 0) {
          return specificityCompare;
        }
        return a.sourceOrder.compareTo(b.sourceOrder);
      });

    for (final rule in matched) {
      merged = merged.merge(rule.style);
    }

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
        final rel = (_attribute(link, const <String>['rel']) ?? '').toLowerCase();
        if (!rel.contains('stylesheet')) {
          continue;
        }
        final href = _cleanAttribute(_attribute(link, const <String>['href']));
        if (href == null || href.isEmpty) {
          continue;
        }
        final css = externalCssResolver(href);
        if (css != null && css.trim().isNotEmpty) {
          styleSheets.add(css);
        }
      }
    }

    for (final styleElement in fragment.querySelectorAll('style')) {
      final css = styleElement.text;
      if (css.trim().isNotEmpty) {
        styleSheets.add(css);
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
}
