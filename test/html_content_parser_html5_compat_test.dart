import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_html_column_widget/flutter_html_column_widget.dart';

void main() {
  group('HtmlContentParser HTML5 compatibility', () {
    test('parses semantic sectioning elements as text blocks', () {
      final parser = HtmlContentParser();
      final blocks = parser.parse('''
        <header><p>Header text</p></header>
        <main><article><p>Main article</p></article></main>
        <nav><p>Nav text</p></nav>
        <aside><p>Aside text</p></aside>
        <footer><p>Footer text</p></footer>
      ''');

      final text = blocks
          .whereType<HtmlTextBlockNode>()
          .map((block) => block.plainText)
          .join('\n');

      expect(text, contains('Header text'));
      expect(text, contains('Main article'));
      expect(text, contains('Nav text'));
      expect(text, contains('Aside text'));
      expect(text, contains('Footer text'));
    });

    test('handles HTML5 and XHTML-style void elements consistently', () {
      final parser = HtmlContentParser();
      final blocks = parser.parse(
        '<p>Line 1<br/>Line 2<wbr/>Line 3</p><img src="image.jpg" alt="cover" />',
      );

      final paragraph = blocks.whereType<HtmlTextBlockNode>().first;
      expect(paragraph.plainText, contains('Line 1'));
      expect(paragraph.plainText, contains('\n'));
      expect(paragraph.plainText, contains('\u200B'));

      final image = blocks.whereType<HtmlImageBlockNode>().first;
      expect(image.src, 'image.jpg');
      expect(image.alt, 'cover');
    });

    test('extracts namespaced link metadata in a tolerant way', () {
      final parser = HtmlContentParser();
      final blocks = parser.parse(
        '<p><a href="#note1" EPUB:TYPE="noteref" ROLE="doc-noteref">1</a></p>',
      );

      final paragraph = blocks.whereType<HtmlTextBlockNode>().first;
      final linkedSegment = paragraph.segments.firstWhere(
        (segment) => segment.reference != null,
      );

      expect(linkedSegment.reference?.raw, '#note1');
      expect(linkedSegment.reference?.epubType, 'noteref');
      expect(linkedSegment.reference?.role, 'doc-noteref');
    });

    test('tolerates malformed-but-common HTML5 input', () {
      final parser = HtmlContentParser();
      final blocks = parser.parse('<section><p>First<p>Second</section>');
      final text = blocks
          .whereType<HtmlTextBlockNode>()
          .map((block) => block.plainText)
          .join(' ');

      expect(text, contains('First'));
      expect(text, contains('Second'));
    });

    test('keeps blockquote content with nested paragraphs', () {
      final parser = HtmlContentParser();
      final blocks = parser.parse(
        '<blockquote><p>Quoted</p><p>Text</p></blockquote>',
      );

      final text = blocks
          .whereType<HtmlTextBlockNode>()
          .map((block) => block.plainText)
          .join(' ');
      expect(text, contains('Quoted'));
      expect(text, contains('Text'));
    });
  });
}
