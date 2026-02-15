import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_html_column_viewer/flutter_html_column_viewer.dart';
import 'package:url_launcher/url_launcher.dart';

import 'example_demo_content.dart';

class ChapterPagination {
  const ChapterPagination({required this.current, required this.total});

  final int current;
  final int total;
}

class ExampleImageData {
  const ExampleImageData({
    required this.src,
    required this.alt,
    required this.isRemote,
    required this.resolvedEpubPath,
    required this.effectiveUrl,
  });

  final String src;
  final String? alt;
  final bool isRemote;
  final String? resolvedEpubPath;
  final String? effectiveUrl;
}

class ExampleReaderService extends ChangeNotifier {
  ExampleReaderService() {
    readerController.pageController.addListener(_onPageChanged);
  }

  final HtmlReaderController readerController = HtmlReaderController();
  final EpubCfiParser _cfiParser = const EpubCfiParser();

  static const int columnsPerPage = 2;
  static const int _preloadThresholdColumnPages = 2;

  String _currentDocumentPath = ExampleDemoContent.initialDocumentPath;
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
  bool _pendingAdvanceAfterChapterLoad = false;

  String get currentDocumentPath => _currentDocumentPath;
  int get currentPage => _currentPage;
  int get pageCount => _pageCount;
  bool get canGoPrevious => _currentPage > 0;
  bool get canGoNext =>
      _pageCount > 0 &&
      (_currentPage < _pageCount - 1 || _nextChapterPath() != null);

  String get currentHtml => _loadedChapters
      .map((path) => ExampleDemoContent.documents[path] ?? '')
      .join('\n<column-break></column-break>\n');

  ChapterPagination? get chapterPagination => _currentChapterColumnPagination();

  void onPreviousPagePressed() {
    if (_currentPage <= 0) {
      return;
    }
    readerController.pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void onNextPagePressed() {
    if (_currentPage < _pageCount - 1) {
      readerController.pageController.nextPage(
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

  Future<String?> handleReferenceTap(HtmlReference reference) async {
    final targetDocument = _resolveDocument(reference.path);
    final hasExplicitPath =
        reference.path != null && reference.path!.trim().isNotEmpty;
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
          await readerController.pageController.animateToPage(
            resolvedTargetPage,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          return null;
        }
        final jumped = await readerController.animateToReference(
          targetFragment,
        );
        if (!jumped) {
          readerController.jumpToReference(targetFragment);
        }
      }
      return null;
    }

    if (reference.fragmentId != null && reference.fragmentId!.isNotEmpty) {
      await readerController.animateToReference(reference.fragmentId!);
      return null;
    }

    if (reference.isCfiLike) {
      final resolved = await _resolveAndNavigateCfi(reference);
      if (resolved) {
        return null;
      }
      return 'Unable to resolve CFI target from: ${reference.raw}';
    }

    final uri = reference.uri;
    if (uri != null && uri.hasScheme) {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) {
        return null;
      }
      return 'Unable to open URL: $uri';
    }

    return 'Unhandled reference: ${reference.raw}';
  }

  ExampleImageData resolveImage(String src, String? alt) {
    final imageUri = Uri.tryParse(src.trim());
    final isRemote =
        imageUri != null &&
        (imageUri.scheme == 'http' || imageUri.scheme == 'https');
    final resolvedEpubPath = _resolveEpubImagePath(src);
    final mappedRemoteUrl = resolvedEpubPath == null
        ? null
        : ExampleDemoContent.epubImageUrlByPath[_normalizePath(
            resolvedEpubPath,
          )];
    final effectiveUrl = isRemote ? src : mappedRemoteUrl;

    return ExampleImageData(
      src: src,
      alt: alt,
      isRemote: isRemote,
      resolvedEpubPath: resolvedEpubPath,
      effectiveUrl: effectiveUrl,
    );
  }

  void onPageCountChanged(int count) {
    _pageCount = count;
    if (_pendingAdvanceAfterChapterLoad &&
        count > 0 &&
        _currentPage < count - 1) {
      _pendingAdvanceAfterChapterLoad = false;
      readerController.pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
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
    notifyListeners();
  }

  String? _resolveDocument(String? rawPath) {
    if (rawPath == null || rawPath.isEmpty) {
      return null;
    }
    final normalized = _canonicalPath(rawPath);
    if (ExampleDemoContent.documents.containsKey(normalized)) {
      return normalized;
    }
    for (final key in ExampleDemoContent.documents.keys) {
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
        ExampleDemoContent.canonicalChapterByPath[normalizedCurrentPath] ??
        normalizedCurrentPath;
    final normalizedOrder = ExampleDemoContent.chapterOrder.map(_normalizePath);
    final chapterOrder = normalizedOrder.toList();
    final currentIndex = chapterOrder.indexOf(canonicalCurrentPath);
    if (currentIndex == -1 || currentIndex >= chapterOrder.length - 1) {
      return null;
    }

    final nextCanonicalPath = chapterOrder[currentIndex + 1];
    return _resolveDocument(nextCanonicalPath);
  }

  String? _chapterStartIdForPath(String path) {
    final canonical = _canonicalPath(path);
    return ExampleDemoContent.chapterStartIdByPath[canonical];
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

  bool _updateCurrentChapterFromPage() {
    final chapterPath = _chapterPathForPage(_currentPage);
    if (chapterPath == null) {
      return false;
    }
    if (_normalizePath(chapterPath) == _normalizePath(_currentDocumentPath)) {
      return false;
    }
    _currentDocumentPath = chapterPath;
    return true;
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
    final normalizedOrder = ExampleDemoContent.chapterOrder.map(_normalizePath);
    final chapterOrder = normalizedOrder.toList();
    final normalizedCurrent = _normalizePath(
      ExampleDemoContent.canonicalChapterByPath[_normalizePath(chapterPath)] ??
          _normalizePath(chapterPath),
    );
    final chapterIndex = chapterOrder.indexOf(normalizedCurrent);
    if (chapterIndex < 0 || chapterIndex >= chapterOrder.length - 1) {
      return _columnCount > 0 ? _columnCount - 1 : null;
    }
    final nextCanonical = chapterOrder[chapterIndex + 1];
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

    _loadedChapters.add(resolved);
    notifyListeners();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (preserveCurrentPosition) {
        readerController.pageController.jumpToPage(previousPage);
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
    final startPage = startColumn ~/ columnsPerPage;
    final endPage = endColumn ~/ columnsPerPage;
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
    final absolute = spreadPage * columnsPerPage;
    return absolute.clamp(0, _columnCount - 1);
  }

  ChapterPagination? _currentChapterColumnPagination() {
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
    return ChapterPagination(
      current: currentColumnPage,
      total: totalColumnPages,
    );
  }

  String _normalizePath(String value) => value.trim().toLowerCase();

  String _canonicalPath(String value) {
    final normalized = _normalizePath(value);
    return ExampleDemoContent.canonicalChapterByPath[normalized] ?? normalized;
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
}
