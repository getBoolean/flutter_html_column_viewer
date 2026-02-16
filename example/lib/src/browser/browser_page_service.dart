import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class BrowserPageLoadResult {
  const BrowserPageLoadResult({
    required this.uri,
    required this.html,
    required this.linkedCss,
  });

  final Uri uri;
  final String html;
  final Map<String, String> linkedCss;
}

class BrowserPageService {
  BrowserPageService();

  static const int _cacheSchemaVersion = 3;
  static const int _maxFetchAttempts = 4;
  static const Duration _minRequestInterval = Duration(milliseconds: 350);
  static const Duration _loadTimeout = Duration(seconds: 25);
  static const String _browserLikeUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36';
  DateTime? _lastRequestAt;
  bool _cacheLoaded = false;
  final Map<String, _CachedPageData> _cache = <String, _CachedPageData>{};

  void dispose() {}

  Uri normalizeAddress(String input, {Uri? base}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Address is empty');
    }
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null) {
      throw FormatException('Invalid address: $input');
    }
    if (parsed.hasScheme) {
      return parsed;
    }
    if (base != null) {
      return base.resolveUri(parsed);
    }
    return Uri.parse('https://$trimmed');
  }

  Future<BrowserPageLoadResult> load(Uri uri) async {
    await _ensureCacheLoaded();
    final cacheKey = uri.toString();
    final cached = _cache[cacheKey];
    if (cached != null) {
      return BrowserPageLoadResult(
        uri: uri,
        html: cached.html,
        linkedCss: cached.linkedCss,
      );
    }

    final html = await _fetchText(uri);
    final linkedCss = await _loadLinkedCss(uri, html);
    _cache[cacheKey] = _CachedPageData(html: html, linkedCss: linkedCss);
    await _persistCache();
    return BrowserPageLoadResult(uri: uri, html: html, linkedCss: linkedCss);
  }

  Future<void> clearCache(Uri uri) async {
    await _ensureCacheLoaded();
    _cache.remove(uri.toString());
    await _persistCache();
  }

  Future<String> _fetchText(
    Uri uri, {
    Uri? referer,
    bool expectPlainText = false,
  }) async {
    Exception? lastError;
    for (var attempt = 1; attempt <= _maxFetchAttempts; attempt++) {
      try {
        return await _fetchViaHeadlessWebView(
          uri,
          referer: referer,
          expectPlainText: expectPlainText,
        );
      } on _BrowserFetchHttpException catch (error) {
        lastError = error;
        final retryable =
            error.statusCode == 429 ||
            (error.statusCode >= 500 && error.statusCode <= 599);
        if (!retryable || attempt == _maxFetchAttempts) {
          break;
        }
        await Future<void>.delayed(
          error.retryAfter ?? Duration(seconds: attempt),
        );
      } on TimeoutException catch (error) {
        lastError = error;
        if (attempt == _maxFetchAttempts) {
          break;
        }
        await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
      } on Exception catch (error) {
        lastError = error;
        if (attempt == _maxFetchAttempts) {
          break;
        }
        await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
      }
    }

    if (lastError case final _BrowserFetchHttpException httpError) {
      throw HttpException('HTTP ${httpError.statusCode}', uri: uri);
    }
    throw HttpException('${lastError ?? 'Request failed'}', uri: uri);
  }

  Future<Map<String, String>> _loadLinkedCss(Uri pageUri, String html) async {
    final cssByHref = <String, String>{};
    final pending = <_PendingCssRequest>[
      for (final href in _extractStylesheetHrefs(html))
        _PendingCssRequest(href: href, baseUri: pageUri),
      for (final href in _extractInlineStyleImportHrefs(html))
        _PendingCssRequest(href: href, baseUri: pageUri),
    ];
    final requested = <Uri>{};

    while (pending.isNotEmpty) {
      final request = pending.removeAt(0);
      final href = request.href;
      try {
        final cssUri = normalizeAddress(href, base: request.baseUri);
        if (!requested.add(cssUri)) {
          continue;
        }
        final css = await _fetchText(
          cssUri,
          referer: request.baseUri,
          expectPlainText: true,
        );
        // Keep both textual href and absolute URI aliases available.
        cssByHref[href] = css;
        cssByHref[cssUri.toString()] = css;
        for (final importedHref in _extractLeadingImportHrefs(css)) {
          pending.add(_PendingCssRequest(href: importedHref, baseUri: cssUri));
        }
      } catch (_) {
        // Keep rendering even when linked stylesheets fail to load.
      }
    }
    return cssByHref;
  }

  Set<String> _extractStylesheetHrefs(String html) {
    final out = <String>{};
    final linkTagRegex = RegExp(r'<link\b[^>]*>', caseSensitive: false);
    for (final tagMatch in linkTagRegex.allMatches(html)) {
      final tag = tagMatch.group(0);
      if (tag == null) {
        continue;
      }
      final rel = _extractAttribute(tag, 'rel');
      if (!_isPreferredStylesheetRel(rel)) {
        continue;
      }
      final href = _extractAttribute(tag, 'href')?.trim();
      if (href == null || href.isEmpty || href.startsWith('data:')) {
        continue;
      }
      out.add(href);
    }
    return out;
  }

  String? _extractAttribute(String tag, String attribute) {
    final regex = RegExp(
      '$attribute\\s*=\\s*(["\'])(.*?)\\1',
      caseSensitive: false,
      dotAll: true,
    );
    final match = regex.firstMatch(tag);
    return match?.group(2);
  }

  bool _isPreferredStylesheetRel(String? relRaw) {
    final rel = relRaw?.trim().toLowerCase();
    if (rel == null || rel.isEmpty) {
      return false;
    }
    final relTokens = rel.split(RegExp(r'\s+'));
    return relTokens.contains('stylesheet') &&
        !relTokens.contains('alternate');
  }

  Set<String> _extractInlineStyleImportHrefs(String html) {
    final out = <String>{};
    final styleTagRegex = RegExp(
      r'<style\b[^>]*>(.*?)</style>',
      caseSensitive: false,
      dotAll: true,
    );
    for (final styleMatch in styleTagRegex.allMatches(html)) {
      final css = styleMatch.group(1);
      if (css == null || css.trim().isEmpty) {
        continue;
      }
      out.addAll(_extractLeadingImportHrefs(css));
    }
    return out;
  }

  Set<String> _extractLeadingImportHrefs(String css) {
    final out = <String>{};
    var offset = 0;
    while (offset < css.length) {
      offset = _skipCssWhitespaceAndComments(css, offset);
      if (offset >= css.length) {
        break;
      }
      if (_startsWithIgnoreCase(css, offset, '@charset')) {
        final statementEnd = css.indexOf(';', offset);
        if (statementEnd < 0) {
          break;
        }
        offset = statementEnd + 1;
        continue;
      }
      if (!_startsWithIgnoreCase(css, offset, '@import')) {
        break;
      }
      final statementEnd = css.indexOf(';', offset);
      if (statementEnd < 0) {
        break;
      }
      final statement = css.substring(offset, statementEnd + 1);
      final href = _extractImportHref(statement);
      if (href != null && href.isNotEmpty) {
        out.add(href);
      }
      offset = statementEnd + 1;
    }
    return out;
  }

  int _skipCssWhitespaceAndComments(String css, int start) {
    var offset = start;
    while (offset < css.length) {
      if (offset + 4 <= css.length && css.substring(offset, offset + 4) == '<!--') {
        offset += 4;
        continue;
      }
      if (offset + 3 <= css.length && css.substring(offset, offset + 3) == '-->') {
        offset += 3;
        continue;
      }
      final current = css.codeUnitAt(offset);
      if (current == 0x2f &&
          offset + 1 < css.length &&
          css.codeUnitAt(offset + 1) == 0x2a) {
        final commentEnd = css.indexOf('*/', offset + 2);
        if (commentEnd < 0) {
          return css.length;
        }
        offset = commentEnd + 2;
        continue;
      }
      if (current == 0x20 ||
          current == 0x09 ||
          current == 0x0a ||
          current == 0x0d ||
          current == 0x0c) {
        offset += 1;
        continue;
      }
      break;
    }
    return offset;
  }

  bool _startsWithIgnoreCase(String text, int offset, String needle) {
    if (offset + needle.length > text.length) {
      return false;
    }
    final segment = text.substring(offset, offset + needle.length);
    return segment.toLowerCase() == needle.toLowerCase();
  }

  String? _extractImportHref(String importStatement) {
    final urlMatch = RegExp(
      '@import\\s+url\\(\\s*(["\\\']?)([^)"\\\']+)\\1\\s*\\)',
      caseSensitive: false,
    ).firstMatch(importStatement);
    if (urlMatch != null) {
      return urlMatch.group(2)?.trim();
    }

    final quotedMatch = RegExp(
      '@import\\s+(["\\\'])([^"\\\']+)\\1',
      caseSensitive: false,
    ).firstMatch(importStatement);
    return quotedMatch?.group(2)?.trim();
  }

  Future<void> _waitForRequestSlot() async {
    final last = _lastRequestAt;
    if (last != null) {
      final elapsed = DateTime.now().difference(last);
      if (elapsed < _minRequestInterval) {
        await Future<void>.delayed(_minRequestInterval - elapsed);
      }
    }
    _lastRequestAt = DateTime.now();
  }

  Duration? _parseRetryAfterValue(String? rawValue) {
    final raw = rawValue?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final seconds = int.tryParse(raw);
    if (seconds != null && seconds >= 0) {
      return Duration(seconds: seconds);
    }
    DateTime retryDate;
    try {
      retryDate = HttpDate.parse(raw);
    } on FormatException {
      return null;
    }
    final delta = retryDate.difference(DateTime.now().toUtc());
    if (delta.isNegative) {
      return Duration.zero;
    }
    return delta;
  }

  Future<String> _fetchViaHeadlessWebView(
    Uri uri, {
    Uri? referer,
    required bool expectPlainText,
  }) async {
    await _waitForRequestSlot();
    final completer = Completer<String>();
    _BrowserFetchHttpException? httpException;

    final headers = <String, String>{
      'User-Agent': _browserLikeUserAgent,
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,'
          'image/webp,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
      'Upgrade-Insecure-Requests': '1',
    };
    if (referer != null) {
      headers['Referer'] = referer.toString();
    }

    final webView = HeadlessInAppWebView(
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        userAgent: _browserLikeUserAgent,
      ),
      initialUrlRequest: URLRequest(url: WebUri.uri(uri), headers: headers),
      onReceivedHttpError: (controller, request, response) async {
        final status = response.statusCode;
        if (status != null && status >= 400) {
          httpException = _BrowserFetchHttpException(
            status,
            retryAfter: _parseRetryAfterValue(
              _findHeaderIgnoreCase(response.headers, 'retry-after'),
            ),
          );
        }
      },
      onReceivedError: (controller, request, error) async {
        if (completer.isCompleted) {
          return;
        }
        completer.completeError(
          HttpException(
            'WebView load error (${error.type.name}): ${error.description}',
            uri: uri,
          ),
        );
      },
      onLoadStop: (controller, _) async {
        if (completer.isCompleted) {
          return;
        }
        if (httpException != null) {
          completer.completeError(httpException!);
          return;
        }

        try {
          final result = expectPlainText
              ? await controller.evaluateJavascript(
                  source:
                      'document.body ? document.body.innerText : document.documentElement.outerHTML;',
                )
              : await controller.getHtml();
          final text = '${result ?? ''}'.trim();
          if (text.isEmpty) {
            completer.completeError(
              HttpException('Empty response body', uri: uri),
            );
            return;
          }
          completer.complete(text);
        } catch (error) {
          completer.completeError(
            HttpException('Unable to extract content: $error', uri: uri),
          );
        }
      },
    );

    await webView.run();
    try {
      return await completer.future.timeout(_loadTimeout);
    } finally {
      await webView.dispose();
    }
  }

  String? _findHeaderIgnoreCase(Map<String, String>? headers, String key) {
    if (headers == null || headers.isEmpty) {
      return null;
    }
    final target = key.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == target) {
        return entry.value;
      }
    }
    return null;
  }

  Future<void> _ensureCacheLoaded() async {
    if (_cacheLoaded) {
      return;
    }
    _cacheLoaded = true;
    try {
      final file = await _cacheFile();
      if (!await file.exists()) {
        return;
      }
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      final version = decoded['version'];
      final pagesRaw = decoded['pages'];
      if (version != _cacheSchemaVersion || pagesRaw is! Map<String, dynamic>) {
        return;
      }
      for (final entry in pagesRaw.entries) {
        final value = entry.value;
        if (value is! Map<String, dynamic>) {
          continue;
        }
        final html = value['html'];
        final linkedCssRaw = value['linkedCss'];
        if (html is! String || linkedCssRaw is! Map) {
          continue;
        }
        final linkedCss = <String, String>{};
        for (final cssEntry in linkedCssRaw.entries) {
          final key = '${cssEntry.key}';
          final css = cssEntry.value;
          if (css is String) {
            linkedCss[key] = css;
          }
        }
        _cache[entry.key] = _CachedPageData(html: html, linkedCss: linkedCss);
      }
    } catch (_) {
      _cache.clear();
    }
  }

  Future<void> _persistCache() async {
    final file = await _cacheFile();
    final encoded = <String, Object?>{
      'version': _cacheSchemaVersion,
      'pages': <String, Object?>{
        for (final entry in _cache.entries)
          entry.key: <String, Object?>{
            'html': entry.value.html,
            'linkedCss': entry.value.linkedCss,
          },
        },
      };
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(encoded), flush: true);
  }

  Future<File> _cacheFile() async {
    final root = Directory(
      '${Directory.systemTemp.path}/flutter_html_browser_cache',
    );
    return File('${root.path}/page_cache.json');
  }
}

class _BrowserFetchHttpException implements Exception {
  const _BrowserFetchHttpException(this.statusCode, {this.retryAfter});

  final int statusCode;
  final Duration? retryAfter;
}

class _CachedPageData {
  const _CachedPageData({required this.html, required this.linkedCss});

  final String html;
  final Map<String, String> linkedCss;
}

class _PendingCssRequest {
  const _PendingCssRequest({required this.href, required this.baseUri});

  final String href;
  final Uri baseUri;
}
