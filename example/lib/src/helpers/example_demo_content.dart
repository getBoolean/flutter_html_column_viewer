class ExampleDemoContent {
  const ExampleDemoContent._();

  static const String initialDocumentPath = 'chapter1.xhtml';

  static const Map<String, String> documents = <String, String>{
    'chapter1.xhtml': chapter1Html,
    'chapter2.xhtml': chapter2Html,
    'chapters/chapter2.xhtml': chapter2Html,
    'chapter3.xhtml': chapter3Html,
    'chapters/chapter3.xhtml': chapter3Html,
  };

  static const List<String> chapterOrder = <String>[
    'chapter1.xhtml',
    'chapter2.xhtml',
    'chapter3.xhtml',
  ];

  static const Map<String, String> canonicalChapterByPath = <String, String>{
    'chapter1.xhtml': 'chapter1.xhtml',
    'chapter2.xhtml': 'chapter2.xhtml',
    'chapters/chapter2.xhtml': 'chapter2.xhtml',
    'chapter3.xhtml': 'chapter3.xhtml',
    'chapters/chapter3.xhtml': 'chapter3.xhtml',
  };

  static const Map<String, String> chapterStartIdByPath = <String, String>{
    'chapter1.xhtml': 'top',
    'chapter2.xhtml': 'chapter2-top',
    'chapter3.xhtml': 'chapter3-top',
  };

  static const Map<String, String> epubImageUrlByPath = <String, String>{
    'images/chapter1-illustration.jpg': 'https://picsum.photos/id/1015/640/220',
    'images/chapter2-illustration.jpg': 'https://picsum.photos/id/1025/640/220',
  };

  static const Map<String, String> styleSheets = <String, String>{
    'styles/chapter3.css': chapter3ExternalCss,
  };

  static const Map<String, String> externalCssByChapterPath = <String, String>{
    'chapter3.xhtml': chapter3ExternalCss,
  };
}

const String chapter1Html = '''
<h1 id="top" style="color:#1a237e;">Chapter 1</h1>
<p style="text-align: justify;">
This demo shows abstract reference handling with <code>onRefTap</code>.
Tap <a href="#section3">same-file anchor</a>,
<a href="chapters/chapter2.xhtml#para12">cross-file reference</a>,
<a href="book.epub#epubcfi(/6/4[chap01ref]!/4[body01]/10[para05]/3:10)">CFI-like reference</a>,
or an <a href="https://example.com">external URL</a>.
</p>
<p>
Accessibility note example:
<a href="#note1" epub:type="noteref" role="doc-noteref">Footnote 1</a>.
</p>
<h2 id="supported-html-css">Supported HTML and CSS examples</h2>
<h3 style="color: rgb(38, 70, 83);">Heading level 3</h3>
<h4 style="color: teal;">Heading level 4</h4>
<h5 style="font-style: italic;">Heading level 5</h5>
<h6 style="text-decoration: underline;">Heading level 6</h6>
<section id="section-block" style="background-color: #f1f8e9;">
  <p style="font-size: 18px; font-weight: 600;">
    Section + paragraph with inline CSS: <strong>strong</strong>, <b>b</b>,
    <em>em</em>, <i>i</i>, <u>u</u>, and inline <code>code()</code>.
  </p>
</section>
<article id="article-block">
  <div style="text-align: center; color: #37474f;">
    Article + div block with centered text and named/hex colors.
    <br>
    This second line is created with a <code>&lt;br&gt;</code> tag.
  </div>
</article>
<blockquote style="font-style: italic; color: #424242;">
  Blockquote example rendered with a quote border style in Flutter.
</blockquote>
<pre id="pre-sample" style="background-color: #eeeeee; color: #1b5e20;">
for (var i = 0; i < 3; i++) {
  print('preformatted code line \$i');
}
</pre>
<hr>
<ul id="unordered-list">
  <li>Unordered item with <strong>bold text</strong></li>
  <li>Unordered item with <em>italic text</em></li>
  <li>Unordered item with <u>underlined text</u></li>
</ul>
<ol id="ordered-list" style="font-size: 15px;">
  <li>Ordered item one</li>
  <li>Ordered item two</li>
  <li>Ordered item three</li>
</ol>
<table id="table-sample">
  <tr>
    <th>Tag</th>
    <th>Status</th>
    <th>Notes</th>
  </tr>
  <tr>
    <td>table</td>
    <td>Supported</td>
    <td>th/td rows are rendered as Flutter Table</td>
  </tr>
  <tr>
    <td>img</td>
    <td>Supported</td>
    <td>Uses Image.network by default</td>
  </tr>
</table>
<h3 id="image-estimation-demo">Image estimation demo</h3>
<p>
The next images include both explicit dimensions and missing dimensions so you can
compare column height estimation behavior.
</p>
<img
  id="example-image-sized-attrs"
  src="https://picsum.photos/id/1043/720/320"
  width="720"
  height="320"
  alt="Network image with width and height attributes"
>
<img
  id="example-image-sized-style"
  src="https://picsum.photos/id/1059/480/640"
  style="width: 480px; height: 640px;"
  alt="Network image with width and height in inline style"
>
<img
  id="example-image-fallback-fill-1"
  src="https://picsum.photos/640/220"
  alt="Network image with no width and height, should estimate as full column height"
>
<img
  id="example-epub-image-path"
  src="images/chapter1-illustration.jpg"
  alt="Example EPUB-style relative image path with no dimensions, resolved by imageBuilder"
>
<img
  id="example-image-fallback-fill-2"
  src="images/chapter2-illustration.jpg"
  alt="Second EPUB-style image path with no dimensions, should estimate as full column height"
>
<h2 id="section2">Section 2</h2>
<p>Intro paragraph for chapter 1.</p>
<p>
Section 2 is intentionally long in the example so internal navigation can
demonstrate a page jump when linking to <code>#section3</code>.
</p>
<p>
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer porta orci
at purus varius, eu convallis risus gravida. Sed id ipsum et nunc feugiat
porttitor non non velit.
</p>
<p>
Curabitur ut libero in erat pretium tristique. Vestibulum ante ipsum primis in
faucibus orci luctus et ultrices posuere cubilia curae; Morbi vitae diam
eleifend, dictum sem at, feugiat erat.
</p>
<p>
Mauris finibus magna at nibh feugiat, eget posuere erat bibendum. Suspendisse
interdum, mauris at sagittis euismod, nisi massa luctus augue, id hendrerit
urna arcu in ligula.
</p>
<p>
Praesent non dui venenatis, sodales augue non, dignissim est. Donec tincidunt
velit sed purus vestibulum vulputate. Cras efficitur faucibus hendrerit.
</p>
<p id="para05">
Etiam faucibus eros at justo lobortis, quis tristique lectus aliquet. In sit
amet tristique turpis, non varius neque. Integer hendrerit metus sed velit
facilisis lacinia.
</p>
<p>
Aliquam erat volutpat. In condimentum sem id dui hendrerit, sed ornare lacus
efficitur. Pellentesque id urna in ex ultrices volutpat nec in sapien.
</p>
<h2 id="section3">Section 3</h2>
<p id="para12">Target paragraph in chapter 1 for bookmark-based jumps.</p>
<p id="note1">Footnote 1 text.</p>
<p>More reading content to force pagination.</p>
<p>Lorem ipsum dolor sit amet, consectetur adipiscing elit.</p>
<p>Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.</p>
<p>Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.</p>
<p>Nisi ut aliquip ex ea commodo consequat.</p>
<p>Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore.</p>
<p>Excepteur sint occaecat cupidatat non proident.</p>
<p>Sunt in culpa qui officia deserunt mollit anim id est laborum.</p>
''';

