import '../models/contact.dart';

class FuzzyMatcher {
  static List<Contact> searchContacts(String query, List<Contact> contacts) {
    if (query.isEmpty) return contacts;

    final cleanedQuery = _cleanString(query);
    if (cleanedQuery.isEmpty) return contacts;

    // Split query into individual words
    final qWords = cleanedQuery.split(' ');

    final scoredContacts = <_ScoredContact>[];

    for (final contact in contacts) {
      final cleanedName = _cleanString(contact.name);
      if (cleanedName.isEmpty) continue;

      // ── 1. EXACT OR SUBSTRING MATCH BONUSES ───────────────────────
      if (cleanedName == cleanedQuery) {
        scoredContacts.add(_ScoredContact(contact, 1.0));
        continue;
      }

      // If the query perfectly matches a word or substring of the name
      if (cleanedName.contains(cleanedQuery) || cleanedQuery.contains(cleanedName)) {
        // Calculate similarity based on length ratio
        final ratio = cleanedQuery.length < cleanedName.length
            ? cleanedQuery.length / cleanedName.length
            : cleanedName.length / cleanedQuery.length;
        
        // Grant a strong substring score (minimum 0.75 up to 0.95)
        final score = 0.75 + (ratio * 0.2);
        scoredContacts.add(_ScoredContact(contact, score));
        continue;
      }

      // ── 2. WORD-LEVEL SIMILARITY SCORING ──────────────────────────
      final cWords = cleanedName.split(' ');
      double totalQueryWordScore = 0.0;

      for (final qw in qWords) {
        double bestWordScore = 0.0;

        for (final cw in cWords) {
          double currentScore = 0.0;

          if (qw == cw) {
            currentScore = 1.0;
          } else if (_phoneticNormalize(qw) == _phoneticNormalize(cw)) {
            // High score for phonetic equivalents like "aneesh" and "anish"
            currentScore = 0.95;
          } else {
            // Levenshtein similarity
            final dist = _levenshtein(qw, cw);
            final maxLen = qw.length > cw.length ? qw.length : cw.length;
            currentScore = maxLen > 0 ? 1.0 - (dist / maxLen) : 0.0;
            if (currentScore < 0.0) currentScore = 0.0;
          }

          // Substring bonus within words
          if ((cw.contains(qw) || qw.contains(cw)) && currentScore < 0.7) {
            currentScore = 0.7;
          }

          if (currentScore > bestWordScore) {
            bestWordScore = currentScore;
          }
        }

        totalQueryWordScore += bestWordScore;
      }

      final averageScore = totalQueryWordScore / qWords.length;

      // Only retain matches with a confidence score above 0.5
      if (averageScore >= 0.5) {
        scoredContacts.add(_ScoredContact(contact, averageScore));
      }
    }

    // ── 3. SORT BY SCORE & TIE-BREAKERS ─────────────────────────────
    scoredContacts.sort((a, b) {
      // Sort by score descending
      final scoreComparison = b.score.compareTo(a.score);
      if (scoreComparison != 0) return scoreComparison;

      // If scores are equal, prefer shorter contact name (closer fit to query)
      return a.contact.name.length.compareTo(b.contact.name.length);
    });

    return scoredContacts.map((sc) => sc.contact).toList();
  }

  // Standardize strings: strip emojis, symbols, punctuation, and lowercase
  static String _cleanString(String s) {
    return s
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  // Phonetic normalization for Indian pronunciation variations
  static String _phoneticNormalize(String s) {
    return s
        .replaceAll('ee', 'i')
        .replaceAll('oo', 'u')
        .replaceAll('y', 'i')
        .replaceAll('sh', 's')
        .replaceAll('ch', 'c')
        .replaceAll('bh', 'b')
        .replaceAll('dh', 'd')
        .replaceAll('gh', 'g')
        .replaceAll('kh', 'k')
        .replaceAll('ph', 'f')
        .replaceAll('th', 't')
        .replaceAll('jh', 'j');
  }

  // Standard Levenshtein distance algorithm
  static int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;

      for (int j = 0; j < t.length; j++) {
        int cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = _min3(v1[j] + 1, v0[j + 1] + 1, v0[j] + cost);
      }

      for (int j = 0; j < v0.length; j++) {
        v0[j] = v1[j];
      }
    }

    return v0[t.length];
  }

  static int _min3(int a, int b, int c) {
    int m = a < b ? a : b;
    return m < c ? m : c;
  }
}

class _ScoredContact {
  final Contact contact;
  final double score;
  _ScoredContact(this.contact, this.score);
}
