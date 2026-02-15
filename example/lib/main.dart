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
    return MaterialApp(home: const _ExamplePage());
  }
}

class _ExamplePage extends StatefulWidget {
  const _ExamplePage();

  @override
  State<_ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<_ExamplePage> {
  final HtmlReaderController _readerController = HtmlReaderController();
  final EpubCfiParser _cfiParser = const EpubCfiParser();
  final Map<String, String> _documents = <String, String>{
    'chapter1.xhtml': _chapter1Html,
    'chapter2.xhtml': _chapter2Html,
    'chapters/chapter2.xhtml': _chapter2Html,
  };

  String _currentDocumentPath = 'chapter1.xhtml';
  String _currentHtml = _chapter1Html;
  int _pageCount = 0;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _readerController.pageController.addListener(_onPageChanged);
  }

  @override
  void dispose() {
    _readerController.pageController.removeListener(_onPageChanged);
    _readerController.dispose();
    super.dispose();
  }

  void _onPageChanged() {
    final page = _readerController.pageController.page?.round() ?? 0;
    final maxPage = _pageCount > 0 ? _pageCount - 1 : 0;
    final newPage = page.clamp(0, maxPage);
    if (newPage != _currentPage && mounted) {
      setState(() => _currentPage = newPage);
    }
  }

  void _nextPage() {
    if (_currentPage < _pageCount - 1) {
      _readerController.pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _readerController.pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _handleRefTap(HtmlReference reference) async {
    final targetDocument = _resolveDocument(reference.path);
    final hasExplicitPath =
        reference.path != null && reference.path!.isNotEmpty;
    final isCrossDocument =
        hasExplicitPath &&
        targetDocument != null &&
        _normalizePath(targetDocument) != _normalizePath(_currentDocumentPath);

    if (isCrossDocument) {
      setState(() {
        _currentDocumentPath = targetDocument;
        _currentHtml = _documents[targetDocument]!;
        _currentPage = 0;
        _pageCount = 0;
      });
      _readerController.pageController.jumpToPage(0);
      if (reference.fragmentId != null && reference.fragmentId!.isNotEmpty) {
        _readerController.jumpToReference(reference.fragmentId!);
      }
      return;
    }

    if (reference.fragmentId != null && reference.fragmentId!.isNotEmpty) {
      await _readerController.animateToReference(reference.fragmentId!);
      return;
    }

    if (reference.isCfiLike) {
      final resolved = await _resolveAndNavigateCfi(reference);
      if (resolved) {
        return;
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to resolve CFI target from: ${reference.raw}',
          ),
        ),
      );
      return;
    }

    final uri = reference.uri;
    if (uri != null && uri.hasScheme) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unhandled reference: ${reference.raw}')),
    );
  }

  String? _resolveDocument(String? rawPath) {
    if (rawPath == null || rawPath.isEmpty) {
      return null;
    }
    final normalized = _normalizePath(rawPath);
    for (final key in _documents.keys) {
      if (_normalizePath(key) == normalized) {
        return key;
      }
    }
    return null;
  }

  String _normalizePath(String value) {
    return value.trim().toLowerCase();
  }

  Future<bool> _resolveAndNavigateCfi(HtmlReference reference) async {
    final candidates = _cfiParser.parseCandidateIds(reference.raw);
    if (candidates.isEmpty) {
      return false;
    }

    for (final id in candidates.reversed) {
      final jumped = await _readerController.animateToReference(id);
      if (jumped) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter HTML Viewer Example')),
      body: Column(
        children: [
          Expanded(
            child: HtmlColumnReader(
              controller: _readerController,
              columnsPerPage: 2,
              html: _currentHtml,
              onRefTap: _handleRefTap,
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
                        '${_currentPage + 1} / $_pageCount ($_currentDocumentPath)',
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

const String _chapter1Html = '''
<h1 id="top" style="color:#1a237e;">Chapter 1</h1>
<p style="text-align: justify;">
This demo shows abstract reference handling with <code>onRefTap</code>.
Tap <a href="#section3">same-file anchor</a>,
<a href="chapters/chapter2.xhtml#para12">cross-file reference</a>,
<a href="book.epub#epubcfi(/6/4[chap01ref]!/4[body01]/10[para05]/3:10)">CFI-like reference</a>,
or an <a href="https://example.com">external URL</a>.
</p>
<p>
Accessibility note example:
<a href="#note1" epub:type="noteref" role="doc-noteref">Footnote 1</a>.
</p>
<h2 id="section2">Section 2</h2>
<p>Intro paragraph for chapter 1.</p>
<p>
Section 2 is intentionally long in the example so internal navigation can
demonstrate a page jump when linking to <code>#section3</code>.
</p>
<p>
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer porta orci
at purus varius, eu convallis risus gravida. Sed id ipsum et nunc feugiat
porttitor non non velit.
</p>
<p>
Curabitur ut libero in erat pretium tristique. Vestibulum ante ipsum primis in
faucibus orci luctus et ultrices posuere cubilia curae; Morbi vitae diam
eleifend, dictum sem at, feugiat erat.
</p>
<p>
Mauris finibus magna at nibh feugiat, eget posuere erat bibendum. Suspendisse
interdum, mauris at sagittis euismod, nisi massa luctus augue, id hendrerit
urna arcu in ligula.
</p>
<p>
Praesent non dui venenatis, sodales augue non, dignissim est. Donec tincidunt
velit sed purus vestibulum vulputate. Cras efficitur faucibus hendrerit.
</p>
<p id="para05">
Etiam faucibus eros at justo lobortis, quis tristique lectus aliquet. In sit
amet tristique turpis, non varius neque. Integer hendrerit metus sed velit
facilisis lacinia.
</p>
<p>
Aliquam erat volutpat. In condimentum sem id dui hendrerit, sed ornare lacus
efficitur. Pellentesque id urna in ex ultrices volutpat nec in sapien.
</p>
<h2 id="section3">Section 3</h2>
<p id="para12">Target paragraph in chapter 1 for bookmark-based jumps.</p>
<p id="note1">Footnote 1 text.</p>
<p>More reading content to force pagination.</p>
<p>Lorem ipsum dolor sit amet, consectetur adipiscing elit.</p>
<p>Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.</p>
<p>Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.</p>
<p>Nisi ut aliquip ex ea commodo consequat.</p>
<p>Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore.</p>
<p>Excepteur sint occaecat cupidatat non proident.</p>
<p>Sunt in culpa qui officia deserunt mollit anim id est laborum.</p>
''';

const String _chapter2Html = '''
<h1 id="chapter2-top" style="color:#0d47a1;">Chapter 2</h1>
<p>
You are now in chapter 2.
Tap <a href="chapter1.xhtml#section3">back to chapter 1 section 3</a>.
</p>
<h2 id="overview">Overview</h2>
<p>Chapter 2 starts with an overview section.</p>
<p id="para12">This paragraph is the target for cross-file links.</p>
<p>Additional chapter 2 text to ensure multiple pages are possible.</p>
<p>Lorem ipsum dolor sit amet, consectetur adipiscing elit.</p>
<p>Vestibulum dignissim neque ac arcu interdum, vel tincidunt velit posuere.</p>
<p>Curabitur congue, justo ut varius efficitur, neque arcu consequat justo.</p>
''';
