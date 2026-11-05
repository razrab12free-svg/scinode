import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../models/taxonomy.dart';
import '../services/orcid_service.dart';
import '../strings.dart';

/// Что из найденного по ORCID человек решил подставить в профиль.
class OrcidChoice {
  bool name = true;
  bool org = true;
  bool country = true;
  bool bio = true;
  bool author = true;
  bool tags = true;
}

/// Направления автора OpenAlex, которых ещё нет в профиле (всего не больше 5).
List<TagRef> newTagsFrom(OrcidLookup r, List<TagRef> current) {
  final out = <TagRef>[];
  for (final x in r.author?.subfieldTags ?? const <TagRef>[]) {
    if (current.length + out.length >= 5) break;
    if (!current.any((e) => e.tag == x.tag) &&
        !out.any((e) => e.tag == x.tag)) {
      out.add(x);
    }
  }
  return out;
}

/// Подставляет выбранное в профиль. Пустые значения ничего не стирают.
void applyOrcid(UserProfile p, OrcidLookup r, OrcidChoice c) {
  p.orcid = r.orcid;
  if (c.name && r.name.isNotEmpty) p.name = r.name;
  if (c.org && r.org.isNotEmpty) p.org = r.org;
  if (c.country && r.country.isNotEmpty) p.country = r.country;
  if (c.bio && r.bio.isNotEmpty) {
    p.bio = r.bio.length > 400 ? '${r.bio.substring(0, 399)}…' : r.bio;
  }
  final a = r.author;
  if (c.author && a != null) {
    p.oaId = a.id;
    p.oaName = a.name;
  }
  if (c.tags) p.tags = [...p.tags, ...newTagsFrom(r, p.tags)];
}

/// Окно предпросмотра: что нашлось и что подставить.
Future<OrcidChoice?> showOrcidFillSheet(
  BuildContext context,
  OrcidLookup r,
  UserProfile current,
) {
  return showModalBottomSheet<OrcidChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _OrcidSheet(r: r, current: current),
  );
}

class _OrcidSheet extends StatefulWidget {
  const _OrcidSheet({required this.r, required this.current});
  final OrcidLookup r;
  final UserProfile current;

  @override
  State<_OrcidSheet> createState() => _OrcidSheetState();
}

class _OrcidSheetState extends State<_OrcidSheet> {
  late final OrcidChoice _c = OrcidChoice()
    // Свой текст «О себе» без спроса не заменяем.
    ..bio = widget.current.bio.trim().isEmpty;

  Widget _row(String label, String value, bool on, ValueChanged<bool> set) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: on,
      onChanged: (v) => setState(() => set(v ?? false)),
      title: Text(label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      subtitle: Text(value,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final a = r.author;
    final tags = newTagsFrom(r, widget.current.tags);
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('orc.found_title'),
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('ORCID ${r.orcid}', style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          if (r.name.isNotEmpty)
            _row(t('me.name'), r.name, _c.name, (v) => _c.name = v),
          if (r.org.isNotEmpty)
            _row(t('me.org'), r.org, _c.org, (v) => _c.org = v),
          if (r.country.isNotEmpty)
            _row(t('me.country'), countryName(r.country), _c.country,
                (v) => _c.country = v),
          if (r.bio.isNotEmpty)
            _row(t('orc.bio'), r.bio, _c.bio, (v) => _c.bio = v),
          if (a != null)
            _row(
              t('me.claim_title'),
              t('orc.author', {'name': a.name, 'n': a.works}),
              _c.author,
              (v) => _c.author = v,
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(t('orc.no_author'),
                  style:
                      TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            ),
          if (tags.isNotEmpty)
            _row(t('orc.tags'), tags.map((e) => e.label).join(' · '), _c.tags,
                (v) => _c.tags = v),
          const SizedBox(height: 8),
          Text(t('orc.check_note'),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('orc.apply'),
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: () => Navigator.pop(context, _c),
            icon: const Icon(Icons.download_done),
            label: Text(t('orc.apply')),
          ),
          const SizedBox(height: 8),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () => Navigator.pop(context),
            child: Text(t('bd.cancel')),
          ),
        ],
      ),
    );
  }
}
