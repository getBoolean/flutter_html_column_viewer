import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_html_column_viewer/flutter_html_column_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

const String _css1SuiteIndex =
    'https://www.w3.org/Style/CSS/Test/CSS1/current/index.html';
const String _suiteHost = 'www.w3.org';
const String _suitePathPrefix = '/Style/CSS/Test/CSS1/current/';
const int _maxPagesToVisit = 2000;

/// Set RUN_CSS1_TEST_SUITE=1 to run this network-backed test locally/CI.
bool get _isEnabled =>
    true; //Platform.environment['RUN_CSS1_TEST_SUITE'] == '1';

void main() {
  group('W3C CSS1 test suite corpus', () {
    test(
      'parses every HTML page in the CSS1 suite without throwing',
      () async {
        final parser = HtmlContentParser();
        final crawler = _Css1Crawler();
        final pages = await crawler.discoverHtmlPages(
          indexUrl: Uri.parse(_css1SuiteIndex),
        );

        expect(
          pages,
          isNotEmpty,
          reason: 'No CSS1 suite pages discovered from $_css1SuiteIndex',
        );

        final failures = <String>[];
        for (final page in pages) {
          try {
            final html = await crawler.fetchUtf8(page);
            parser.parse(html);
          } catch (error, stackTrace) {
            failures.add('$page\n$error\n$stackTrace');
          }
        }

        expect(
          failures,
          isEmpty,
          reason: 'Failed pages:\n${failures.join('\n\n-----\n\n')}',
        );
      },
      skip: _isEnabled ? null : 'Set RUN_CSS1_TEST_SUITE=1 to enable',
    );
  });
}

class _Css1Crawler {
  _Css1Crawler({HttpClient? client})
    : _client = client ?? HttpClient()
        ..userAgent = 'flutter-html-column-viewer-tests';

  final HttpClient _client;

  Future<List<Uri>> discoverHtmlPages({required Uri indexUrl}) async {
    final seen = <String>{};
    final queue = Queue<Uri>()..add(_normalize(indexUrl));
    final htmlPages = <Uri>[];

    while (queue.isNotEmpty && seen.length < _maxPagesToVisit) {
      final current = queue.removeFirst();
      final key = current.toString();
      if (!seen.add(key)) {
        continue;
      }

      final content = await fetchUtf8(current);
      htmlPages.add(current);

      for (final discovered in _extractLinks(content, current)) {
        if (!seen.contains(discovered.toString())) {
          queue.add(discovered);
        }
      }
    }

    htmlPages.sort((a, b) => a.toString().compareTo(b.toString()));
    return htmlPages;
  }

  Future<String> fetchUtf8(Uri url) async {
    final request = await _client.getUrl(url);
    request.followRedirects = true;
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode > 299) {
      throw HttpException('HTTP ${response.statusCode} for $url');
    }

    final bytes = await consolidateHttpClientResponseBytes(response);
    return utf8.decode(bytes, allowMalformed: true);
  }

  List<Uri> _extractLinks(String html, Uri baseUri) {
    final links = <Uri>[];
    final hrefRegex = RegExp(
      r'''href\s*=\s*(['"])([^'"#?]+)\1''',
      caseSensitive: false,
    );

    for (final match in hrefRegex.allMatches(html)) {
      final rawHref = match.group(2);
      if (rawHref == null || rawHref.isEmpty) {
        continue;
      }

      final resolved = _normalize(baseUri.resolve(rawHref));
      if (_isCss1SuiteHtml(resolved)) {
        links.add(resolved);
      }
    }

    return links;
  }

  bool _isCss1SuiteHtml(Uri uri) {
    if (uri.scheme != 'https') {
      return false;
    }
    if (uri.host != _suiteHost) {
      return false;
    }
    if (!uri.path.startsWith(_suitePathPrefix)) {
      return false;
    }
    return uri.path.toLowerCase().endsWith('.html');
  }

  Uri _normalize(Uri uri) {
    return uri.replace(fragment: '', query: '');
  }
}
