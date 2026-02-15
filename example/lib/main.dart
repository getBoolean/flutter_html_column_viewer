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
      home: const _ExamplePage(),
    );
  }
}

class _ExamplePage extends StatefulWidget {
  const _ExamplePage();

  @override
  State<_ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<_ExamplePage> {
  final PageController _pageController = PageController();
  int _pageCount = 0;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_onPageChanged);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged() {
    final page = _pageController.page?.round() ?? 0;
    final maxPage = _pageCount > 0 ? _pageCount - 1 : 0;
    final newPage = page.clamp(0, maxPage);
    if (newPage != _currentPage && mounted) {
      setState(() => _currentPage = newPage);
    }
  }

  void _nextPage() {
    if (_currentPage < _pageCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter HTML Viewer Example')),
      body: Column(
        children: [
          Expanded(
            child: HtmlColumnReader(
              controller: _pageController,
              columnsPerPage: 2,
              html: _sampleHtml,
              onLinkTap: (href) {
                final uri = Uri.tryParse(href);
                if (uri != null) {
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              onPageCountChanged: (count) {
                setState(() => _pageCount = count);
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _currentPage > 0 ? _previousPage : null,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Previous'),
                  ),
                  if (_pageCount > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '${_currentPage + 1} / $_pageCount',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  FilledButton.tonalIcon(
                    onPressed: _pageCount > 0 && _currentPage < _pageCount - 1
                        ? _nextPage
                        : null,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Next'),
                  ),
                ],
              ),
            ),
          ),
        ],
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
