import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_html_column_viewer/flutter_html_column_viewer.dart';

void main() {
  group('HtmlContentParser XHTML-style compatibility', () {
    test('accepts XHTML-style namespace declarations and epub:type links', () {
      final parser = HtmlContentParser();
      final blocks = parser.parse('''
        <section xmlns:epub="http://www.idpf.org/2007/ops">
          <p>
            <a href="#note1" epub:type="noteref" role="doc-noteref">Footnote</a>
          </p>
        </section>
      ''');

      final paragraph = blocks.whereType<HtmlTextBlockNode>().first;
      final linkedSegment = paragraph.segments.firstWhere(
        (segment) => segment.reference != null,
      );

      expect(linkedSegment.reference?.raw, '#note1');
      expect(linkedSegment.reference?.epubType, 'noteref');
      expect(linkedSegment.reference?.role, 'doc-noteref');
    });

    test('supports XHTML-style self-closing syntax for mixed inline/block tags', () {
      final parser = HtmlContentParser();
      final blocks = parser.parse('''
        <p>Before<br/>After</p>
        <hr/>
        <img src="cover.jpg" alt="Cover"/>
      ''');

      final paragraph = blocks.whereType<HtmlTextBlockNode>().first;
      expect(paragraph.plainText, contains('Before'));
      expect(paragraph.plainText, contains('\n'));
      expect(paragraph.plainText, contains('After'));

      expect(blocks.whereType<HtmlDividerBlockNode>(), hasLength(1));
      expect(blocks.whereType<HtmlImageBlockNode>(), hasLength(1));
    });

    test('parses XHTML-style attributes for image sizing', () {
      final parser = HtmlContentParser();
      final blocks = parser.parse(
        '<img src="img.jpg" width="400" height="200" alt="Sized image" />',
      );

      final image = blocks.whereType<HtmlImageBlockNode>().first;
      expect(image.src, 'img.jpg');
      expect(image.alt, 'Sized image');
      expect(image.intrinsicAspectRatio, closeTo(2.0, 0.0001));
    });
  });
}
