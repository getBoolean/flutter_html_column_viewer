import 'package:flutter/material.dart';

import 'src/example_reader_service.dart';
import 'src/widgets/example_bottom_controls.dart';
import 'src/widgets/example_reader_view.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: const ExamplePage());
  }
}

class ExamplePage extends StatefulWidget {
  const ExamplePage({super.key});

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  late final ExampleReaderService _service;

  @override
  void initState() {
    super.initState();
    _service = ExampleReaderService();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _service,
      builder: (context, _) {
        final pagination = _service.chapterPagination;
        final pageLabel = _service.pageCount > 0
            ? '${pagination?.current ?? 0} / ${pagination?.total ?? 0} (${_service.currentDocumentPath})'
            : null;

        return Scaffold(
          appBar: AppBar(title: const Text('Flutter HTML Viewer Example')),
          body: Column(
            children: [
              Expanded(
                child: ExampleReaderView(
                  service: _service,
                  onMessage: _showMessage,
                ),
              ),
              ExampleBottomControls(
                canGoPrevious: _service.canGoPrevious,
                canGoNext: _service.canGoNext,
                onPrevious: _service.onPreviousPagePressed,
                onNext: _service.onNextPagePressed,
                pageLabel: pageLabel,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
import 'package:flutter/material.dart';

import 'src/example_reader_service.dart';
import 'src/widgets/example_bottom_controls.dart';
import 'src/widgets/example_reader_view.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: const ExamplePage());
  }
}

class ExamplePage extends StatefulWidget {
  const ExamplePage({super.key});

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  late final ExampleReaderService _service;

  @override
  void initState() {
    super.initState();
    _service = ExampleReaderService();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _service,
      builder: (context, _) {
        final pagination = _service.chapterPagination;
        final pageLabel = _service.pageCount > 0
            ? '${pagination?.current ?? 0} / ${pagination?.total ?? 0} (${_service.currentDocumentPath})'
            : null;

        return Scaffold(
          appBar: AppBar(title: const Text('Flutter HTML Viewer Example')),
          body: Column(
            children: [
              Expanded(
                child: ExampleReaderView(
                  service: _service,
                  onMessage: _showMessage,
                ),
              ),
              ExampleBottomControls(
                canGoPrevious: _service.canGoPrevious,
                canGoNext: _service.canGoNext,
                onPrevious: _service.onPreviousPagePressed,
                onNext: _service.onNextPagePressed,
                pageLabel: pageLabel,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

/*
import 'dart:async';

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
  static const int _columnsPerPage = 2;
  static const int _preloadThresholdColumnPages = 2;
  final Map<String, String> _documents = <String, String>{
    'chapter1.xhtml': _chapter1Html,
    'chapter2.xhtml': _chapter2Html,
    'chapters/chapter2.xhtml': _chapter2Html,
  };
  final List<String> _chapterOrder = <String>[
    'chapter1.xhtml',
    'chapter2.xhtml',
  ];
  final Map<String, String> _canonicalChapterByPath = <String, String>{
    'chapter1.xhtml': 'chapter1.xhtml',
    'chapter2.xhtml': 'chapter2.xhtml',
    'chapters/chapter2.xhtml': 'chapter2.xhtml',
  };
  final Map<String, String> _chapterStartIdByPath = <String, String>{
    'chapter1.xhtml': 'top',
    'chapter2.xhtml': 'chapter2-top',
  };
  final Map<String, String> _epubImageUrlByPath = <String, String>{
    'images/chapter1-illustration.jpg': 'https://picsum.photos/id/1015/640/220',
    'images/chapter2-illustration.jpg': 'https://picsum.photos/id/1025/640/220',
  };

  String _currentDocumentPath = 'chapter1.xhtml';
  final List<String> _loadedChapters = <String>['chapter1.xhtml'];
  Map<String, int> _bookmarkIndex = const <String, int>{};
  Map<String, int> _bookmarkColumnIndex = const <String, int>{};
  Map<String, List<int>> _bookmarkPageCandidates = const <String, List<int>>{};
  int _pageCount = 0;
  int _columnCount = 0;
  int _currentPage = 0;
  bool _isLoadingAdjacentChapter = false;
  Completer<void>? _chapterLoadCompleter;
  bool _pendingAdvanceAfterChapterLoad = false;

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
      _updateCurrentChapterFromPage();
      _maybePreloadNextChapter();
    }
  }

  void _nextPage() {
    if (_currentPage < _pageCount - 1) {
      _readerController.pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    final nextChapterPath = _nextChapterPath();
    if (nextChapterPath == null) {
      return;
    }
    _pendingAdvanceAfterChapterLoad = true;
    unawaited(_ensureChapterLoaded(nextChapterPath));
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
      await _ensureChapterLoaded(
        targetDocument,
        preserveCurrentPosition: false,
      );
      final targetFragment =
          (reference.fragmentId != null && reference.fragmentId!.isNotEmpty)
          ? reference.fragmentId!
          : _chapterStartIdForPath(targetDocument);
      if (targetFragment != null && targetFragment.isNotEmpty) {
        final resolvedTargetPage = _resolvePageInChapterForFragment(
          chapterPath: targetDocument,
          fragmentId: targetFragment,
        );
        if (resolvedTargetPage != null) {
          await _readerController.pageController.animateToPage(
            resolvedTargetPage,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          return;
        }
        final jumped = await _readerController.animateToReference(
          targetFragment,
        );
        if (!jumped) {
          _readerController.jumpToReference(targetFragment);
        }
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
          content: Text('Unable to resolve CFI target from: ${reference.raw}'),
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
    final normalized = _canonicalPath(rawPath);
    if (_documents.containsKey(normalized)) {
      return normalized;
    }
    for (final key in _documents.keys) {
      if (_canonicalPath(key) == normalized) {
        return key;
      }
    }
    return null;
  }

  String? _nextChapterPath() {
    final normalizedCurrentPath = _normalizePath(
      _chapterPathForPage(_currentPage) ?? _currentDocumentPath,
    );
    final canonicalCurrentPath =
        _canonicalChapterByPath[normalizedCurrentPath] ?? normalizedCurrentPath;
    final normalizedOrder = _chapterOrder.map(_normalizePath).toList();
    final currentIndex = normalizedOrder.indexOf(canonicalCurrentPath);
    if (currentIndex == -1 || currentIndex >= normalizedOrder.length - 1) {
      return null;
    }

    final nextCanonicalPath = normalizedOrder[currentIndex + 1];
    return _resolveDocument(nextCanonicalPath);
  }

  String get _currentHtml => _loadedChapters
      .map((path) => _documents[path] ?? '')
      .join('\n<column-break></column-break>\n');

  String? _chapterStartIdForPath(String path) {
    final canonical = _canonicalPath(path);
    return _chapterStartIdByPath[canonical];
  }

  bool _isChapterLoaded(String path) {
    final normalized = _canonicalPath(path);
    return _loadedChapters.any(
      (chapter) => _canonicalPath(chapter) == normalized,
    );
  }

  String? _chapterPathForPage(int page) {
    final currentColumn = _currentAbsoluteColumnForSpread(page);
    String? resolvedPath;
    var resolvedStart = -1;
    for (final chapterPath in _loadedChapters) {
      final startId = _chapterStartIdForPath(chapterPath);
      if (startId == null) {
        continue;
      }
      final startColumn = _bookmarkColumnIndex[startId];
      if (startColumn == null) {
        continue;
      }
      if (startColumn <= currentColumn && startColumn >= resolvedStart) {
        resolvedStart = startColumn;
        resolvedPath = chapterPath;
      }
    }
    if (resolvedPath != null) {
      return resolvedPath;
    }
    return _loadedChapters.isNotEmpty ? _loadedChapters.first : null;
  }

  void _updateCurrentChapterFromPage() {
    final chapterPath = _chapterPathForPage(_currentPage);
    if (chapterPath == null) {
      return;
    }
    if (_normalizePath(chapterPath) != _normalizePath(_currentDocumentPath)) {
      setState(() {
        _currentDocumentPath = chapterPath;
      });
    }
  }

  void _maybePreloadNextChapter() {
    if (_columnCount <= 0 || _isLoadingAdjacentChapter) {
      return;
    }
    final activeChapter =
        _chapterPathForPage(_currentPage) ?? _currentDocumentPath;
    final nextChapter = _nextChapterPath();
    if (nextChapter == null || _isChapterLoaded(nextChapter)) {
      return;
    }

    final chapterEndColumn = _chapterEndColumn(activeChapter);
    if (chapterEndColumn == null) {
      return;
    }
    final remainingColumnPages =
        chapterEndColumn - _currentAbsoluteColumnForSpread(_currentPage);
    if (remainingColumnPages <= _preloadThresholdColumnPages) {
      unawaited(_ensureChapterLoaded(nextChapter));
    }
  }

  int? _chapterEndColumn(String chapterPath) {
    final normalizedOrder = _chapterOrder.map(_normalizePath).toList();
    final normalizedCurrent = _normalizePath(
      _canonicalChapterByPath[_normalizePath(chapterPath)] ??
          _normalizePath(chapterPath),
    );
    final chapterIndex = normalizedOrder.indexOf(normalizedCurrent);
    if (chapterIndex < 0 || chapterIndex >= normalizedOrder.length - 1) {
      return _columnCount > 0 ? _columnCount - 1 : null;
    }
    final nextCanonical = normalizedOrder[chapterIndex + 1];
    final nextChapterPath = _resolveDocument(nextCanonical);
    if (nextChapterPath == null || !_isChapterLoaded(nextChapterPath)) {
      return _columnCount > 0 ? _columnCount - 1 : null;
    }
    final nextStartId = _chapterStartIdForPath(nextChapterPath);
    if (nextStartId == null) {
      return _columnCount > 0 ? _columnCount - 1 : null;
    }
    final nextStartColumn = _bookmarkColumnIndex[nextStartId];
    if (nextStartColumn == null) {
      return _columnCount > 0 ? _columnCount - 1 : null;
    }
    return (nextStartColumn - 1).clamp(0, _columnCount - 1);
  }

  Future<void> _ensureChapterLoaded(
    String chapterPath, {
    bool preserveCurrentPosition = true,
  }) async {
    final resolved = _resolveDocument(chapterPath);
    if (resolved == null || _isChapterLoaded(resolved)) {
      return;
    }
    if (_isLoadingAdjacentChapter) {
      await _chapterLoadCompleter?.future;
      return;
    }
    final previousPage = _currentPage;
    _isLoadingAdjacentChapter = true;
    final loadCompleter = Completer<void>();
    _chapterLoadCompleter = loadCompleter;
    setState(() {
      _loadedChapters.add(resolved);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _isLoadingAdjacentChapter = false;
        _chapterLoadCompleter = null;
        _pendingAdvanceAfterChapterLoad = false;
        loadCompleter.complete();
        return;
      }
      if (preserveCurrentPosition) {
        _readerController.pageController.jumpToPage(previousPage);
      }
      _isLoadingAdjacentChapter = false;
      _chapterLoadCompleter = null;
      _maybePreloadNextChapter();
      loadCompleter.complete();
    });
    await loadCompleter.future;
  }

  int _chapterStartColumn(String chapterPath) {
    final startId = _chapterStartIdForPath(chapterPath);
    if (startId == null) {
      return 0;
    }
    return _bookmarkColumnIndex[startId] ?? 0;
  }

  int? _resolvePageInChapterForFragment({
    required String chapterPath,
    required String fragmentId,
  }) {
    final candidates = _bookmarkPageCandidates[fragmentId];
    if (candidates == null || candidates.isEmpty) {
      return null;
    }

    final startColumn = _chapterStartColumn(chapterPath);
    final endColumn = _chapterEndColumn(chapterPath) ?? (_columnCount - 1);
    final startPage = startColumn ~/ _columnsPerPage;
    final endPage = endColumn ~/ _columnsPerPage;
    for (final page in candidates) {
      if (page >= startPage && page <= endPage) {
        return page;
      }
    }
    return null;
  }

  int _currentAbsoluteColumnForSpread(int spreadPage) {
    if (_columnCount <= 0) {
      return 0;
    }
    final absolute = spreadPage * _columnsPerPage;
    return absolute.clamp(0, _columnCount - 1);
  }

  ({int current, int total})? _currentChapterColumnPagination() {
    if (_columnCount <= 0) {
      return null;
    }
    final chapterPath =
        _chapterPathForPage(_currentPage) ?? _currentDocumentPath;
    final chapterStartColumn = _chapterStartColumn(chapterPath);
    final chapterEndColumn =
        _chapterEndColumn(chapterPath) ?? (_columnCount - 1);
    final totalColumnPages = (chapterEndColumn - chapterStartColumn + 1).clamp(
      1,
      _columnCount,
    );
    final currentColumn = _currentAbsoluteColumnForSpread(_currentPage);
    final currentColumnPage = (currentColumn - chapterStartColumn + 1).clamp(
      1,
      totalColumnPages,
    );
    return (current: currentColumnPage, total: totalColumnPages);
  }

  String _normalizePath(String value) {
    return value.trim().toLowerCase();
  }

  String _canonicalPath(String value) {
    final normalized = _normalizePath(value);
    return _canonicalChapterByPath[normalized] ?? normalized;
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

  Widget _buildExampleImage(BuildContext context, String src, String? alt) {
    final colorScheme = Theme.of(context).colorScheme;
    final imageUri = Uri.tryParse(src.trim());
    final isRemote =
        imageUri != null &&
        (imageUri.scheme == 'http' || imageUri.scheme == 'https');
    final resolvedEpubPath = _resolveEpubImagePath(src);
    final mappedRemoteUrl = resolvedEpubPath == null
        ? null
        : _epubImageUrlByPath[_normalizePath(resolvedEpubPath)];
    final effectiveUrl = isRemote ? src : mappedRemoteUrl;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: effectiveUrl == null
                  ? ColoredBox(
                      color: colorScheme.tertiaryContainer,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'Resolved EPUB path:\n${resolvedEpubPath ?? src}\n\n'
                            'No mapping found in example asset map.',
                            style: TextStyle(
                              color: colorScheme.onTertiaryContainer,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                  : Image.network(
                      effectiveUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) {
                          return child;
                        }
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return ColoredBox(
                          color: colorScheme.errorContainer,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                'Image failed to load',
                                style: TextStyle(
                                  color: colorScheme.onErrorContainer,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          if (alt != null && alt.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              alt,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            isRemote
                ? src
                : 'EPUB src: $src'
                      '${resolvedEpubPath == null ? '' : ' -> $resolvedEpubPath'}'
                      '${effectiveUrl == null ? '' : ' -> $effectiveUrl'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  String? _resolveEpubImagePath(String rawSrc) {
    final src = rawSrc.trim();
    if (src.isEmpty) {
      return null;
    }

    final parsed = Uri.tryParse(src);
    if (parsed != null && parsed.hasScheme) {
      return null;
    }

    final normalizedCurrentPath = _normalizePath(_currentDocumentPath);
    final baseUri = Uri.parse(
      normalizedCurrentPath.contains('/')
          ? normalizedCurrentPath
          : '/$normalizedCurrentPath',
    );
    final resolved = baseUri.resolve(src).path;
    return resolved.startsWith('/') ? resolved.substring(1) : resolved;
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
              columnsPerPage: _columnsPerPage,
              html: _currentHtml,
              onRefTap: _handleRefTap,
              imageBuilder: _buildExampleImage,
              onPageCountChanged: (count) {
                setState(() => _pageCount = count);
                if (_pendingAdvanceAfterChapterLoad &&
                    count > 0 &&
                    _currentPage < count - 1) {
                  _pendingAdvanceAfterChapterLoad = false;
                  _readerController.pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
              onColumnCountChanged: (count) {
                _columnCount = count;
              },
              onBookmarkIndexChanged: (index) {
                _bookmarkIndex = index;
                _updateCurrentChapterFromPage();
                _maybePreloadNextChapter();
              },
              onBookmarkColumnIndexChanged: (index) {
                _bookmarkColumnIndex = index;
                _updateCurrentChapterFromPage();
                _maybePreloadNextChapter();
              },
              onBookmarkPageCandidatesChanged: (candidates) {
                _bookmarkPageCandidates = candidates;
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 360;
                  final chapterPagination = _currentChapterColumnPagination();
                  final previousButton = compact
                      ? IconButton.filledTonal(
                          onPressed: _currentPage > 0 ? _previousPage : null,
                          tooltip: 'Previous',
                          icon: const Icon(Icons.arrow_back),
                        )
                      : FilledButton.tonalIcon(
                          onPressed: _currentPage > 0 ? _previousPage : null,
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Previous'),
                        );
                  final nextButton = compact
                      ? IconButton.filledTonal(
                          onPressed:
                              _pageCount > 0 &&
                                  (_currentPage < _pageCount - 1 ||
                                      _nextChapterPath() != null)
                              ? _nextPage
                              : null,
                          tooltip: 'Next',
                          icon: const Icon(Icons.arrow_forward),
                        )
                      : FilledButton.tonalIcon(
                          onPressed:
                              _pageCount > 0 &&
                                  (_currentPage < _pageCount - 1 ||
                                      _nextChapterPath() != null)
                              ? _nextPage
                              : null,
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Next'),
                        );

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      previousButton,
                      if (_pageCount > 0) ...[
                        SizedBox(width: compact ? 8 : 12),
                        Expanded(
                          child: Text(
                            '${chapterPagination?.current ?? 0} / ${chapterPagination?.total ?? 0} ($_currentDocumentPath)',
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(width: compact ? 8 : 12),
                      ],
                      nextButton,
                    ],
                  );
                },
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
<h2 id="supported-html-css">Supported HTML and CSS examples</h2>
<h3 style="color: rgb(38, 70, 83);">Heading level 3</h3>
<h4 style="color: teal;">Heading level 4</h4>
<h5 style="font-style: italic;">Heading level 5</h5>
<h6 style="text-decoration: underline;">Heading level 6</h6>
<section id="section-block" style="background-color: #f1f8e9;">
  <p style="font-size: 18px; font-weight: 600;">
    Section + paragraph with inline CSS: <strong>strong</strong>, <b>b</b>,
    <em>em</em>, <i>i</i>, <u>u</u>, and inline <code>code()</code>.
  </p>
</section>
<article id="article-block">
  <div style="text-align: center; color: #37474f;">
    Article + div block with centered text and named/hex colors.
    <br>
    This second line is created with a <code>&lt;br&gt;</code> tag.
  </div>
</article>
<blockquote style="font-style: italic; color: #424242;">
  Blockquote example rendered with a quote border style in Flutter.
</blockquote>
<pre id="pre-sample" style="background-color: #eeeeee; color: #1b5e20;">
for (var i = 0; i < 3; i++) {
  print('preformatted code line \$i');
}
</pre>
<hr>
<ul id="unordered-list">
  <li>Unordered item with <strong>bold text</strong></li>
  <li>Unordered item with <em>italic text</em></li>
  <li>Unordered item with <u>underlined text</u></li>
</ul>
<ol id="ordered-list" style="font-size: 15px;">
  <li>Ordered item one</li>
  <li>Ordered item two</li>
  <li>Ordered item three</li>
</ol>
<table id="table-sample">
  <tr>
    <th>Tag</th>
    <th>Status</th>
    <th>Notes</th>
  </tr>
  <tr>
    <td>table</td>
    <td>Supported</td>
    <td>th/td rows are rendered as Flutter Table</td>
  </tr>
  <tr>
    <td>img</td>
    <td>Supported</td>
    <td>Uses Image.network by default</td>
  </tr>
</table>
<img
  id="example-image"
  src="https://picsum.photos/640/220"
  alt="Example network image rendered from the img tag"
>
<img
  id="example-epub-image-path"
  src="images/chapter1-illustration.jpg"
  alt="Example EPUB-style relative image path resolved by imageBuilder"
>
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
*/
