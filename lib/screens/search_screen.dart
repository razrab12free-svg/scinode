import 'package:flutter/material.dart';

import '../models/paper.dart';
import '../services/openalex_service.dart';
import '../strings.dart';
import '../widgets/paper_card.dart';
import 'paper_sheet.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _examples = [
    'machine learning',
    'CRISPR',
    'graphene',
    'climate change',
    'quantum computing',
    'Alzheimer',
  ];

  final TextEditingController _ctrl = TextEditingController();
  final List<Paper> _papers = [];
  String _query = '';
  bool _oaOnly = false;
  int? _yearFrom;
  String _sort = 'relevance';
  int _page = 1;
  int _total = 0;
  bool _loading = false;
  bool _searched = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _run({bool more = false}) async {
    final q = more ? _query : _ctrl.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      if (!more) {
        _query = q;
        _page = 1;
        _papers.clear();
        _searched = true;
      }
    });
    try {
      final r = await OpenAlexService.instance.search(
        query: q,
        page: more ? _page + 1 : 1,
        oaOnly: _oaOnly,
        yearFrom: _yearFrom,
        sort: _sort,
      );
      if (!mounted) return;
      setState(() {
        _papers.addAll(r.papers);
        _total = r.total;
        _page = r.page;
        _loading = false;
      });
    } on SearchException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.kind;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'other';
        _loading = false;
      });
    }
  }

  void _changed(VoidCallback fn) {
    setState(fn);
    if (_searched && _query.isNotEmpty) {
      _ctrl.text = _query;
      _run();
    }
  }

  void _tryExample(String q) {
    _ctrl.text = q;
    _run();
  }

  Widget _filters() {
    final year = DateTime.now().year;
    final yearOptions = <int?>[null, year - 4, year - 1];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          FilterChip(
            label: Text(t('f.oa')),
            selected: _oaOnly,
            showCheckmark: false,
            onSelected: (v) => _changed(() => _oaOnly = v),
          ),
          const SizedBox(width: 8),
          for (final s in const ['relevance', 'cited', 'newest'])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(t('f.sort.$s')),
                selected: _sort == s,
                showCheckmark: false,
                onSelected: (_) => _changed(() => _sort = s),
              ),
            ),
          for (final y in yearOptions)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(y == null
                    ? t('f.year.any')
                    : t('f.year.from', {'y': y})),
                selected: _yearFrom == y,
                showCheckmark: false,
                onSelected: (_) => _changed(() => _yearFrom = y),
              ),
            ),
        ],
      ),
    );
  }

  Widget _intro() {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Icon(Icons.travel_explore, size: 64, color: scheme.primary),
        const SizedBox(height: 16),
        Text(
          t('search.intro'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 24),
        Text(t('search.try'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in _examples)
              ActionChip(label: Text(e), onPressed: () => _tryExample(e)),
          ],
        ),
      ],
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 12),
            Text(
              t('search.err.${_error ?? 'other'}'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                  minimumSize: const Size(160, 48)),
              onPressed: () => _run(more: _papers.isNotEmpty),
              child: Text(t('search.retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(t('search.err.${_error!}'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14)),
            TextButton(
              onPressed: () => _run(more: true),
              child: Text(t('search.retry')),
            ),
          ],
        ),
      );
    }
    if (_papers.length < _total) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: () => _run(more: true),
          child: Text(t('search.more')),
        ),
      );
    }
    return const SizedBox(height: 12);
  }

  Widget _body() {
    if (!_searched) return _intro();
    if (_papers.isEmpty) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      if (_error != null) return _errorView();
      return Center(child: Text(t('search.empty')));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      itemCount: _papers.length + 2,
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              t('search.results', {'n': _total}),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          );
        }
        if (i == _papers.length + 1) return _footer();
        final p = _papers[i - 1];
        return PaperCard(
          paper: p,
          onTap: () => showPaperSheet(context, p),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _ctrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _run(),
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: t('search.hint'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _run,
                ),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          _filters(),
          const SizedBox(height: 6),
          Expanded(child: _body()),
        ],
      ),
    );
  }
}
