import 'package:flutter/material.dart';

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
