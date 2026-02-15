import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_html_column_viewer/flutter_html_column_viewer.dart';

import '../example_reader_service.dart';
import 'example_image_widget.dart';

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
      imageBuilder: _buildImage,
      onPageCountChanged: service.onPageCountChanged,
      onColumnCountChanged: service.onColumnCountChanged,
      onBookmarkColumnIndexChanged: service.onBookmarkColumnIndexChanged,
      onBookmarkPageCandidatesChanged: service.onBookmarkPageCandidatesChanged,
    );
  }

  void _onRefTap(HtmlReference reference) {
    unawaited(
      service.handleReferenceTap(reference).then((message) {
        if (message != null && message.isNotEmpty) {
          onMessage(message);
        }
      }),
    );
  }

  Widget _buildImage(BuildContext context, String src, String? alt) {
    return ExampleImageWidget(data: service.resolveImage(src, alt));
  }
}
