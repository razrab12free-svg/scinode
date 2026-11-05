import 'package:flutter/material.dart';

import '../models/taxonomy.dart';
import '../services/openalex_service.dart';
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

  @override
  void initState() {
    super.initState();
    _sel = List<TagRef>.of(widget.selected);
    _load();
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
    final open = _open;
    if (open == null) {
      return ListView.builder(
        itemCount: tax.fields.length,
        itemBuilder: (_, i) {
          final f = tax.fields[i];
          final n = _countIn(f);
          return ListTile(
            title: Text(localFieldName(f.name)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (n > 0)
                  CircleAvatar(
                      radius: 11,
                      child: Text('$n', style: const TextStyle(fontSize: 12))),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => setState(() => _open = f),
          );
        },
      );
    }
    final subs = tax.subfields[open.id] ?? const <SciSubfield>[];
    final fieldTag = TagRef(tag: 'f${open.id}', name: open.name);
    Widget tile({
      required String title,
      required bool selected,
      required VoidCallback onTap,
      bool bold = false,
    }) {
      return ListTile(
        leading: widget.multi
            ? Icon(selected ? Icons.check_box : Icons.check_box_outline_blank)
            : null,
        title: Text(
          title,
          style: TextStyle(fontWeight: bold ? FontWeight.w800 : null),
        ),
        trailing: (!widget.multi && selected) ? const Icon(Icons.check) : null,
        onTap: onTap,
      );
    }

    return ListView(
      children: [
        tile(
          title: t('tax.all_in', {'name': localFieldName(open.name)}),
          selected: _has(fieldTag.tag),
          bold: true,
          onTap: () => _tap(fieldTag),
        ),
        for (final s in subs)
          tile(
            title: s.name,
            selected: _has('s${s.id}'),
            onTap: () => _tap(TagRef(tag: 's${s.id}', name: s.name)),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(t('tax.hint_en'), style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return SizedBox(
      height: mq.size.height * 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 16, 4),
            child: Row(
              children: [
                if (_open != null)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(() => _open = null),
                  )
                else
                  const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _open == null
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
