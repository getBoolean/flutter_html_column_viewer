import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show NetworkAssetBundle;
import 'package:flutter_html_column_widget/flutter_html_column_widget.dart';

import 'helpers/example_demo_content.dart';
import 'helpers/example_reader_chapters.dart';
import 'helpers/example_reader_images.dart';
import 'helpers/example_reader_links.dart';
import 'helpers/example_reader_models.dart';
import 'helpers/example_reader_pagination.dart';
import 'helpers/example_reader_paths.dart';

class ExampleReaderService extends ChangeNotifier {
  ExampleReaderService() {
    readerController.pageController.addListener(_onPageChanged);
  }

  final HtmlReaderController readerController = HtmlReaderController();
  final EpubCfiParser _cfiParser = const EpubCfiParser();
  final ExampleReaderPaths _paths = const ExampleReaderPaths();
  late final ExampleReaderChapters _chapters = ExampleReaderChapters(
    paths: _paths,
  );
  late final ExampleReaderImages _images = ExampleReaderImages(paths: _paths);
  final ExampleReaderLinks _links = const ExampleReaderLinks();

  static const int columnsPerPage = 2;
  static const int _preloadThresholdColumnPages = 2;
  static const int _imagePreloadThresholdPages = 3;
  static const Duration _pageAnimationDuration = Duration(milliseconds: 300);
  static const Curve _pageAnimationCurve = Curves.easeInOut;
  static const ExampleReaderPagination _pagination = ExampleReaderPagination(
    columnsPerPage: columnsPerPage,
  );

  String _currentChapterPath = ExampleDemoContent.initialDocumentPath;
  final List<String> _loadedChapters = <String>[
    ExampleDemoContent.initialDocumentPath,
  ];
  Map<String, int> _bookmarkColumnIndex = const <String, int>{};
  Map<String, List<int>> _bookmarkPageCandidates = const <String, List<int>>{};
  int _pageCount = 0;
  int _columnCount = 0;
  int _currentPage = 0;
  bool _isLoadingAdjacentChapter = false;
  Completer<void>? _chapterLoadCompleter;
  final Map<String, Future<Uint8List?>> _imageBytesByUrl =
      <String, Future<Uint8List?>>{};
  final HtmlContentParser _htmlParser = HtmlContentParser();
  final Map<String, List<HtmlImageRef>> _chapterImageRefs =
      <String, List<HtmlImageRef>>{};

  String get currentChapterPath => _currentChapterPath;
  int get currentPage => _currentPage;
  int get pageCount => _pageCount;
  bool get canGoPrevious => _currentPage > 0;
  bool get canGoNext =>
      _pageCount > 0 &&
      (_currentPage < _pageCount - 1 ||
          _chapters.nextChapterPath(
                activeChapterPath:
                    _chapterPathForForwardNavigation(_currentPage) ??
                    _currentChapterPath,
                resolveDocument: _paths.resolveDocument,
              ) !=
              null);

  String get currentHtml => _loadedChapters
      .map((path) => ExampleDemoContent.documents[path] ?? '')
      .join('\n<column-break></column-break>\n');

  String? get currentExternalCss {
    final css = _loadedChapters
        .map((path) {
          final canonical = _paths.canonicalPath(path);
          return ExampleDemoContent.externalCssByChapterPath[canonical];
        })
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .toList(growable: false);
    if (css.isEmpty) {
      return null;
    }
    return css.join('\n');
  }

  ChapterPagination? get currentChapterPagination =>
      _pagination.currentChapterPagination(
        columnCount: _columnCount,
        currentSpreadPage: _currentPage,
        chapterStartColumn: _chapterStartColumn(
          _chapterPathForPage(_currentPage) ?? _currentChapterPath,
        ),
        chapterEndColumn:
            _chapterEndColumn(
              _chapterPathForPage(_currentPage) ?? _currentChapterPath,
            ) ??
            (_columnCount - 1),
      );

