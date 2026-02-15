import 'package:flutter_html_column_viewer/flutter_html_column_viewer.dart';
import 'package:url_launcher/url_launcher.dart';

typedef NavigateToChapterFragment =
    Future<int?> Function({
      required String chapterPath,
      required String? fragmentId,
    });

class ExampleReaderLinks {
  const ExampleReaderLinks();

  Future<String?> handleLinkTap({
    required HtmlReference reference,
    required String currentChapterPath,
    required String? resolvedTargetDocument,
    required String Function(String value) normalizePath,
    required NavigateToChapterFragment navigateToChapterFragment,
    required Future<bool> Function(HtmlReference reference)
    resolveAndNavigateCfi,
    required HtmlReaderController readerController,
  }) async {
    final hasExplicitPath =
        reference.path != null && reference.path!.trim().isNotEmpty;
    final isCrossDocument =
        hasExplicitPath &&
        resolvedTargetDocument != null &&
        normalizePath(resolvedTargetDocument) !=
            normalizePath(currentChapterPath);

    if (isCrossDocument) {
      await navigateToChapterFragment(
        chapterPath: resolvedTargetDocument,
        fragmentId: reference.fragmentId,
      );
      return null;
    }

    if (reference.fragmentId != null && reference.fragmentId!.isNotEmpty) {
      await readerController.animateToReference(reference.fragmentId!);
      return null;
    }

    if (reference.isCfiLike) {
      final resolved = await resolveAndNavigateCfi(reference);
      if (resolved) {
        return null;
      }
      return 'Unable to resolve CFI target from: ${reference.raw}';
    }

    final uri = reference.uri;
    if (uri != null && uri.hasScheme) {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) {
        return null;
      }
      return 'Unable to open URL: $uri';
    }

    return 'Unhandled reference: ${reference.raw}';
  }
}
