import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_html_column_viewer/flutter_html_column_viewer.dart';

import 'browser_page_service.dart';

class BrowserController extends ChangeNotifier {
  BrowserController({required BrowserPageService pageService})
    : _pageService = pageService;

  final BrowserPageService _pageService;
  final HtmlReaderController readerController = HtmlReaderController();
  final TextEditingController addressController = TextEditingController();

  bool _loading = false;
  String? _error;
  String _html = '';
  Uri? _currentUri;
  Map<String, String> _linkedCss = const <String, String>{};
  final List<Uri> _history = <Uri>[];
  int _historyIndex = -1;

  bool get loading => _loading;
  String? get error => _error;
  String get html => _html;
  Uri? get currentUri => _currentUri;
  bool get canGoBack => _historyIndex > 0;
  bool get canGoForward =>
      _historyIndex >= 0 && _historyIndex < _history.length - 1;

  String? resolveExternalCss(String href) => _linkedCss[href];

  Future<void> openInitial(String address) async {
    if (_currentUri != null || _loading) {
      return;
    }
    addressController.text = address;
    await openAddress(address);
  }

  Future<void> openAddressBarInput() async {
    await openAddress(addressController.text);
  }

  Future<void> openAddress(String input) async {
    Uri uri;
    try {
      uri = _pageService.normalizeAddress(input, base: _currentUri);
    } on FormatException catch (error) {
      _setError(error.message);
      return;
    }
    await _load(uri, addToHistory: true);
  }

  Future<void> reload() async {
    final uri = _currentUri;
    if (uri == null) {
      return;
    }
    await _load(uri, addToHistory: false);
  }

  Future<void> goBack() async {
    if (!canGoBack) {
      return;
    }
    _historyIndex -= 1;
    await _load(_history[_historyIndex], addToHistory: false);
  }

  Future<void> goForward() async {
    if (!canGoForward) {
      return;
    }
    _historyIndex += 1;
    await _load(_history[_historyIndex], addToHistory: false);
  }

  Future<String?> openReference(HtmlReference reference) async {
    final raw = reference.raw.trim();
    if (raw.isEmpty) {
      return null;
    }

    if (raw.startsWith('#')) {
      final fragment = reference.fragmentId;
      if (fragment == null || fragment.isEmpty) {
        return null;
      }
      await readerController.animateToReference(fragment);
      return null;
    }

    final base = _currentUri;
    if (base == null) {
      return 'No page is currently loaded.';
    }

    final targetUri = _pageService.normalizeAddress(raw, base: base);
    final scheme = targetUri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return 'Unsupported link scheme in browser example: $scheme';
    }

    final fragment = targetUri.fragment.isNotEmpty ? targetUri.fragment : null;
    final requestUri = targetUri.replace(fragment: '');
    await _load(requestUri, addToHistory: true);
    if (fragment != null && fragment.isNotEmpty) {
      unawaited(
        Future<void>.delayed(
          const Duration(milliseconds: 30),
        ).then((_) => readerController.animateToReference(fragment)),
      );
    }
    return null;
  }

  Uri? resolveImageUri(String rawSrc) {
    final trimmed = rawSrc.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final base = _currentUri;
    try {
      return _pageService.normalizeAddress(trimmed, base: base);
    } on FormatException {
      return null;
    }
  }

  Future<void> _load(Uri uri, {required bool addToHistory}) async {
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      _setError('Only http/https URLs are supported in this example app.');
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final page = await _pageService.load(uri);
      _currentUri = page.uri;
      _html = page.html;
      _linkedCss = page.linkedCss;
      addressController.text = page.uri.toString();
      if (addToHistory) {
        _recordHistory(page.uri);
      }
    } catch (error) {
      _setError('Failed to load $uri: $error', notify: false);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _recordHistory(Uri uri) {
    if (_historyIndex >= 0 && _history[_historyIndex] == uri) {
      return;
    }
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(uri);
    _historyIndex = _history.length - 1;
  }

  void _setError(String message, {bool notify = true}) {
    _error = message;
    if (notify) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    addressController.dispose();
    readerController.dispose();
    _pageService.dispose();
    super.dispose();
  }
}
