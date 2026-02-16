import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

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
  BrowserPageService({HttpClient? client})
    : _client = client ?? HttpClient()
        ..userAgent = 'flutter-html-browser-example';

  final HttpClient _client;

  void dispose() {
    _client.close(force: true);
  }

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

  Future<String> _fetchText(Uri uri) async {
    final request = await _client.getUrl(uri);
    request.followRedirects = true;
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode > 299) {
      throw HttpException('HTTP ${response.statusCode}', uri: uri);
    }
    final bytes = await consolidateHttpClientResponseBytes(response);
    return utf8.decode(bytes, allowMalformed: true);
  }

  Future<Map<String, String>> _loadLinkedCss(Uri pageUri, String html) async {
    final hrefs = _extractStylesheetHrefs(html);
    final cssByHref = <String, String>{};
    for (final href in hrefs) {
      try {
        final cssUri = normalizeAddress(href, base: pageUri);
        final css = await _fetchText(cssUri);
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
}
