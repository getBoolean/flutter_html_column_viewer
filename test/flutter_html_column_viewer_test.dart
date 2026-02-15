import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:flutter_html_column_viewer/flutter_html_column_viewer.dart';

void main() {
  test('parser extracts blocks with css styles', () {
    final parser = HtmlContentParser();
    final blocks = parser.parse('''
      <h2 style="color: #ff0000">Title</h2>
      <p>Hello <a href="https://example.com">link</a> world.</p>
      <ul><li>One</li><li>Two</li></ul>
      <table>
        <tr><th>H1</th><th>H2</th></tr>
        <tr><td>A</td><td>B</td></tr>
      </table>
      ''');

    expect(blocks, isNotEmpty);
    expect(blocks.whereType<HtmlTextBlockNode>().first.headingLevel, 2);
    final firstTextBlock = blocks.whereType<HtmlTextBlockNode>().first;
    expect(firstTextBlock.style.color, const Color(0xFFFF0000));

    final paragraphBlock = blocks.whereType<HtmlTextBlockNode>().elementAt(1);
    expect(
      paragraphBlock.segments.any(
        (segment) => segment.reference?.raw == 'https://example.com',
      ),
      isTrue,
    );

    expect(blocks.whereType<HtmlListBlockNode>().length, 1);
    expect(blocks.whereType<HtmlTableBlockNode>().length, 1);
  });

  testWidgets('reader shows configured columns and pages forward', (
    tester,
  ) async {
    final sampleHtml = StringBuffer('<h1>Reader</h1>');
    for (var i = 1; i <= 30; i++) {
      sampleHtml.write(
        '<p>Paragraph $i Lorem ipsum dolor sit amet, consectetur adipiscing elit.</p>',
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 600,
            child: HtmlColumnReader(
              html: sampleHtml.toString(),
              columnsPerPage: 2,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('html-column-page-0-col-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('html-column-page-0-col-1')),
      findsOneWidget,
    );

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('html-column-page-1-col-0')),
      findsOneWidget,
    );
  });
}
