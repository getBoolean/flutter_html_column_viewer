import 'package:flutter/material.dart' show Colors;
import 'package:flutter/widgets.dart';
import 'package:flutter_html_column_widget/flutter_html_column_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CSS style engine', () {
    test('applies cascade with inline > id > class > element', () {
      final parser = HtmlContentParser();
      final blocks = parser.parse('''
        <style>
          p { color: #ff0000; }
          .note { color: #00ff00; }
          #target { color: #0000ff; }
        </style>
        <p id="target" class="note" style="color: #010203">hello</p>
      ''');

      final paragraph = blocks.whereType<HtmlTextBlockNode>().first;
      expect(paragraph.style.color, const Color(0xFF010203));
    });

    test('inherits inheritable properties from parent styles', () {
      final parser = HtmlContentParser();
      final blocks = parser.parse('''
        <style>
          div { color: #123456; font-family: "Roboto"; }
        </style>
        <div><p>child</p></div>
      ''');

      final paragraph = blocks.whereType<HtmlTextBlockNode>().first;
      expect(paragraph.style.color, const Color(0xFF123456));
      expect(paragraph.style.fontFamily, 'Roboto');
    });

    test('reads external chapter css and link-resolved css', () {
      final parser = HtmlContentParser();
      final blocks = parser.parse(
        '''
        <link rel="stylesheet" href="chapter.css">
        <p class="chapter">content</p>
        ''',
        externalCss: '.chapter { text-align: center; }',
        externalCssResolver: (href) {
          if (href == 'chapter.css') {
            return '.chapter { line-height: 1.8; }';
          }
          return null;
        },
      );

      final paragraph = blocks.whereType<HtmlTextBlockNode>().first;
      expect(paragraph.style.textAlign, TextAlign.center);
      expect(paragraph.style.lineHeight, closeTo(1.8, 0.0001));
    });

    test('does not apply alternate stylesheets by default', () {
      final parser = HtmlContentParser();
      final blocks = parser.parse(
        '''
        <link rel="stylesheet" href="base.css">
        <link rel="alternate stylesheet" href="alternate.css">
        <p class="sample">content</p>
        ''',
        externalCssResolver: (href) {
          if (href == 'base.css') {
            return '.sample { text-decoration: underline; }';
          }
          if (href == 'alternate.css') {
            return '.sample { text-decoration: none; }';
          }
          return null;
        },
      );

      final paragraph = blocks.whereType<HtmlTextBlockNode>().first;
      expect(paragraph.style.decoration, TextDecoration.underline);
    });

    test('applies leading @import rules from style blocks', () {
      final parser = HtmlContentParser();
      final blocks = parser.parse(
        '''
        <style>
          @import url("imported.css");
        </style>
        <p class="sample">content</p>
        ''',
        externalCssResolver: (href) {
          if (href == 'imported.css') {
            return '.sample { color: #00aa00; }';
          }
          return null;
        },
      );

      final paragraph = blocks.whereType<HtmlTextBlockNode>().first;
      expect(paragraph.style.color, const Color(0xFF00AA00));
    });

    test('ignores non-leading @import rules', () {
      final parser = HtmlContentParser();
      final blocks = parser.parse(
        '''
        <style>
          @import url("first.css");
          .sample { color: #111111; }
          @import url("late.css");
        </style>
        <p class="sample">content</p>
        ''',
        externalCssResolver: (href) {
          if (href == 'first.css') {
            return '.sample { line-height: 1.8; }';
          }
          if (href == 'late.css') {
            return '.sample { color: #ff0000; }';
          }
          return null;
        },
      );

      final paragraph = blocks.whereType<HtmlTextBlockNode>().first;
      expect(paragraph.style.color, const Color(0xFF111111));
      expect(paragraph.style.lineHeight, closeTo(1.8, 0.0001));
    });

    test('applies @import inside legacy HTML comment wrappers', () {
      final parser = HtmlContentParser();
      final blocks = parser.parse(
        '''
        <style>
          <!--
          @import url("imported.css");
          -->
        </style>
        <p class="sample">content</p>
        ''',
        externalCssResolver: (href) {
          if (href == 'imported.css') {
            return '.sample { color: #228b22; }';
          }
          return null;
        },
      );

      final paragraph = blocks.whereType<HtmlTextBlockNode>().first;
      expect(paragraph.style.color, const Color(0xFF228B22));
    });

    test('applies li selector styles over inherited ul color', () {
      final parser = HtmlContentParser();
      final blocks = parser.parse('''
        <style>
          ul { color: red; }
          li.three { color: green; }
          li.threea { color: purple; }
        </style>
        <ul>
          <li class="threea">purple item</li>
          <li class="three">green item</li>
        </ul>
        ''');

      final list = blocks.whereType<HtmlListBlockNode>().first;
      final firstItemColor = list.items[0].first.style.color;
      final secondItemColor = list.items[1].first.style.color;
      expect(firstItemColor, Colors.purple);
      expect(secondItemColor, Colors.green);
    });

    test('applies selectors wrapped in legacy HTML comment tokens', () {
      final parser = HtmlContentParser();
      final blocks = parser.parse('''
        <style>
          <!--
          p.six { color: green; }
          -->
        </style>
        <p class="six">green paragraph</p>
        ''');

      final paragraph = blocks.whereType<HtmlTextBlockNode>().first;
      expect(paragraph.style.color, Colors.green);
    });

    test('keeps parsing selectors after ignored non-leading @import', () {
      final parser = HtmlContentParser();
      final blocks = parser.parse('''
        <style>
          p.before { color: black; }
          @import url("late.css");
          p.six { color: green; }
        </style>
        <p class="six">green paragraph</p>
        ''');

      final paragraph = blocks.whereType<HtmlTextBlockNode>().first;
      expect(paragraph.style.color, Colors.green);
    });

    test('parses typography and spacing properties', () {
      final parser = HtmlContentParser();
      final blocks = parser.parse('''
        <p style="
          line-height: 1.6;
          letter-spacing: 2px;
          word-spacing: 3px;
          text-indent: 8px;
          text-transform: uppercase;
          white-space: pre-wrap;
          margin: 4px 8px;
          padding: 2px 6px;
          border-left: 3px solid #333333;
        ">hello</p>
      ''');

      final paragraph = blocks.whereType<HtmlTextBlockNode>().first;
      expect(paragraph.style.lineHeight, closeTo(1.6, 0.0001));
      expect(paragraph.style.letterSpacing, closeTo(2, 0.0001));
      expect(paragraph.style.wordSpacing, closeTo(3, 0.0001));
      expect(paragraph.style.textIndent, closeTo(8, 0.0001));
      expect(paragraph.style.textTransform, HtmlTextTransform.uppercase);
      expect(paragraph.style.whiteSpace, HtmlWhiteSpace.preWrap);
      expect(
        paragraph.style.margin,
        const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      );
      expect(
        paragraph.style.padding,
        const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
      );
      expect(paragraph.style.borderLeftWidth, closeTo(3, 0.0001));
      expect(paragraph.style.borderLeftColor, const Color(0xFF333333));
    });

    test('parses font-variant small-caps', () {
      final parser = HtmlContentParser();
      final blocks = parser.parse(
        '<p style="font-variant: small-caps">hello</p>',
      );

      final paragraph = blocks.whereType<HtmlTextBlockNode>().first;
      expect(paragraph.style.fontVariant, HtmlFontVariant.smallCaps);
    });

    test('supports important precedence in cascade', () {
      final parser = HtmlContentParser();
      final blocks = parser.parse('''
        <style>
          p.note { color: #111111; }
          p { color: #333333 !important; }
        </style>
        <section><p class="note" data-kind="x">value</p></section>
      ''');
      final paragraph = blocks.whereType<HtmlTextBlockNode>().first;
      expect(paragraph.segments.first.style.color, const Color(0xFF333333));
    });

    test('parses all border sides from shorthand and side overrides', () {
      final parser = HtmlContentParser();
      final blocks = parser.parse('''
        <p style="
          border: 1px solid #111111;
          border-top-width: 2px;
          border-right-color: #00ff00;
          border-bottom-style: dashed;
        ">hello</p>
      ''');
      final paragraph = blocks.whereType<HtmlTextBlockNode>().first;
      expect(paragraph.style.borderTopWidth, closeTo(2, 0.0001));
      expect(paragraph.style.borderRightColor, const Color(0xFF00FF00));
      expect(paragraph.style.borderBottomStyle, BorderStyle.solid);
      expect(paragraph.style.borderLeftWidth, closeTo(1, 0.0001));
    });

    test('parses background shorthand color and percentage width', () {
      final parser = HtmlContentParser();
      final blocks = parser.parse(
        '<p style="background: #cccccc; width: 100%;">hello</p>',
      );
      final paragraph = blocks.whereType<HtmlTextBlockNode>().first;
      expect(paragraph.style.blockBackgroundColor, const Color(0xFFCCCCCC));
      expect(
        paragraph.style.boxStyle?.backgroundColor,
        const Color(0xFFCCCCCC),
      );
      expect(paragraph.style.boxStyle?.widthFactor, closeTo(1.0, 0.0001));
    });

    test('resolves document background from body selector', () {
      final parser = HtmlContentParser();
      final style = parser.parseDocumentStyle('''
        <style>
          body { background: #cccccc; }
        </style>
        <p>hello</p>
      ''');
      expect(style.blockBackgroundColor, const Color(0xFFCCCCCC));
    });
  });
}
