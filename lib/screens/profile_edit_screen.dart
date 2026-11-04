import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../models/scientist.dart';
import '../models/taxonomy.dart';
import '../services/openalex_service.dart';
import '../services/profile_service.dart';
import '../services/scientist_service.dart';
import '../auth_service.dart';
import '../strings.dart';
import '../widgets/scientist_card.dart';
import '../widgets/taxonomy_picker.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _org;
  late final TextEditingController _bio;
  late final TextEditingController _orcid;
  late UserProfile _p;
  bool _saving = false;
  bool _filling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final mine = ProfileService.instance.mine;
    final u = AuthService.instance.user;
    _p = mine != null
        ? mine.copy()
        : UserProfile(name: (u?.displayName ?? '').trim());
    _name = TextEditingController(text: _p.name);
    _org = TextEditingController(text: _p.org);
    _bio = TextEditingController(text: _p.bio);
    _orcid = TextEditingController(text: _p.orcid);
  }

  @override
  void dispose() {
    _name.dispose();
    _org.dispose();
    _bio.dispose();
    _orcid.dispose();
    super.dispose();
  }

  Future<void> _addTags() async {
    final r = await pickTags(context, multi: true, selected: _p.tags, max: 5);
    if (r != null) setState(() => _p.tags = r);
  }

  Future<void> _pickCountry() async {
    final r = await pickCountry(context, selected: _p.country);
    if (r != null) setState(() => _p.country = r);
  }

  Future<void> _claim() async {
    final s = await showModalBottomSheet<Scientist>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _ClaimSheet(initial: _name.text.trim()),
    );
    if (s != null) {
      setState(() {
        _p.oaId = s.id;
        _p.oaName = s.name;
      });
    }
  }

  Future<void> _fill() async {
    setState(() {
      _filling = true;
      _error = null;
    });
    try {
      final s = await ScientistService.instance.getAuthor(_p.oaId);
      final merged = List<TagRef>.of(_p.tags);
      for (final x in s.subfieldTags) {
        if (merged.length >= 5) break;
        if (!merged.any((e) => e.tag == x.tag)) merged.add(x);
      }
      if (!mounted) return;
      setState(() {
        _p.tags = merged;
        _filling = false;
      });
    } on SearchException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = t('search.err.${e.kind}');
        _filling = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = t('search.err.other');
        _filling = false;
      });
    }
  }

  Future<void> _save() async {
    _p.name = _name.text.trim();
    _p.org = _org.text.trim();
    _p.bio = _bio.text.trim();
    _p.orcid = _orcid.text.trim();
    if (_p.name.isEmpty) {
      setState(() => _error = t('me.name_required'));
      return;
    }
    if (_p.orcid.isNotEmpty &&
        !RegExp(r'^\d{4}-\d{4}-\d{4}-\d{3}[\dX]$').hasMatch(_p.orcid)) {
      setState(() => _error = t('me.orcid_bad'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final err = await ProfileService.instance.save(_p);
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.pop(context, _p.published ? t('me.published') : t('me.saved'));
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      );

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    return Scaffold(
      appBar: AppBar(title: Text(t('me.title'))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + bottom),
        children: [
          _label(t('me.name')),
          TextField(controller: _name, maxLength: 80, decoration: _dec('')),
          _label(t('me.role')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in profileRoles)
                ChoiceChip(
                  label: Text(t('role.$r')),
                  selected: _p.role == r,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _p.role = r),
                ),
            ],
          ),
          _label(t('me.org')),
          TextField(controller: _org, maxLength: 120, decoration: _dec('')),
          _label(t('me.country')),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              alignment: Alignment.centerLeft,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _pickCountry,
            child: Row(
              children: [
                const Icon(Icons.public),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_p.country.isEmpty
                      ? t('net.country.any')
                      : countryName(_p.country)),
                ),
              ],
            ),
          ),
          _label(t('me.bio')),
          TextField(
            controller: _bio,
            maxLength: 400,
            maxLines: 4,
            decoration: _dec(''),
          ),
          _label(t('me.orcid')),
          TextField(controller: _orcid, maxLength: 19, decoration: _dec('0000-0000-0000-0000')),
          _label(t('me.interests')),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final x in _p.tags)
                InputChip(
                  label: Text(x.label),
                  onDeleted: () => setState(
                      () => _p.tags.removeWhere((e) => e.tag == x.tag)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _addTags,
            icon: const Icon(Icons.add),
            label: Text(t('me.interests_add')),
          ),
          _label(t('me.claim_title')),
          if (_p.oaId.isEmpty) ...[
            Text(t('me.claim_hint'), style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _claim,
              icon: const Icon(Icons.link),
              label: Text(t('me.claim_btn')),
            ),
          ] else ...[
            Text(t('me.claimed', {'name': _p.oaName}),
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: _filling ? null : _fill,
              icon: _filling
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(t('me.fill')),
            ),
            TextButton(
              onPressed: () => setState(() {
                _p.oaId = '';
                _p.oaName = '';
              }),
              child: Text(t('me.unlink')),
            ),
          ],
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            color: scheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(t('me.publish'),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    value: _p.published,
                    onChanged: (v) => setState(() => _p.published = v),
                  ),
                  Text(t('me.publish_note'),
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(color: scheme.error, fontSize: 14)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Text(t('me.save')),
          ),
        ],
      ),
    );
  }
}

class _ClaimSheet extends StatefulWidget {
  const _ClaimSheet({required this.initial});
  final String initial;

  @override
  State<_ClaimSheet> createState() => _ClaimSheetState();
}

class _ClaimSheetState extends State<_ClaimSheet> {
  late final TextEditingController _q;
  List<Scientist> _res = [];
  bool _loading = false;
  bool _searched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _q = TextEditingController(text: widget.initial);
    if (widget.initial.isNotEmpty) _run();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final q = _q.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
    });
    try {
      final r = await ScientistService.instance.searchByName(q);
      if (!mounted) return;
      setState(() {
        _res = r;
        _loading = false;
      });
    } on SearchException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = t('search.err.${e.kind}');
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = t('search.err.other');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SizedBox(
        height: mq.size.height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _q,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _run(),
                decoration: InputDecoration(
                  hintText: t('me.claim_search'),
                  prefixIcon: const Icon(Icons.person_search),
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
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : (_searched && _res.isEmpty)
                          ? Center(child: Text(t('net.empty')))
                          : ListView.builder(
                              padding: EdgeInsets.only(
                                  bottom: mq.viewPadding.bottom + 16),
                              itemCount: _res.length,
                              itemBuilder: (_, i) => ScientistCard(
                                s: _res[i],
                                onTap: () => Navigator.pop(context, _res[i]),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
