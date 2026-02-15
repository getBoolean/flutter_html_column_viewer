import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_html_column_viewer/flutter_html_column_viewer.dart';

void main() {
  group('EpubCfiParser', () {
    const parser = EpubCfiParser();

    test('extracts candidate ids from an epubcfi reference', () {
      final candidates = parser.parseCandidateIds(
        'book.epub#epubcfi(/6/4[chap01ref]!/4[body01]/10[para05]/3:10)',
      );

      expect(
        candidates,
        containsAll(<String>['chap01ref', 'body01', 'para05']),
      );
    });

    test('returns empty candidates for non-cfi references', () {
      final candidates = parser.parseCandidateIds('chapter1.xhtml#section3');

      expect(candidates, isEmpty);
    });
  });
}
