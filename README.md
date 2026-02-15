# flutter_html_viewer

`flutter_html_viewer` renders HTML with Flutter widgets and displays content in
paged columns.  
Set `columnsPerPage`, and each page will show exactly that many columns.
Swiping horizontally moves to the next page of continued content.

## Features

- HTML parsing with `html: ^0.15.6`
- Inline CSS parsing with `csslib: ^1.0.2`
- Paged multi-column layout (`columnsPerPage`)
- Extended HTML support:
  - headings (`h1`-`h6`), paragraphs, links
  - unordered/ordered lists
  - blockquote
  - pre/code blocks
  - tables
  - images (`img`)
- Inline style support (subset):
  - `color`
  - `background-color`
  - `font-size` (px)
  - `font-weight`
  - `font-style`
  - `text-decoration`
  - `text-align`

## Getting started

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_html_viewer: ^0.0.1
```

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:flutter_html_viewer/flutter_html_viewer.dart';

class ReaderPage extends StatelessWidget {
  const ReaderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HtmlColumnReader(
        html: '''
          <h1>My Article</h1>
          <p style="text-align: justify;">Long HTML content...</p>
        ''',
        columnsPerPage: 2,
        columnGap: 16,
        onLinkTap: (href) {
          debugPrint('Tapped link: $href');
        },
      ),
    );
  }
}
```

## API

- `HtmlColumnReader`
  - `html` - source HTML string
  - `columnsPerPage` - number of visible columns on each page
  - `columnGap` - gap between columns
  - `pagePadding` - page padding
  - `textStyle` - base text style
  - `headingStyles` - optional heading style overrides
  - `onLinkTap` - link tap callback
  - `imageBuilder` - custom image rendering hook

## Example app

A runnable example is included in `example/` and demonstrates:
- two columns per page
- horizontal page swipes
- representative extended HTML tags
