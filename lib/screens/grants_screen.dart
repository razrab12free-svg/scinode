import 'package:flutter/material.dart';

import '../models/grant.dart';
import '../services/grants_service.dart';
import '../strings.dart';
import '../widgets/grant_card.dart';
import 'grant_sheet.dart';

/// Экран «Гранты»: открытые конкурсы и профинансированные проекты.
class GrantsScreen extends StatelessWidget {
  const GrantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('gr.title')),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(height: 52, text: t('gr.tab.open')),
              Tab(height: 52, text: t('gr.tab.funded')),
            ],
          ),
        ),
        body: const TabBarView(
          children: [OpenCallsTab(), FundedProjectsTab()],
        ),
      ),
    );
  }
}

/// Состояние загрузки одного источника.
class _SourceState<T> {
  bool loading = false;
  String? error;
  List<T> items = const [];
}

String _errKind(Object e) => e is GrantsException ? e.kind : 'parse';

/// Общая логика: каждый источник грузится параллельно и независимо.
mixin _MultiSource<W extends StatefulWidget, T> on State<W> {
  late final Map<GrantSource, _SourceState<T>> states = {
    for (final s in sources) s: _SourceState<T>(),
  };
  late final Set<GrantSource> enabled = {...sources};
  final TextEditingController ctrl = TextEditingController();
  String query = '';
  int _seq = 0;

  List<GrantSource> get sources;
  Future<List<T>> fetch(GrantSource s, String q);

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  void loadAll() {
    _seq++;
    for (final s in sources) {
      loadOne(s);
    }
  }

  Future<void> loadOne(GrantSource s) async {
    final seq = _seq;
    final st = states[s]!;
    setState(() {
      st.loading = true;
      st.error = null;
    });
    try {
      final items = await fetch(s, query);
      if (!mounted || seq != _seq) return;
      setState(() {
        st.items = items;
        st.loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        st.items = const [];
        st.error = _errKind(e);
        st.loading = false;
      });
    }
  }

  Future<void> refresh() async {
    loadAll();
    // Ждём, пока все источники закончат, чтобы индикатор не пропадал раньше.
    while (mounted && states.values.any((s) => s.loading)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  bool get anyLoading => enabled.any((s) => states[s]!.loading);

  /// Строка поиска.
  Widget searchField(String hint, VoidCallback onSubmit) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: ctrl,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => onSubmit(),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: ListenableBuilder(
            listenable: ctrl,
            builder: (_, __) => ctrl.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip:
                        MaterialLocalizations.of(context).deleteButtonTooltip,
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      ctrl.clear();
                      onSubmit();
                    },
                  ),
          ),
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  /// Фильтр по источникам с числом найденного.
  Widget sourceChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          for (final s in sources)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: enabled.contains(s),
                onSelected: (v) => setState(() {
                  if (v) {
                    enabled.add(s);
                  } else {
                    enabled.remove(s);
                  }
                }),
                label: Text(_chipText(s)),
              ),
            ),
        ],
      ),
    );
  }

  String _chipText(GrantSource s) {
    final st = states[s]!;
    if (st.loading) return '${s.short} · …';
    if (st.error != null) return '${s.short} · !';
    return '${s.short} · ${st.items.length}';
  }

  /// Плашки загрузки и ошибок для включённых источников.
  List<Widget> statusRows() => [
        for (final s in sources)
          if (enabled.contains(s) && states[s]!.loading)
            SourceLoadingRow(source: s)
          else if (enabled.contains(s) && states[s]!.error != null)
            SourceErrorBanner(
              source: s,
              kind: states[s]!.error!,
              onRetry: () => loadOne(s),
            ),
      ];

  /// Пусто — только если хотя бы один включённый источник ответил без ошибки.
  bool get showEmpty =>
      !anyLoading && enabled.any((s) => states[s]!.error == null);

  Widget emptyText(String text) => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15)),
        ),
      );
}

// ---------------------------------------------------------------------------
// Открытые конкурсы
// ---------------------------------------------------------------------------

class OpenCallsTab extends StatefulWidget {
  const OpenCallsTab({super.key});

  @override
  State<OpenCallsTab> createState() => _OpenCallsTabState();
}

