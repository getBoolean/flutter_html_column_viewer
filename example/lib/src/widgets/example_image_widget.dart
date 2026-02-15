import 'package:flutter/material.dart';

import '../example_reader_service.dart';

class ExampleImageWidget extends StatelessWidget {
  const ExampleImageWidget({super.key, required this.data});

  final ExampleImageData data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: data.effectiveUrl == null
                  ? ColoredBox(
                      color: colorScheme.tertiaryContainer,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'Resolved EPUB path:\n${data.resolvedEpubPath ?? data.src}\n\n'
                            'No mapping found in example asset map.',
                            style: TextStyle(
                              color: colorScheme.onTertiaryContainer,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                  : Image.network(
                      data.effectiveUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) {
                          return child;
                        }
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return ColoredBox(
                          color: colorScheme.errorContainer,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                'Image failed to load',
                                style: TextStyle(
                                  color: colorScheme.onErrorContainer,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          if (data.alt != null && data.alt!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              data.alt!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            data.isRemote
                ? data.src
                : 'EPUB src: ${data.src}'
                      '${data.resolvedEpubPath == null ? '' : ' -> ${data.resolvedEpubPath}'}'
                      '${data.effectiveUrl == null ? '' : ' -> ${data.effectiveUrl}'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
