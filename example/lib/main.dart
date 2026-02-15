import 'package:flutter/material.dart';
import 'package:flutter_html_column_viewer/flutter_html_column_viewer.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Flutter HTML Viewer Example')),
        body: HtmlColumnReader(
          columnsPerPage: 2,
          html: _sampleHtml,
          onLinkTap: (href) {
            final uri = Uri.tryParse(href);
            if (uri != null) {
              launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        ),
      ),
    );
  }
}

const String _sampleHtml = '''
<h1 style="color:#1a237e;">Column HTML Reader</h1>
<p style="text-align: justify;">
This package renders HTML as paged multi-column content using Flutter widgets.
Each page shows exactly two columns and swiping horizontally navigates to the next two columns.
</p>
<blockquote style="background-color:#f3f4f6;">
Column rendering is useful for reading long-form text on larger screens.
</blockquote>
<h2>Supported Tags</h2>
<ul>
  <li><strong>Headings</strong>, paragraphs, and links</li>
  <li>Lists, blockquotes, code/pre blocks</li>
  <li>Tables and images</li>
</ul>
<p>
Here is an <a href="https://example.com">example link</a>.
</p>
<pre style="background-color:#eceff1;">
final reader = HtmlColumnReader(
  html: htmlString,
  columnsPerPage: 2,
);
</pre>
<table>
  <tr><th>Feature</th><th>Status</th></tr>
  <tr><td>HTML Parsing</td><td>html 0.15.6</td></tr>
  <tr><td>CSS Parsing</td><td>csslib 1.0.2</td></tr>
  <tr><td>Column Paging</td><td>Enabled</td></tr>
</table>
<h2>More Content</h2>
<p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed imperdiet volutpat est, quis tincidunt justo tincidunt sit amet.</p>
<p>Vestibulum dignissim neque ac arcu interdum, vel tincidunt velit posuere. Praesent mattis, nunc at fringilla elementum.</p>
<p>Integer tincidunt eros eget nisl tristique, ut fermentum tortor pulvinar. Aenean at est gravida, cursus ligula eu, egestas risus.</p>
<p>Suspendisse potenti. Nunc vel orci non arcu ullamcorper luctus sit amet sed eros. Nulla facilisi.</p>
<p>Quisque eu convallis massa. Fusce ac nibh in lorem faucibus luctus quis ac risus.</p>
<p>Aliquam erat volutpat. Sed rutrum, lorem id luctus egestas, orci velit lacinia justo, non varius turpis nibh sed libero.</p>
<p>Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas.</p>
<p>Vivamus consequat, ante id ultricies finibus, velit nunc pellentesque est, sit amet lacinia ipsum mauris vel sem.</p>
<p>Donec posuere diam nec nunc dictum, eu facilisis erat sodales. Mauris vulputate semper pellentesque.</p>
<p>Nam semper magna et tellus vulputate, sed feugiat lorem semper. Curabitur congue, justo ut varius efficitur, neque arcu consequat justo.</p>
''';
