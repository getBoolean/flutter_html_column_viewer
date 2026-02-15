import 'example_demo_content.dart';
import 'example_reader_models.dart';
import 'example_reader_paths.dart';

class ExampleReaderImages {
  const ExampleReaderImages({required ExampleReaderPaths paths}) : _paths = paths;

  final ExampleReaderPaths _paths;

  ExampleImageData resolveImage({
    required String src,
    required String? alt,
    required String currentChapterPath,
  }) {
    final imageUri = Uri.tryParse(src.trim());
    final isRemote =
        imageUri != null &&
        (imageUri.scheme == 'http' || imageUri.scheme == 'https');
    final resolvedEpubPath = _paths.resolveEpubImagePath(
      rawSrc: src,
      currentChapterPath: currentChapterPath,
    );
    final mappedRemoteUrl = resolvedEpubPath == null
        ? null
        : ExampleDemoContent.epubImageUrlByPath[
            _paths.normalizePath(resolvedEpubPath)
          ];
    final effectiveUrl = isRemote ? src : mappedRemoteUrl;

    return ExampleImageData(
      src: src,
      alt: alt,
      isRemote: isRemote,
      resolvedEpubPath: resolvedEpubPath,
      effectiveUrl: effectiveUrl,
    );
  }
}
