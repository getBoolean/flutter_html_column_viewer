import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_html_column_viewer/flutter_html_column_viewer.dart';

import 'src/example_reader_service.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: const ExamplePage());
  }
}

class ExamplePage extends StatefulWidget {
  const ExamplePage({super.key});

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  late final ExampleReaderService _service;

  @override
  void initState() {
    super.initState();
    _service = ExampleReaderService();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _service,
      builder: (context, _) {
        final pagination = _service.currentChapterPagination;
        final pageLabel = _service.pageCount > 0
            ? '${pagination?.current ?? 0} / ${pagination?.total ?? 0} (${_service.currentChapterPath})'
            : null;

        return Scaffold(
          appBar: AppBar(title: const Text('Flutter HTML Viewer Example')),
          body: Column(
            children: [
              Expanded(
                child: ExampleReaderView(
                  service: _service,
                  onMessage: _showMessage,
                ),
              ),
              ExampleBottomControls(
                canGoPrevious: _service.canGoPrevious,
                canGoNext: _service.canGoNext,
                onPrevious: _service.goToPreviousPage,
                onNext: _service.goToNextPage,
                pageLabel: pageLabel,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class ExampleReaderView extends StatelessWidget {
  const ExampleReaderView({
    super.key,
    required this.service,
    required this.onMessage,
  });

  final ExampleReaderService service;
  final ValueChanged<String> onMessage;

  @override
  Widget build(BuildContext context) {
    return HtmlColumnReader(
      controller: service.readerController,
      columnsPerPage: ExampleReaderService.columnsPerPage,
      html: service.currentHtml,
      onRefTap: _onRefTap,
      imageBytesBuilder: _buildImageBytes,
      onPageCountChanged: service.onPageCountChanged,
      onColumnCountChanged: service.onColumnCountChanged,
      onBookmarkColumnIndexChanged: service.onBookmarkColumnIndexChanged,
      onBookmarkPageCandidatesChanged: service.onBookmarkPageCandidatesChanged,
    );
  }

  void _onRefTap(HtmlReference reference) {
    unawaited(
      service.handleLinkTap(reference).then((message) {
        if (message != null && message.isNotEmpty) {
          onMessage(message);
        }
      }),
    );
  }

  Future<Uint8List?> _buildImageBytes(HtmlImageRef imageRef) {
    return service.resolveImageBytes(imageRef.src, imageRef.alt);
  }
}

class ExampleBottomControls extends StatelessWidget {
  const ExampleBottomControls({
    super.key,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
    required this.pageLabel,
  });

  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final String? pageLabel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 360;
            final previousButton = compact
                ? IconButton.filledTonal(
                    onPressed: canGoPrevious ? onPrevious : null,
                    tooltip: 'Previous',
                    icon: const Icon(Icons.arrow_back),
                  )
                : FilledButton.tonalIcon(
                    onPressed: canGoPrevious ? onPrevious : null,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Previous'),
                  );
            final nextButton = compact
                ? IconButton.filledTonal(
                    onPressed: canGoNext ? onNext : null,
                    tooltip: 'Next',
                    icon: const Icon(Icons.arrow_forward),
                  )
                : FilledButton.tonalIcon(
                    onPressed: canGoNext ? onNext : null,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Next'),
                  );

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                previousButton,
                if (pageLabel != null) ...[
                  SizedBox(width: compact ? 8 : 12),
                  Expanded(
                    child: Text(
                      pageLabel!,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(width: compact ? 8 : 12),
                ],
                nextButton,
              ],
            );
          },
        ),
      ),
    );
  }
}
