import 'dart:async';
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

  static const int _maxFetchAttempts = 4;
  static const Duration _minRequestInterval = Duration(milliseconds: 350);
  static const Duration _loadTimeout = Duration(seconds: 25);
  static const String _browserLikeUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36';
  DateTime? _lastRequestAt;

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
    final html = await _fetchText(uri);
    final linkedCss = await _loadLinkedCss(uri, html);
    return BrowserPageLoadResult(uri: uri, html: html, linkedCss: linkedCss);
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
    final hrefs = _extractStylesheetHrefs(html);
    final cssByHref = <String, String>{};
    for (final href in hrefs) {
      try {
        final cssUri = normalizeAddress(href, base: pageUri);
        final css = await _fetchText(
          cssUri,
          referer: pageUri,
          expectPlainText: true,
        );
        cssByHref[href] = css;
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
      final rel = _extractAttribute(tag, 'rel')?.toLowerCase() ?? '';
      if (!rel.contains('stylesheet')) {
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
}

class _BrowserFetchHttpException implements Exception {
  const _BrowserFetchHttpException(this.statusCode, {this.retryAfter});

  final int statusCode;
  final Duration? retryAfter;
}
