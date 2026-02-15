import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:flutter/material.dart';

import 'css_style_parser.dart';
import 'html_nodes.dart';

class HtmlContentParser {
  HtmlContentParser({CssStyleParser? styleParser})
    : _styleParser = styleParser ?? const CssStyleParser();

  final CssStyleParser _styleParser;

  List<HtmlBlockNode> parse(String html) {
    final fragment = html_parser.parseFragment(html);
    final blocks = <HtmlBlockNode>[];

    for (final child in fragment.nodes) {
      _parseNodeIntoBlocks(child, HtmlStyleData.empty, blocks);
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
  ) {
    if (node is dom.Text) {
      final text = _normalizeWhitespace(node.text);
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

    final tag = node.localName?.toLowerCase() ?? '';
    final mergedStyle = inheritedStyle.merge(
      _styleParser.parseInlineStyle(node.attributes['style']),
    );

    if (tag == 'hr') {
      out.add(const HtmlDividerBlockNode());
      return;
    }

    if (tag == 'img') {
      final src = node.attributes['src']?.trim();
      if (src != null && src.isNotEmpty) {
        out.add(HtmlImageBlockNode(src: src, alt: node.attributes['alt']));
      }
      return;
    }

    if (_isHeadingTag(tag)) {
      out.add(
        HtmlTextBlockNode(
          segments: _parseInlineNodes(node.nodes, mergedStyle),
          headingLevel: int.parse(tag.substring(1)),
          style: mergedStyle,
        ),
      );
      return;
    }

    if (tag == 'p' || tag == 'div' || tag == 'article' || tag == 'section') {
      final segments = _parseInlineNodes(node.nodes, mergedStyle);
      if (segments.isNotEmpty) {
        out.add(HtmlTextBlockNode(segments: segments, style: mergedStyle));
      } else {
        for (final child in node.nodes) {
          _parseNodeIntoBlocks(child, mergedStyle, out);
        }
      }
      return;
    }

    if (tag == 'blockquote') {
      final segments = _parseInlineNodes(node.nodes, mergedStyle);
      if (segments.isNotEmpty) {
        out.add(
          HtmlTextBlockNode(
            segments: segments,
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
        (child) => child.localName == 'li',
      )) {
        items.add(_parseInlineNodes(li.nodes, mergedStyle));
      }
      if (items.isNotEmpty) {
        out.add(
          HtmlListBlockNode(ordered: ordered, items: items, style: mergedStyle),
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
            .where((cell) => cell.localName == 'th' || cell.localName == 'td')
            .toList(growable: false);
        if (cells.isEmpty) {
          continue;
        }
        if (cells.any((cell) => cell.localName == 'th')) {
          hasHeader = true;
        }
        for (final cell in cells) {
          row.add(_normalizeWhitespace(cell.text));
        }
        rows.add(row);
      }
      if (rows.isNotEmpty) {
        out.add(HtmlTableBlockNode(rows: rows, hasHeader: hasHeader));
      }
      return;
    }

    if (tag == 'br') {
      out.add(
        HtmlTextBlockNode(
          segments: <HtmlInlineSegment>[
            HtmlInlineSegment(text: '\n', style: mergedStyle),
          ],
          style: mergedStyle,
        ),
      );
      return;
    }

    final inlineSegments = _parseInlineNodes(node.nodes, mergedStyle);
    if (inlineSegments.isNotEmpty) {
      out.add(HtmlTextBlockNode(segments: inlineSegments, style: mergedStyle));
      return;
    }
    for (final child in node.nodes) {
      _parseNodeIntoBlocks(child, mergedStyle, out);
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

  List<HtmlInlineSegment> _parseInlineNodes(
    List<dom.Node> nodes,
    HtmlStyleData inheritedStyle,
  ) {
    final segments = <HtmlInlineSegment>[];
    for (final node in nodes) {
      if (node is dom.Text) {
        final text = _normalizeWhitespace(node.text);
        if (text.isNotEmpty) {
          segments.add(HtmlInlineSegment(text: text, style: inheritedStyle));
        }
        continue;
      }
      if (node is! dom.Element) {
        continue;
      }

      final tag = node.localName?.toLowerCase() ?? '';
      var childStyle = inheritedStyle.merge(
        _styleParser.parseInlineStyle(node.attributes['style']),
      );
      String? href;

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
        href = node.attributes['href'];
        childStyle = childStyle.merge(
          const HtmlStyleData(
            color: Color(0xFF1565C0),
            decoration: TextDecoration.underline,
          ),
        );
      } else if (tag == 'br') {
        segments.add(HtmlInlineSegment(text: '\n', style: childStyle));
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

      final children = _parseInlineNodes(node.nodes, childStyle);
      if (href != null) {
        for (final segment in children) {
          segments.add(
            HtmlInlineSegment(
              text: segment.text,
              style: segment.style,
              href: href,
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
      if (last.href == segment.href &&
          last.style == segment.style &&
          last.isCode == segment.isCode) {
        merged.removeLast();
        merged.add(
          HtmlInlineSegment(
            text: '${last.text}${segment.text}',
            href: last.href,
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

  String _normalizeWhitespace(String input) {
    return input.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