const String chapter2Html = '''
<h1 id="chapter2-top" style="color:#0d47a1;">Chapter 2</h1>
<p>
You are now in chapter 2.
Tap <a href="chapter1.xhtml#section3">back to chapter 1 section 3</a>.
</p>
<p>
Continue to the new CSS showcase:
<a href="chapter3.xhtml#chapter3-top">chapter 3 style demo</a>.
</p>
<h2 id="overview">Overview</h2>
<p>Chapter 2 starts with an overview section.</p>
<p id="para12">This paragraph is the target for cross-file links.</p>
<p>Additional chapter 2 text to ensure multiple pages are possible.</p>
<p>Lorem ipsum dolor sit amet, consectetur adipiscing elit.</p>
<p>Vestibulum dignissim neque ac arcu interdum, vel tincidunt velit posuere.</p>
<p>Curabitur congue, justo ut varius efficitur, neque arcu consequat justo.</p>
''';

const String chapter3Html = '''
<h1 id="chapter3-top" style="color:#2e7d32;">Chapter 3: CSS Showcase</h1>
<p>
This chapter demonstrates the newly added CSS support:
inline styles, <code>&lt;style&gt;</code> rules, stylesheet links, cascade, and specificity.
Back to <a href="chapter1.xhtml#supported-html-css">chapter 1 support list</a>.
</p>

<style>
  .demo-scope {
    color: #37474f;
    font-family: "Roboto";
    line-height: 1.55;
  }
  p.demo-scope {
    margin: 8px 0;
    padding: 6px 10px;
    background-color: rgba(232, 245, 233, 0.8);
  }
  #specificity-target {
    color: #6a1b9a;
  }
  .specificity-note {
    color: #ef6c00;
  }
  ul.pretty-list {
    list-style-type: square;
    list-style-position: inside;
  }
  .caps {
    text-transform: uppercase;
    letter-spacing: 1.2px;
  }
</style>

<link rel="stylesheet" href="styles/chapter3.css">

<h2 id="cascade">Cascade and specificity</h2>
<p id="specificity-target" class="demo-scope specificity-note" style="color:#1565c0;">
  This paragraph resolves color from inline style, overriding ID and class rules.
</p>
<p class="demo-scope specificity-note">
  This paragraph resolves color from the class selector in the style block.
</p>
<p class="demo-scope">
  This paragraph inherits demo-scope typography and block styling.
</p>

<h2 id="typography">Typography and spacing</h2>
<p class="demo-box">
  External stylesheet applies block background, padding, margins, border-left, and line-height.
</p>
<p class="demo-indent">
  This paragraph demonstrates text indentation and line-height adjustments from external CSS.
</p>
<p class="caps">
  transformed text sample using text-transform and letter spacing
</p>
<p class="demo-preline">
  This line has extra      spaces.
  And this line break is preserved by white-space: pre-line.
</p>

<h2 id="lists">List style and marker behavior</h2>
<ul class="pretty-list demo-scope">
  <li>Square marker using list-style-type</li>
  <li>Inside marker using list-style-position</li>
  <li>Inherited typography from parent scope</li>
</ul>
<ol class="numbered-list">
  <li>Roman markers from external stylesheet</li>
  <li>Second list item</li>
  <li>Third list item</li>
</ol>
''';

const String chapter3ExternalCss = '''
.demo-box {
  margin: 12px 0;
  padding: 10px 12px;
  background-color: hsl(188, 52%, 94%);
  border-left: 4px solid #00838f;
  line-height: 1.7;
}

.demo-indent {
  text-indent: 20px;
  line-height: 1.65;
}

.demo-preline {
  white-space: pre-line;
  word-spacing: 2px;
}

ol.numbered-list {
  list-style-type: upper-roman;
  list-style-position: outside;
}
''';
