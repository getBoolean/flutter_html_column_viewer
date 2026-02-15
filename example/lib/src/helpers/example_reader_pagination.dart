import 'example_reader_models.dart';

class ExampleReaderPagination {
  const ExampleReaderPagination({required this.columnsPerPage});

  final int columnsPerPage;

  int currentAbsoluteColumnForSpread({
    required int spreadPage,
    required int columnCount,
  }) {
    if (columnCount <= 0) {
      return 0;
    }
    final absolute = spreadPage * columnsPerPage;
    return absolute.clamp(0, columnCount - 1);
  }

  ChapterPagination? currentChapterPagination({
    required int columnCount,
    required int currentSpreadPage,
    required int chapterStartColumn,
    required int chapterEndColumn,
  }) {
    if (columnCount <= 0) {
      return null;
    }

    final totalColumnPages = (chapterEndColumn - chapterStartColumn + 1).clamp(
      1,
      columnCount,
    );
    final currentColumn = currentAbsoluteColumnForSpread(
      spreadPage: currentSpreadPage,
      columnCount: columnCount,
    );
    final currentColumnPage = (currentColumn - chapterStartColumn + 1).clamp(
      1,
      totalColumnPages,
    );
    return ChapterPagination(current: currentColumnPage, total: totalColumnPages);
  }

  int? resolvePageInChapterForFragment({
    required List<int>? candidates,
    required int chapterStartColumn,
    required int chapterEndColumn,
  }) {
    if (candidates == null || candidates.isEmpty) {
      return null;
    }
    final startPage = chapterStartColumn ~/ columnsPerPage;
    final endPage = chapterEndColumn ~/ columnsPerPage;
    for (final page in candidates) {
      if (page >= startPage && page <= endPage) {
        return page;
      }
    }
    return null;
  }
}
