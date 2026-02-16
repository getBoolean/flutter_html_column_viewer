class EpubCfiParser {
  const EpubCfiParser();

  static final RegExp _cfiExpressionPattern = RegExp(
    r'epubcfi\((.+)\)',
    caseSensitive: false,
  );
  static final RegExp _cfiBracketIdentifierPattern = RegExp(r'\[([^\]]+)\]');

  String? extractExpression(String raw) {
    final match = _cfiExpressionPattern.firstMatch(raw);
    return match?.group(1);
  }

  List<String> extractBracketIdentifiers(String cfi) {
    final matches = _cfiBracketIdentifierPattern.allMatches(cfi);
    if (matches.isEmpty) {
      return const <String>[];
    }

    return matches
        .map((match) => match.group(1)?.trim())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  List<String> parseCandidateIds(String rawReference) {
    final cfi = extractExpression(rawReference);
    if (cfi == null) {
      return const <String>[];
    }
    return extractBracketIdentifiers(cfi);
  }
}
