# Example Apps

This folder includes two runnable example entrypoints:

- Default reader demo:
  - `flutter run -t lib/main.dart`
- In-app HTML browser demo:
  - `flutter run -t lib/browser_main.dart`

The browser demo renders fetched HTML with `HtmlColumnReader` and keeps
navigation in-app by handling link taps internally (no external URL launcher).
