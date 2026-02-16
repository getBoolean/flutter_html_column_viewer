import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html_column_widget/flutter_html_column_widget.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _renderParsedHtml(
  String html, {
  String? externalCss,
  Map<String, String> linkedCss = const <String, String>{},
}) {
  final parser = HtmlContentParser();
  final blocks = parser.parse(
    html,
    externalCss: externalCss,
    externalCssResolver: (href) => linkedCss[href],
  );

  return MaterialApp(
    home: Material(
      color: Colors.white,
      child: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: blocks
              .map(
                (block) => HtmlBlockView(
                  block: block,
                  blockContext: HtmlBlockContext(
                    baseStyle: const TextStyle(fontSize: 14),
                    imageBuilder: (context, src, alt) => Container(
                      color: const Color(0xFFE6EEF8),
                      height: 120,
                      alignment: Alignment.center,
                      child: Text(alt ?? src, textAlign: TextAlign.center),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ),
    ),
  );
}

void main() {
  group('Html parser/spec golden rendering', () {
    goldenTest(
      'css-cascade-precedence',
      fileName: 'css_cascade_precedence',
      builder: () => _labeledGolden(
        name: 'inline beats id class and element',
        child: _renderParsedHtml('''
              <style>
                p { color: #ff0000; }
                .note { color: #00ff00; }
                #target { color: #0000ff; }
              </style>
              <p id="target" class="note" style="color: #010203">hello</p>
            '''),
      ),
    );

    goldenTest(
      'text-whitespace-transform-and-indentation',
      fileName: 'text_whitespace_transform_indent',
      builder: () => _labeledGolden(
        name: 'pre pre-line uppercase text-indent',
        child: _renderParsedHtml('''
              <p style="white-space: pre-line">one   two
              three</p>
              <p style="text-transform: uppercase; text-indent: 12px">hello world</p>
              <pre>line 1
                line 2</pre>
            '''),
      ),
    );

    goldenTest(
      'list-markers-table-and-blockquote',
      fileName: 'list_table_blockquote',
      builder: () => _labeledGolden(
        name: 'roman list plus table and blockquote',
        child: _renderParsedHtml('''
              <ol style="list-style-type: lower-roman">
                <li>One</li>
                <li>Two</li>
              </ol>
              <blockquote style="border-left: 3px solid #333333; padding: 4px 6px">
                Quoted text
              </blockquote>
              <table>
                <tr><th>H1</th><th>H2</th></tr>
                <tr><td>A</td><td>B</td></tr>
              </table>
            '''),
      ),
    );

    goldenTest(
      'references-images-and-explicit-breaks',
      fileName: 'references_images_breaks',
      builder: () => _labeledGolden(
        name: 'anchor metadata image hr column-break',
        child: _renderParsedHtml('''
              <p>
                See <a href="#note1" epub:type="noteref" role="doc-noteref">1</a>
                before break.
              </p>
              <img src="cover.jpg" width="400" height="200" alt="Cover art" />
              <hr />
              <column-break></column-break>
              <p>After break.</p>
            '''),
      ),
    );

    goldenTest(
      'external-css-ordering',
      fileName: 'external_css_ordering',
      builder: () => _labeledGolden(
        name: 'external link style and inline style sheet ordering',
        child: _renderParsedHtml(
          '''
              <link rel="stylesheet" href="chapter.css" />
              <style>.chapter { line-height: 2; }</style>
              <p class="chapter">chapter text</p>
              ''',
          externalCss: '.chapter { text-align: center; }',
          linkedCss: const <String, String>{
            'chapter.css': '.chapter { line-height: 1.8; color: #224466; }',
          },
        ),
      ),
    );
  });
}

Widget _labeledGolden({required String name, required Widget child}) {
  return Material(
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    ),
  );
}
