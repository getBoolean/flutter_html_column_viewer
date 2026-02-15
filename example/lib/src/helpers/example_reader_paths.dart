import 'example_demo_content.dart';

class ExampleReaderPaths {
  const ExampleReaderPaths();

  String normalizePath(String value) => value.trim().toLowerCase();

  String canonicalPath(String value) {
    final normalized = normalizePath(value);
    return ExampleDemoContent.canonicalChapterByPath[normalized] ?? normalized;
  }

  String? resolveDocument(String? rawPath) {
    if (rawPath == null || rawPath.isEmpty) {
      return null;
    }

    final normalized = canonicalPath(rawPath);
    if (ExampleDemoContent.documents.containsKey(normalized)) {
      return normalized;
    }
    for (final key in ExampleDemoContent.documents.keys) {
      if (canonicalPath(key) == normalized) {
        return key;
      }
    }
    return null;
  }

  String? chapterStartIdForPath(String path) {
    final canonical = canonicalPath(path);
    return ExampleDemoContent.chapterStartIdByPath[canonical];
  }

  String? resolveEpubImagePath({
    required String rawSrc,
    required String currentChapterPath,
  }) {
    final src = rawSrc.trim();
    if (src.isEmpty) {
      return null;
    }

    final parsed = Uri.tryParse(src);
    if (parsed != null && parsed.hasScheme) {
      return null;
    }

    final normalizedCurrentPath = normalizePath(currentChapterPath);
    final baseUri = Uri.parse(
      normalizedCurrentPath.contains('/')
          ? normalizedCurrentPath
          : '/$normalizedCurrentPath',
    );
    final resolved = baseUri.resolve(src).path;
    return resolved.startsWith('/') ? resolved.substring(1) : resolved;
  }
}