class _OpenCallsTabState extends State<OpenCallsTab>
    with AutomaticKeepAliveClientMixin, _MultiSource<OpenCallsTab, GrantCall> {
  DateTime _now = DateTime.now();

  @override
  bool get wantKeepAlive => true;

  @override
  List<GrantSource> get sources =>
      const [GrantSource.eu, GrantSource.grantsGov];

  @override
  Future<List<GrantCall>> fetch(GrantSource s, String q) {
    final svc = GrantsService.instance;
    return switch (s) {
      GrantSource.eu => svc.euCalls(q, now: _now),
      _ => svc.grantsGovCalls(q, now: _now),
    };
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => loadAll());
  }

  void _search() {
    FocusScope.of(context).unfocus();
    query = ctrl.text.trim();
    _now = DateTime.now();
    loadAll();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    final calls = <GrantCall>[
      for (final s in sources)
        if (enabled.contains(s)) ...states[s]!.items,
    ];
    sortCalls(calls);

    final header = <Widget>[
      ...statusRows(),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: InfoNote(
            text: t('gr.eligibility_short'), icon: Icons.verified_user),
      ),
      if (calls.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          child: Text(t('gr.found', {'n': calls.length}),
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        ),
      if (enabled.isEmpty)
        emptyText(t('gr.no_sources'))
      else if (calls.isEmpty && showEmpty)
        emptyText(t('gr.empty')),
    ];
    final footer = Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Text(t('gr.disclaimer'),
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
    );

    return Column(
      children: [
        searchField(t('gr.search.open'), _search),
        sourceChips(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () {
              _now = DateTime.now();
              return refresh();
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: header.length + calls.length + 1,
              itemBuilder: (ctx, i) {
                if (i < header.length) return header[i];
                final j = i - header.length;
                if (j == calls.length) return footer;
                final c = calls[j];
                return GrantCallCard(
                  call: c,
                  now: _now,
                  onTap: () => showGrantCallSheet(context, c),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Профинансированные проекты
// ---------------------------------------------------------------------------

class FundedProjectsTab extends StatefulWidget {
  const FundedProjectsTab({super.key});

  @override
  State<FundedProjectsTab> createState() => _FundedProjectsTabState();
}

class _FundedProjectsTabState extends State<FundedProjectsTab>
    with
        AutomaticKeepAliveClientMixin,
        _MultiSource<FundedProjectsTab, FundedProject> {
  static const _examples = [
    'quantum sensing',
    'CRISPR',
    'machine learning',
    'Alzheimer',
    'climate change',
    'graphene',
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  List<GrantSource> get sources => const [GrantSource.nih, GrantSource.nsf];

  @override
  Future<List<FundedProject>> fetch(GrantSource s, String q) {
    final svc = GrantsService.instance;
    return switch (s) {
      GrantSource.nih => svc.nihProjects(q),
      _ => svc.nsfAwards(q),
    };
  }

  void _search() {
    FocusScope.of(context).unfocus();
    query = ctrl.text.trim();
    if (query.isEmpty) {
      setState(() {
        for (final st in states.values) {
          st.items = const [];
          st.error = null;
          st.loading = false;
        }
      });
      return;
    }
    loadAll();
  }

  void _try(String q) {
    ctrl.text = q;
    _search();
  }

  Widget _intro() {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 12),
        Icon(Icons.workspace_premium_outlined, size: 64, color: scheme.primary),
        const SizedBox(height: 16),
        Text(t('gr.funded.intro'),
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        Text(t('gr.lang_note'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 24),
        Text(t('gr.try'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in _examples)
              ActionChip(label: Text(e), onPressed: () => _try(e)),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    final searched = query.isNotEmpty;
    final items = <FundedProject>[
      for (final s in sources)
        if (enabled.contains(s)) ...states[s]!.items,
    ];
    sortProjects(items);

    final header = <Widget>[
      ...statusRows(),
      if (items.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          child: Text(t('gr.found', {'n': items.length}),
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        ),
      if (enabled.isEmpty)
        emptyText(t('gr.no_sources'))
      else if (items.isEmpty && showEmpty)
        emptyText(t('gr.empty')),
    ];

    return Column(
      children: [
        searchField(t('gr.search.funded'), _search),
        sourceChips(),
        Expanded(
          child: !searched
              ? _intro()
              : RefreshIndicator(
                  onRefresh: refresh,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: header.length + items.length,
                    itemBuilder: (ctx, i) {
                      if (i < header.length) return header[i];
                      final p = items[i - header.length];
                      return FundedProjectCard(
                        project: p,
                        onTap: () => showFundedProjectSheet(context, p),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