  void goToPreviousPage() {
    if (_currentPage <= 0) {
      return;
    }
    readerController.pageController.previousPage(
      duration: _pageAnimationDuration,
      curve: _pageAnimationCurve,
    );
  }

  void goToNextPage() {
    if (_currentPage < _pageCount - 1) {
      readerController.pageController.nextPage(
        duration: _pageAnimationDuration,
        curve: _pageAnimationCurve,
      );
      return;
    }

    final nextChapterPath = _chapters.nextChapterPath(
      activeChapterPath:
          _chapterPathForForwardNavigation(_currentPage) ?? _currentChapterPath,
      resolveDocument: _paths.resolveDocument,
    );
    if (nextChapterPath == null) {
      return;
    }
    // Navigate directly to the start of the next chapter instead of relying on
    // deferred "advance after preload" state.
    unawaited(
      _navigateToChapterFragment(chapterPath: nextChapterPath, fragmentId: null),
    );
  }

  Future<String?> handleLinkTap(HtmlReference reference) {
    return _links.handleLinkTap(
      reference: reference,
      currentChapterPath: _currentChapterPath,
      resolvedTargetDocument: _paths.resolveDocument(reference.path),
      normalizePath: _paths.normalizePath,
      navigateToChapterFragment: _navigateToChapterFragment,
      resolveAndNavigateCfi: _resolveAndNavigateCfi,
      readerController: readerController,
    );
  }

  Future<int?> _navigateToChapterFragment({
    required String chapterPath,
    required String? fragmentId,
  }) async {
    await _ensureChapterLoaded(chapterPath, preserveCurrentPosition: false);
    final targetFragment = (fragmentId != null && fragmentId.isNotEmpty)
        ? fragmentId
        : _paths.chapterStartIdForPath(chapterPath);
    if (targetFragment == null || targetFragment.isEmpty) {
      return null;
    }

    final resolvedTargetPage = _resolvePageInChapterForFragment(
      chapterPath: chapterPath,
      fragmentId: targetFragment,
    );
    if (resolvedTargetPage != null) {
      await readerController.pageController.animateToPage(
        resolvedTargetPage,
        duration: _pageAnimationDuration,
        curve: _pageAnimationCurve,
      );
      return resolvedTargetPage;
    }

    final jumped = await readerController.animateToReference(targetFragment);
    if (!jumped) {
      readerController.jumpToReference(targetFragment);
    }
    return null;
  }

  ExampleImageData resolveImage(String src, String? alt) {
    return _images.resolveImage(
      src: src,
      alt: alt,
      currentChapterPath: _currentChapterPath,
    );
  }

