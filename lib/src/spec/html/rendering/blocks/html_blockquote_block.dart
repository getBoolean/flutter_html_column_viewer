import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';

import '../../model/html_nodes.dart';

class HtmlBlockquoteBlock extends StatelessWidget {
  const HtmlBlockquoteBlock({
    super.key,
    required this.node,
    required this.child,
  });

  final HtmlTextBlockNode node;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: node.style.borderLeftColor ?? Theme.of(context).dividerColor,
            width: node.style.borderLeftWidth ?? 3,
            style: node.style.borderLeftStyle ?? BorderStyle.solid,
          ),
        ),
      ),
      child: child,
    );
  }
}
