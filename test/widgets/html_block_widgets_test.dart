import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_html_column_widget/flutter_html_column_widget.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildBlocks(
  List<HtmlBlockNode> blocks, {
  HtmlRefTapCallback? onRefTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: blocks
            .map(
              (block) => HtmlBlockView(
                block: block,
                blockContext: HtmlBlockContext(
                  baseStyle: const TextStyle(fontSize: 14),
                  onRefTap: onRefTap,
                ),
              ),
            )
            .toList(growable: false),
      ),
    ),
  );
}

bool _anyRichTextContains(WidgetTester tester, String text) {
  return tester
      .widgetList<RichText>(find.byType(RichText))
      .any((richText) => richText.text.toPlainText().contains(text));
}

TapGestureRecognizer? _findTapRecognizerForText(InlineSpan span, String text) {
  if (span is! TextSpan) {
    return null;
  }
  final directText = span.text ?? '';
  if (directText.contains(text) && span.recognizer is TapGestureRecognizer) {
    return span.recognizer! as TapGestureRecognizer;
  }
  for (final child in span.children ?? const <InlineSpan>[]) {
    final recognizer = _findTapRecognizerForText(child, text);
    if (recognizer != null) {
      return recognizer;
    }
  }
  return null;
}

void main() {
  group('Html block widgets', () {
    testWidgets('text-transform uppercase renders transformed text', (
      tester,
    ) async {
      final parser = HtmlContentParser();
      final blocks = parser.parse(
        '<p style="text-transform: uppercase">hello world</p>',
      );

      await tester.pumpWidget(_buildBlocks(blocks));

      final richText = tester.widget<RichText>(find.byType(RichText).first);
      expect(richText.text.toPlainText(), contains('HELLO WORLD'));
    });

    testWidgets('unordered list square marker renders expected glyph', (
      tester,
    ) async {
      final parser = HtmlContentParser();
      final blocks = parser.parse(
        '<ul style="list-style-type: square"><li>alpha</li></ul>',
      );

      await tester.pumpWidget(_buildBlocks(blocks));

      expect(_anyRichTextContains(tester, '\u25AA'), isTrue);
      expect(_anyRichTextContains(tester, 'alpha'), isTrue);
    });

    testWidgets('anchor tap dispatches parsed HtmlReference with metadata', (
      tester,
    ) async {
      final parser = HtmlContentParser();
      final blocks = parser.parse(
        '<p><a href="#fn-1" epub:type="noteref" role="doc-noteref">1</a></p>',
      );
      HtmlReference? tapped;

      await tester.pumpWidget(
        _buildBlocks(
          blocks,
          onRefTap: (reference) {
            tapped = reference;
          },
        ),
      );

      TapGestureRecognizer? recognizer;
      for (final richText in tester.widgetList<RichText>(
        find.byType(RichText),
      )) {
        recognizer = _findTapRecognizerForText(richText.text, '1');
        if (recognizer != null) {
          break;
        }
      }
      expect(recognizer, isNotNull);
      recognizer!.onTap?.call();

      expect(tapped, isNotNull);
      expect(tapped?.raw, '#fn-1');
      expect(tapped?.fragmentId, 'fn-1');
      expect(tapped?.epubType, 'noteref');
      expect(tapped?.role, 'doc-noteref');
    });

    testWidgets('list item anchor tap dispatches parsed HtmlReference', (
      tester,
    ) async {
      final parser = HtmlContentParser();
      final blocks = parser.parse(
        '<ul><li><a href="#chapter-1">Chapter 1</a></li></ul>',
      );
      HtmlReference? tapped;

      await tester.pumpWidget(
        _buildBlocks(
          blocks,
          onRefTap: (reference) {
            tapped = reference;
          },
        ),
      );

      TapGestureRecognizer? recognizer;
      for (final richText in tester.widgetList<RichText>(
        find.byType(RichText),
      )) {
        recognizer = _findTapRecognizerForText(richText.text, 'Chapter 1');
        if (recognizer != null) {
          break;
        }
      }
      expect(recognizer, isNotNull);
      recognizer!.onTap?.call();

      expect(tapped, isNotNull);
      expect(tapped?.raw, '#chapter-1');
      expect(tapped?.fragmentId, 'chapter-1');
    });

    testWidgets('preformatted block keeps original newlines and spacing', (
      tester,
    ) async {
      final parser = HtmlContentParser();
      final blocks = parser.parse('<pre>line 1\n  line 2\nline 3</pre>');

      await tester.pumpWidget(_buildBlocks(blocks));

      expect(find.text('line 1\n  line 2\nline 3'), findsOneWidget);
      expect(find.byType(DecoratedBox), findsWidgets);
    });

    testWidgets('semantic table allocates wider column for long content', (
      tester,
    ) async {
      final parser = HtmlContentParser();
      final blocks = parser.parse('''
        <table border cellspacing="0" cellpadding="3">
          <tr><td colspan="2"><strong>TABLE Testing Section</strong></td></tr>
          <tr>
            <td>&nbsp;</td>
            <td>This is a much longer table cell that should receive more width.</td>
          </tr>
        </table>
        ''');

      await tester.pumpWidget(_buildBlocks(blocks));

      final rows = tester.widgetList<Row>(find.byType(Row));
      final dataRow = rows.firstWhere(
        (row) =>
            row.children.length == 2 &&
            row.children.every((child) => child is Expanded),
      );
      final first = dataRow.children[0] as Expanded;
      final second = dataRow.children[1] as Expanded;
      expect(second.flex, greaterThan(first.flex * 8));
    });

    testWidgets('semantic table renders nested list blocks inside cells', (
      tester,
    ) async {
      final parser = HtmlContentParser();
      final blocks = parser.parse('''
        <table>
          <tr>
            <td>
              <ul><li>alpha</li></ul>
              <ol><li>one</li></ol>
            </td>
          </tr>
        </table>
        ''');

      await tester.pumpWidget(_buildBlocks(blocks));

      expect(_anyRichTextContains(tester, '\u2022'), isTrue);
      expect(_anyRichTextContains(tester, 'alpha'), isTrue);
      expect(_anyRichTextContains(tester, '1.'), isTrue);
      expect(_anyRichTextContains(tester, 'one'), isTrue);
    });
  });
}
