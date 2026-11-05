import 'package:flutter/material.dart';

import '../models/taxonomy.dart';
import '../services/taxonomy_service.dart';
import '../strings.dart';
import '../strings_science.dart';

/// Выбор направлений науки. В режиме [multi] можно выбрать до [max].
Future<List<TagRef>?> pickTags(
  BuildContext context, {
  required bool multi,
  List<TagRef> selected = const [],
  int max = 5,
}) {
  return showModalBottomSheet<List<TagRef>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _TaxSheet(multi: multi, selected: selected, max: max),
  );
}

/// Выбор страны. Возвращает код, пустую строку («весь мир») или null.
Future<String?> pickCountry(BuildContext context, {String selected = ''}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) {
      final bottom = MediaQuery.of(ctx).viewPadding.bottom;
      return ListView(
        shrinkWrap: true,
        padding: EdgeInsets.only(bottom: bottom + 16),
        children: [
          ListTile(
            leading: const Icon(Icons.public),
            title: Text(t('net.country.any')),
            trailing: selected.isEmpty ? const Icon(Icons.check) : null,
            onTap: () => Navigator.pop(ctx, ''),
          ),
          for (final c in countryList)
            ListTile(
              title: Text(countryName(c.$1)),
              trailing: selected == c.$1 ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, c.$1),
            ),
        ],
      );
    },
  );
}

class _TaxSheet extends StatefulWidget {
  const _TaxSheet({
    required this.multi,
    required this.selected,
    required this.max,
  });
  final bool multi;
  final List<TagRef> selected;
  final int max;

  @override
  State<_TaxSheet> createState() => _TaxSheetState();
}

class _TaxSheetState extends State<_TaxSheet> {
  Taxonomy? _tax;
  bool _loading = true;
  String? _error;
  SciField? _open;
  late List<TagRef> _sel;
  String? _note;
  final TextEditingController _q = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sel = List<TagRef>.of(widget.selected);
    _q.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tx = await TaxonomyService.instance.load();
      if (!mounted) return;
      setState(() {
        _tax = tx;
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

  bool _has(String tag) => _sel.any((e) => e.tag == tag);

  void _tap(TagRef tag) {
    if (!widget.multi) {
      Navigator.pop(context, [tag]);
      return;
    }
    setState(() {
      _note = null;
      if (_has(tag.tag)) {
        _sel.removeWhere((e) => e.tag == tag.tag);
      } else if (_sel.length >= widget.max) {
        _note = t('me.limit');
      } else {
        _sel.add(tag);
      }
    });
  }

  int _countIn(SciField f) {
    final subs = _tax?.subfields[f.id] ?? const <SciSubfield>[];
    return _sel
        .where(
            (e) => e.tag == 'f${f.id}' || subs.any((s) => 's${s.id}' == e.tag))
        .length;
  }

  Widget _tile({
    required String title,
    String? subtitle,
    required bool selected,
    required VoidCallback onTap,
    bool bold = false,
  }) {
    return ListTile(
      minTileHeight: 52,
      leading: widget.multi
          ? Icon(selected ? Icons.check_box : Icons.check_box_outline_blank)
          : null,
      title: Text(
        title,
        style: TextStyle(fontWeight: bold ? FontWeight.w800 : null),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: (!widget.multi && selected) ? const Icon(Icons.check) : null,
      onTap: onTap,
    );
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Text(text.toUpperCase(),
            style: TextStyle(
                fontSize: 12,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.primary)),
      );

  Widget _results(Taxonomy tax) {
    final hits = searchTaxonomy(tax, _q.text);
    if (hits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(t('tax.no_results'), textAlign: TextAlign.center),
        ),
      );
    }
    return ListView(
      children: [
        for (final h in hits)
          _tile(
            title: h.topic == null ? h.tag.label : h.topic!.name,
            subtitle: h.topic != null
                ? t('tax.topic_in', {'name': h.tag.label})
                : (h.tag.isField
                    ? t('tax.field')
                    : localFieldName(tax
                            .field(tax.subfield(h.tag.rawId)?.fieldId ?? '')
                            ?.name ??
                        '')),
            selected: _has(h.tag.tag),
            onTap: () => _tap(h.tag),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(t('tax.hint_en'), style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _tax == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t('search.err.${_error ?? 'other'}'),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
                onPressed: _load,
                child: Text(t('search.retry')),
              ),
            ],
          ),
        ),
      );
    }
    final tax = _tax!;
    if (_q.text.trim().length >= 2) return _results(tax);
    final open = _open;
    if (open == null) {
      final byDomain = <String, List<SciField>>{};
      for (final f in tax.fields) {
        byDomain.putIfAbsent(tax.fieldDomain[f.id] ?? '', () => []).add(f);
      }
      final domains = [
        ...tax.domains.map((d) => d.id),
        if (byDomain.containsKey('')) '',
      ];
      return ListView(
        children: [
          for (final d in domains)
            if (byDomain[d] != null) ...[
              if (d.isNotEmpty) _header(t('tax.d.$d')),
              for (final f in byDomain[d]!)
                ListTile(
                  minTileHeight: 52,
                  title: Text(localFieldName(f.name)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_countIn(f) > 0)
                        CircleAvatar(
                            radius: 11,
                            child: Text('${_countIn(f)}',
                                style: const TextStyle(fontSize: 12))),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => setState(() => _open = f),
                ),
            ],
        ],
      );
    }
    final subs = tax.subfields[open.id] ?? const <SciSubfield>[];
    final fieldTag = TagRef(tag: 'f${open.id}', name: open.name);
    return ListView(
      children: [
        _tile(
          title: t('tax.all_in', {'name': localFieldName(open.name)}),
          selected: _has(fieldTag.tag),
          bold: true,
          onTap: () => _tap(fieldTag),
        ),
        for (final s in subs)
          _tile(
            title: localSubfieldName(s.id, s.name),
            selected: _has('s${s.id}'),
            onTap: () => _tap(TagRef(tag: 's${s.id}', name: s.name)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final searching = _q.text.trim().length >= 2;
    return SizedBox(
      height: mq.size.height * 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 16, 4),
            child: Row(
              children: [
                if (_open != null && !searching)
                  IconButton(
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(() => _open = null),
                  )
                else
                  const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _open == null || searching
                        ? t('tax.title')
                        : localFieldName(_open!.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: TextField(
              controller: _q,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: t('tax.search'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _q.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: MaterialLocalizations.of(context)
                            .deleteButtonTooltip,
                        icon: const Icon(Icons.clear),
                        onPressed: _q.clear,
                      ),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(child: _body()),
          if (_note != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_note!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13)),
            ),
          if (widget.multi)
            Padding(
              padding:
                  EdgeInsets.fromLTRB(16, 8, 16, 12 + mq.viewPadding.bottom),
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _sel),
                child: Text(t('tax.done')),
              ),
            )
          else
            SizedBox(height: mq.viewPadding.bottom + 8),
        ],
      ),
    );
  }
}
