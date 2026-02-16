import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../model/html_nodes.dart';

class HtmlInlineSpanBuilder {
  const HtmlInlineSpanBuilder();

  List<InlineSpan> buildTextSpans({
    required HtmlTextBlockNode node,
    required TextStyle baseStyle,
    required HtmlRefTapCallback? onRefTap,
  }) {
    final spans = <InlineSpan>[];
    for (final segment in node.segments) {
      final segmentStyle = segment.style.applyToTextStyle(
        node.preformatted
            ? baseStyle.copyWith(
                fontFamily: 'monospace',
                height: node.style.lineHeight ?? 1.35,
              )
            : baseStyle,
      );
      final transformedText = _transformText(
        segment.text,
        segment.style.textTransform ?? node.style.textTransform,
      );

      if (segment.reference != null && onRefTap != null) {
        spans.add(
          TextSpan(
            text: transformedText,
            style: segmentStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => onRefTap(segment.reference!),
          ),
        );
      } else {
        spans.add(TextSpan(text: transformedText, style: segmentStyle));
      }
    }
    if ((node.style.textIndent ?? 0) > 0) {
      spans.insert(
        0,
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: SizedBox(width: node.style.textIndent ?? 0),
        ),
      );
    }
    return spans;
  }

  String _transformText(String input, HtmlTextTransform? transform) {
    switch (transform) {
      case HtmlTextTransform.uppercase:
        return input.toUpperCase();
      case HtmlTextTransform.lowercase:
        return input.toLowerCase();
      case HtmlTextTransform.capitalize:
        return input.split(RegExp(r'(\s+)')).map((token) {
          if (token.trim().isEmpty) {
            return token;
          }
          return token[0].toUpperCase() + token.substring(1).toLowerCase();
        }).join();
      case HtmlTextTransform.none:
      case null:
        return input;
    }
  }
}
