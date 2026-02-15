import 'example_demo_content.dart';
import 'example_reader_paths.dart';

class ExampleReaderChapters {
  const ExampleReaderChapters({required ExampleReaderPaths paths}) : _paths = paths;

  final ExampleReaderPaths _paths;

  bool isChapterLoaded({
    required List<String> loadedChapters,
    required String path,
  }) {
    final normalized = _paths.canonicalPath(path);
    return loadedChapters.any(
      (chapter) => _paths.canonicalPath(chapter) == normalized,
    );
  }

  String? nextChapterPath({
    required String activeChapterPath,
    required String? Function(String? rawPath) resolveDocument,
  }) {
    final normalizedCurrentPath = _paths.normalizePath(activeChapterPath);
    final canonicalCurrentPath =
        ExampleDemoContent.canonicalChapterByPath[normalizedCurrentPath] ??
        normalizedCurrentPath;
    final chapterOrder = ExampleDemoContent.chapterOrder
        .map(_paths.normalizePath)
        .toList();
    final currentIndex = chapterOrder.indexOf(canonicalCurrentPath);
    if (currentIndex == -1 || currentIndex >= chapterOrder.length - 1) {
      return null;
    }

    final nextCanonicalPath = chapterOrder[currentIndex + 1];
    return resolveDocument(nextCanonicalPath);
  }
}
