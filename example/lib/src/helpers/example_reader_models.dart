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
