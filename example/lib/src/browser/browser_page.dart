import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_html_column_widget/flutter_html_column_widget.dart';

import 'browser_controller.dart';
import 'browser_page_service.dart';

const String _defaultAddress =
    'https://www.w3.org/Style/CSS/Test/CSS1/current/index.html';

class BrowserExampleApp extends StatelessWidget {
  const BrowserExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const BrowserExamplePage(),
    );
  }
}

class BrowserExamplePage extends StatefulWidget {
  const BrowserExamplePage({super.key});

  @override
  State<BrowserExamplePage> createState() => _BrowserExamplePageState();
}

class _BrowserExamplePageState extends State<BrowserExamplePage> {
  late final BrowserController _controller;

  @override
  void initState() {
    super.initState();
    _controller = BrowserController(pageService: BrowserPageService());
    unawaited(_controller.openInitial(_defaultAddress));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('HTML Browser Example')),
          body: Column(
            children: <Widget>[
              BrowserToolbar(controller: _controller),
              if (_controller.error != null)
                _BrowserError(error: _controller.error!),
              Expanded(
                child: _BrowserBody(
                  controller: _controller,
                  onMessage: _showMessage,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted || message.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class BrowserToolbar extends StatelessWidget {
  const BrowserToolbar({super.key, required this.controller});

  final BrowserController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: controller.canGoBack ? controller.goBack : null,
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
          ),
          IconButton(
            onPressed: controller.canGoForward ? controller.goForward : null,
            icon: const Icon(Icons.arrow_forward),
            tooltip: 'Forward',
          ),
          IconButton(
            onPressed: controller.currentUri != null ? controller.reload : null,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller.addressController,
              decoration: const InputDecoration(
                hintText: 'Enter URL (https://...)',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => controller.openAddressBarInput(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: controller.openAddressBarInput,
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }
}

class _BrowserBody extends StatefulWidget {
  const _BrowserBody({required this.controller, required this.onMessage});

  final BrowserController controller;
  final ValueChanged<String> onMessage;

  @override
  State<_BrowserBody> createState() => _BrowserBodyState();
}

class _BrowserBodyState extends State<_BrowserBody> {
  final ScrollController _scrollController = ScrollController();
  final HtmlContentParser _parser = HtmlContentParser();
  final Map<String, GlobalKey> _anchorKeys = <String, GlobalKey>{};
  String? _lastDocumentToken;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (controller.loading && controller.html.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.html.isEmpty) {
      return const Center(child: Text('Enter a URL to load HTML.'));
    }

    final documentToken =
        '${controller.currentUri?.toString() ?? ''}::${controller.html.hashCode}';
    if (documentToken != _lastDocumentToken) {
      _lastDocumentToken = documentToken;
      _anchorKeys.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    }
    final blocks = _parser.parse(
      controller.html,
      externalCssResolver: controller.resolveExternalCss,
    );

    return Stack(
      children: <Widget>[
        ListView.separated(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: blocks.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final block = blocks[index];
            final blockKey = _keyForAnchor(block.id);
            final view = HtmlBlockView(
              block: block,
              blockContext: HtmlBlockContext(
                baseStyle: Theme.of(context).textTheme.bodyMedium!,
                onRefTap: (reference) {
                  unawaited(
                    controller
                        .openReference(
                          reference,
                          scrollToFragment: _scrollToFragment,
                        )
                        .then((message) {
                          if (message != null && message.isNotEmpty) {
                            widget.onMessage(message);
                          }
                        }),
                  );
                },
                imageBuilder: (context, src, alt) {
                  final imageUri = controller.resolveImageUri(src);
                  if (imageUri == null ||
                      !(imageUri.scheme == 'http' ||
                          imageUri.scheme == 'https')) {
                    return _MissingImagePlaceholder(src: src, alt: alt);
                  }
                  return Image.network(
                    imageUri.toString(),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        _MissingImagePlaceholder(src: src, alt: alt),
                  );
                },
              ),
            );
            if (blockKey == null) {
              return view;
            }
            return KeyedSubtree(key: blockKey, child: view);
          },
        ),
        if (controller.loading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  GlobalKey? _keyForAnchor(String? id) {
    if (id == null || id.trim().isEmpty) {
      return null;
    }
    return _anchorKeys.putIfAbsent(id, GlobalKey.new);
  }

  Future<void> _scrollToFragment(String fragmentId) async {
    final key = _anchorKeys[fragmentId];
    if (key == null) {
      widget.onMessage('Anchor not found: #$fragmentId');
      return;
    }
    final anchorContext = key.currentContext;
    if (anchorContext == null) {
      widget.onMessage('Anchor not visible yet: #$fragmentId');
      return;
    }
    await Scrollable.ensureVisible(
      anchorContext,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      alignment: 0.08,
    );
  }
}

class _BrowserError extends StatelessWidget {
  const _BrowserError({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Material(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  error,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissingImagePlaceholder extends StatelessWidget {
  const _MissingImagePlaceholder({required this.src, required this.alt});

  final String src;
  final String? alt;

  @override
  Widget build(BuildContext context) {
    final display = (alt?.trim().isNotEmpty ?? false) ? alt!.trim() : src;
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(10),
      child: Center(
        child: Text(
          display,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
