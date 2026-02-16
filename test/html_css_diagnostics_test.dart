import 'package:flutter_html_column_widget/flutter_html_column_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('logs unsupported css in debug callback pipeline', () {
    final warnings = <HtmlCssWarning>[];
    final diagnostics = HtmlCssDiagnostics(onWarning: warnings.add);
    final parser = HtmlContentParser(
      styleParser: CssStyleParser(diagnostics: diagnostics),
    );

    parser.parse('''
      <style>
        p { unsupported-prop: 1; color: #112233; }
      </style>
      <p>Hello</p>
    ''');

    expect(warnings, isNotEmpty);
    expect(warnings.any((w) => w.code == 'unsupported-property'), isTrue);
  });

  test('does not log unsupported warning for font-variant', () {
    final warnings = <HtmlCssWarning>[];
    final diagnostics = HtmlCssDiagnostics(onWarning: warnings.add);
    final parser = HtmlContentParser(
      styleParser: CssStyleParser(diagnostics: diagnostics),
    );

    parser.parse('''
      <style>
        p { font-variant: small-caps; }
      </style>
      <p>Hello</p>
    ''');

    expect(warnings.where((w) => w.property == 'font-variant'), isEmpty);
  });

  test('does not log unsupported warning for background and width', () {
    final warnings = <HtmlCssWarning>[];
    final diagnostics = HtmlCssDiagnostics(onWarning: warnings.add);
    final parser = HtmlContentParser(
      styleParser: CssStyleParser(diagnostics: diagnostics),
    );

    parser.parse('''
      <style>
        body { background: #CCCCCC; }
        object { width: 100%; }
      </style>
      <object data="sample.svg"></object>
    ''');

    expect(
      warnings.where(
        (w) => w.property == 'background' || w.property == 'width',
      ),
      isEmpty,
    );
  });
}
