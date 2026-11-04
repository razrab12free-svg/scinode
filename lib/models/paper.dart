import 'strings_hook.dart';

dynamic _dig(dynamic m, List<String> path) {
  var cur = m;
  for (final k in path) {
    if (cur is Map) {
      cur = cur[k];
    } else {
      return null;
    }
  }
  return cur;
}

String? _str(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

String _abstract(dynamic inv) {
  if (inv is! Map) return '';
  final words = <int, String>{};
  inv.forEach((k, v) {
    if (v is List) {
      for (final p in v) {
        if (p is int) words[p] = k.toString();
      }
    }
  });
  final keys = words.keys.toList()..sort();
  return keys.map((i) => words[i]!).join(' ');
}

/// Научная статья.
class Paper {
  const Paper({
    required this.id,
    required this.title,
    this.year,
    this.citations = 0,
    this.authors = const [],
    this.venue = '',
    this.doi,
    this.abstractText = '',
    this.isOa = false,
    this.pdfUrl,
    this.landingUrl,
    this.topic = '',
  });

  final String id;
  final String title;
  final int? year;
  final int citations;
  final List<String> authors;
  final String venue;
  final String? doi;
  final String abstractText;
  final bool isOa;
  final String? pdfUrl;
  final String? landingUrl;
  final String topic;

  String? get articleUrl => landingUrl ?? doi;

  /// DOI без префикса адреса, например 10.1038/nature12373.
  String? get doiShort {
    final d = doi;
    if (d == null) return null;
    return d.replaceFirst(RegExp(r'^https?://(dx\.)?doi\.org/'), '');
  }

  String get authorsLine {
    if (authors.isEmpty) return '';
    if (authors.length <= 3) return authors.join(', ');
    return '${authors.take(3).join(', ')} ${etAl()}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'year': year,
        'citations': citations,
        'authors': authors,
        'venue': venue,
        'doi': doi,
        'abstract': abstractText,
        'isOa': isOa,
        'pdfUrl': pdfUrl,
        'landingUrl': landingUrl,
        'topic': topic,
      };

  factory Paper.fromJson(Map<String, dynamic> j) => Paper(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        year: j['year'] is int ? j['year'] as int : null,
        citations: j['citations'] is int ? j['citations'] as int : 0,
        authors: [
          for (final a in (j['authors'] as List? ?? const [])) a.toString(),
        ],
        venue: (j['venue'] ?? '').toString(),
        doi: _str(j['doi']),
        abstractText: (j['abstract'] ?? '').toString(),
        isOa: j['isOa'] == true,
        pdfUrl: _str(j['pdfUrl']),
        landingUrl: _str(j['landingUrl']),
        topic: (j['topic'] ?? '').toString(),
      );

  factory Paper.fromOpenAlex(Map<String, dynamic> w) {
    final authors = <String>[];
    final auths = w['authorships'];
    if (auths is List) {
      for (final a in auths) {
        final n = _str(_dig(a, ['author', 'display_name']));
        if (n != null) authors.add(n);
      }
    }
    return Paper(
      id: _str(w['id']) ?? '',
      title: _str(w['title']) ?? _str(w['display_name']) ?? '—',
      year: w['publication_year'] is int ? w['publication_year'] as int : null,
      citations: w['cited_by_count'] is int ? w['cited_by_count'] as int : 0,
      authors: authors,
      venue:
          _str(_dig(w, ['primary_location', 'source', 'display_name'])) ?? '',
      doi: _str(w['doi']),
      abstractText: _abstract(w['abstract_inverted_index']),
      isOa: _dig(w, ['open_access', 'is_oa']) == true,
      pdfUrl: _str(_dig(w, ['best_oa_location', 'pdf_url'])),
      landingUrl:
          _str(_dig(w, ['best_oa_location', 'landing_page_url'])) ??
              _str(_dig(w, ['open_access', 'oa_url'])),
      topic: _str(_dig(w, ['primary_topic', 'display_name'])) ?? '',
    );
  }
}