  Future<Uint8List?> resolveImageBytes(String src, String? alt) {
    final image = resolveImage(src, alt);
    final url = image.effectiveUrl?.trim();
    if (url == null || url.isEmpty) {
      return Future<Uint8List?>.value(null);
    }
    return _imageBytesByUrl.putIfAbsent(url, () async {
      try {
        final byteData = await NetworkAssetBundle(
          Uri.parse(url),
        ).load(url).timeout(const Duration(seconds: 8));
        return byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        );
      } catch (_) {
        return null;
      }
    });
  }

  String? resolveExternalCss(String href) {
    final normalized = _paths.normalizePath(href);
    return ExampleDemoContent.styleSheets[normalized];
  }

  void onPageCountChanged(int count) {
    _pageCount = count;
    _maybePreloadUpcomingImages();
    notifyListeners();
  }

  void onColumnCountChanged(int count) {
    _columnCount = count;
  }

  void onBookmarkColumnIndexChanged(Map<String, int> index) {
    _bookmarkColumnIndex = index;
    final chapterChanged = _updateCurrentChapterFromPage();
    _maybePreloadNextChapter();
    if (chapterChanged) {
      notifyListeners();
    }
  }

  void onBookmarkPageCandidatesChanged(Map<String, List<int>> candidates) {
    _bookmarkPageCandidates = candidates;
    _maybePreloadUpcomingImages();
  }

  @override
  void dispose() {
    readerController.pageController.removeListener(_onPageChanged);
    readerController.dispose();
    super.dispose();
  }

  void _onPageChanged() {
    final page = readerController.pageController.page?.round() ?? 0;
    final maxPage = _pageCount > 0 ? _pageCount - 1 : 0;
    final newPage = page.clamp(0, maxPage);
    if (newPage == _currentPage) {
      return;
    }

    _currentPage = newPage;
    _updateCurrentChapterFromPage();
    _maybePreloadNextChapter();
    _maybePreloadUpcomingImages();
    notifyListeners();
  }

  String? _chapterPathForPage(int page) {
    final currentColumn = _pagination.currentAbsoluteColumnForSpread(
      spreadPage: page,
      columnCount: _columnCount,
    );
    return _chapterPathForColumn(currentColumn);
  }

  String? _chapterPathForForwardNavigation(int page) {
    if (_columnCount <= 0) {
      return _loadedChapters.isNotEmpty ? _loadedChapters.first : null;
    }
    final spreadStartColumn = _pagination.currentAbsoluteColumnForSpread(
      spreadPage: page,
      columnCount: _columnCount,
    );
    final spreadEndColumn = (spreadStartColumn + columnsPerPage - 1).clamp(
      0,
      _columnCount - 1,
    );
    return _chapterPathForColumn(spreadEndColumn);
  }

  String? _chapterPathForColumn(int currentColumn) {
    String? resolvedPath;
    var resolvedStart = -1;
    for (final chapterPath in _loadedChapters) {
      final startId = _paths.chapterStartIdForPath(chapterPath);
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

  bool _updateCurrentChapterFromPage() {
    final chapterPath = _chapterPathForPage(_currentPage);
    if (chapterPath == null) {
      return false;
    }
    if (_paths.normalizePath(chapterPath) ==
        _paths.normalizePath(_currentChapterPath)) {
      return false;
    }
    _currentChapterPath = chapterPath;
    return true;
  }

  void _maybePreloadNextChapter() {
    if (_columnCount <= 0 || _isLoadingAdjacentChapter) {
      return;
    }
    final activeChapter =
        _chapterPathForPage(_currentPage) ?? _currentChapterPath;
    final nextChapter = _chapters.nextChapterPath(
      activeChapterPath: activeChapter,
      resolveDocument: _paths.resolveDocument,
    );
    if (nextChapter == null ||
        _chapters.isChapterLoaded(
          loadedChapters: _loadedChapters,
          path: nextChapter,
        )) {
      return;
    }

    final chapterEndColumn = _chapterEndColumn(activeChapter);
    if (chapterEndColumn == null) {
      return;
    }
    final remainingColumnPages =
        chapterEndColumn -
        _pagination.currentAbsoluteColumnForSpread(
          spreadPage: _currentPage,
          columnCount: _columnCount,
        );
    if (remainingColumnPages <= _preloadThresholdColumnPages) {
      unawaited(_ensureChapterLoaded(nextChapter));
    }
  }

  int? _chapterEndColumn(String chapterPath) {
    final chapterOrder = ExampleDemoContent.chapterOrder
        .map(_paths.normalizePath)
        .toList();
    final normalizedCurrent = _paths.normalizePath(
      ExampleDemoContent.canonicalChapterByPath[_paths.normalizePath(
            chapterPath,
          )] ??
          _paths.normalizePath(chapterPath),
    );
    final chapterIndex = chapterOrder.indexOf(normalizedCurrent);
    if (chapterIndex < 0 || chapterIndex >= chapterOrder.length - 1) {
      return _columnCount > 0 ? _columnCount - 1 : null;
    }
    final nextCanonical = chapterOrder[chapterIndex + 1];
    final nextChapterPath = _paths.resolveDocument(nextCanonical);
    if (nextChapterPath == null ||
        !_chapters.isChapterLoaded(
          loadedChapters: _loadedChapters,
          path: nextChapterPath,
        )) {
      return _columnCount > 0 ? _columnCount - 1 : null;
    }
    final nextStartId = _paths.chapterStartIdForPath(nextChapterPath);
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
    final resolved = _paths.resolveDocument(chapterPath);
    if (resolved == null ||
        _chapters.isChapterLoaded(
          loadedChapters: _loadedChapters,
          path: resolved,
        )) {
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

    _loadedChapters.add(resolved);
    notifyListeners();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (preserveCurrentPosition) {
        readerController.pageController.jumpToPage(previousPage);
      }
      _isLoadingAdjacentChapter = false;
      _chapterLoadCompleter = null;
      _maybePreloadNextChapter();
      _maybePreloadUpcomingImages();
      loadCompleter.complete();
    });

    await loadCompleter.future;
  }

  int _chapterStartColumn(String chapterPath) {
    final startId = _paths.chapterStartIdForPath(chapterPath);
    if (startId == null) {
      return 0;
    }
    return _bookmarkColumnIndex[startId] ?? 0;
  }

  int? _resolvePageInChapterForFragment({
    required String chapterPath,
    required String fragmentId,
  }) {
    final startColumn = _chapterStartColumn(chapterPath);
    final endColumn = _chapterEndColumn(chapterPath) ?? (_columnCount - 1);
    return _pagination.resolvePageInChapterForFragment(
      candidates: _bookmarkPageCandidates[fragmentId],
      chapterStartColumn: startColumn,
      chapterEndColumn: endColumn,
    );
  }

  Future<bool> _resolveAndNavigateCfi(HtmlReference reference) async {
    final candidates = _cfiParser.parseCandidateIds(reference.raw);
    if (candidates.isEmpty) {
      return false;
    }

    for (final id in candidates.reversed) {
      final jumped = await readerController.animateToReference(id);
      if (jumped) {
        return true;
      }
    }
    return false;
  }

  void _maybePreloadUpcomingImages() {
    if (_pageCount <= 0 || _columnCount <= 0) {
      return;
    }
    final maxPreloadPage = (_currentPage + _imagePreloadThresholdPages).clamp(
      0,
      _pageCount - 1,
    );

    for (final chapterPath in _loadedChapters) {
      final chapterStartPage =
          _chapterStartColumn(chapterPath) ~/ columnsPerPage;
      final chapterEndPage =
          (_chapterEndColumn(chapterPath) ?? (_columnCount - 1)) ~/
          columnsPerPage;
      final chapterIsNear =
          chapterStartPage <= maxPreloadPage && chapterEndPage >= _currentPage;
      if (!chapterIsNear) {
        continue;
      }

      final imageRefs = _imageRefsForChapter(chapterPath);
      for (final imageRef in imageRefs) {
        final imageId = imageRef.id?.trim();
        if (imageId != null && imageId.isNotEmpty) {
          final candidatePages = _bookmarkPageCandidates[imageId];
          if (candidatePages != null && candidatePages.isNotEmpty) {
            final inPreloadWindow = candidatePages.any(
              (page) => page >= _currentPage && page <= maxPreloadPage,
            );
            if (!inPreloadWindow) {
              continue;
            }
          }
        }
        unawaited(resolveImageBytes(imageRef.src, imageRef.alt));
      }
    }
  }

  List<HtmlImageRef> _imageRefsForChapter(String chapterPath) {
    final resolvedPath = _paths.resolveDocument(chapterPath) ?? chapterPath;
    final cacheKey = _paths.normalizePath(resolvedPath);
    return _chapterImageRefs.putIfAbsent(cacheKey, () {
      final chapterHtml = ExampleDemoContent.documents[resolvedPath] ?? '';
      if (chapterHtml.isEmpty) {
        return const <HtmlImageRef>[];
      }
      final blocks = _htmlParser.parse(
        chapterHtml,
        externalCss: ExampleDemoContent
            .externalCssByChapterPath[_paths.canonicalPath(resolvedPath)],
        externalCssResolver: resolveExternalCss,
      );
      return List<HtmlImageRef>.unmodifiable(
        blocks.whereType<HtmlImageBlockNode>().map(HtmlImageRef.fromNode),
      );
    });
  }
}
