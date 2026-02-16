import 'package:flutter/material.dart';

import '../spec/html/model/html_nodes.dart';

/// Controller for programmatic navigation in [HtmlColumnReader].
///
/// Besides page navigation, it also tracks the latest bookmark index
/// (`id -> pageIndex`) so callers can jump directly to a same-document
/// HTML reference such as `#section3`.
class HtmlReaderController {
  HtmlReaderController({PageController? pageController})
    : pageController = pageController ?? PageController();

  final PageController pageController;

  Map<String, int> _bookmarkIndex = const <String, int>{};
  int _pageCount = 0;
  String? _pendingBookmarkId;

  Map<String, int> get bookmarkIndex => _bookmarkIndex;

  int get pageCount => _pageCount;

  /// Internal package hook: updates page and bookmark layout metadata.
  void updateLayoutData({
    required int pageCount,
    required Map<String, int> bookmarkIndex,
  }) {
    _pageCount = pageCount;
    _bookmarkIndex = bookmarkIndex;
    final pending = _pendingBookmarkId;
    if (pending != null) {
      _pendingBookmarkId = null;
      jumpToReference(pending);
    }
  }

  /// Jumps to a same-document reference id (for example: `#section3` or `section3`).
  ///
  /// Returns true if a page jump was scheduled/applied, false otherwise.
  bool jumpToReference(String reference) {
    final bookmarkId = _extractBookmarkId(reference);
    if (bookmarkId == null) {
      return false;
    }
    final page = _bookmarkIndex[bookmarkId];
    if (page == null) {
      _pendingBookmarkId = bookmarkId;
      return false;
    }
    final clamped = _clampPage(page);
    pageController.jumpToPage(clamped);
    return true;
  }

  /// Animates to a same-document reference id.
  Future<bool> animateToReference(
    String reference, {
    Duration duration = const Duration(milliseconds: 280),
    Curve curve = Curves.easeInOut,
  }) async {
    final bookmarkId = _extractBookmarkId(reference);
    if (bookmarkId == null) {
      return false;
    }
    final page = _bookmarkIndex[bookmarkId];
    if (page == null) {
      _pendingBookmarkId = bookmarkId;
      return false;
    }
    final clamped = _clampPage(page);
    await pageController.animateToPage(
      clamped,
      duration: duration,
      curve: curve,
    );
    return true;
  }

  /// Jumps to the fragment in [reference] when available.
  bool jumpToHtmlReference(HtmlReference reference) {
    final fragment = reference.fragmentId;
    if (fragment == null || fragment.isEmpty) {
      return false;
    }
    return jumpToReference(fragment);
  }

  int _clampPage(int page) {
    if (_pageCount <= 0) {
      return 0;
    }
    return page.clamp(0, _pageCount - 1);
  }

  String? _extractBookmarkId(String input) {
    final value = input.trim();
    if (value.isEmpty) {
      return null;
    }
    final hashIndex = value.indexOf('#');
    final candidate = hashIndex >= 0 ? value.substring(hashIndex + 1) : value;
    final trimmed = candidate.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase().startsWith('epubcfi(')) {
      return null;
    }
    return trimmed;
  }

  void dispose() {
    pageController.dispose();
  }
}
