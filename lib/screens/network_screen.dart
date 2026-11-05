import 'package:flutter/material.dart';

import '../auth_service.dart';
import '../models/profile.dart';
import '../models/scientist.dart';
import '../models/taxonomy.dart';
import '../services/openalex_service.dart';
import '../services/profile_service.dart';
import '../services/scientist_service.dart';
import '../strings.dart';
import '../widgets/scientist_card.dart';
import '../widgets/taxonomy_picker.dart';

String _errText(String? kind) {
  if (kind == 'need') return t('net.need_input');
  return t('search.err.${kind ?? 'other'}');
}

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key});

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  int _mode = 0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(t('net.title'),
                style:
                    const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 0, label: Text(t('net.seg.topic'))),
                  ButtonSegment(value: 1, label: Text(t('net.seg.name'))),
                  ButtonSegment(value: 2, label: Text(t('net.seg.members'))),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _mode,
              children: [
                const _TopicView(),
                const _NameView(),
                _MembersView(active: _mode == 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.onClear,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        alignment: Alignment.centerLeft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: onTap,
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (onClear != null)
            InkWell(
              onTap: onClear,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 18),
              ),
            ),
        ],
      ),
    );
  }
}

Widget _padded(Widget w) =>
    Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: w);

// ---------- По теме ----------

class _TopicView extends StatefulWidget {
  const _TopicView();

  @override
  State<_TopicView> createState() => _TopicViewState();
}

class _TopicViewState extends State<_TopicView> {
  final TextEditingController _kw = TextEditingController();
  TagRef? _tag;
  String _country = '';
  bool _recent = true;
  List<Scientist> _res = [];
  bool _loading = false;
  bool _searched = false;
  String? _error;

  @override
  void dispose() {
    _kw.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final r = await pickTags(
      context,
      multi: false,
      selected: _tag == null ? const [] : [_tag!],
    );
    if (r != null && r.isNotEmpty) setState(() => _tag = r.first);
  }

  Future<void> _pickCountry() async {
    final r = await pickCountry(context, selected: _country);
    if (r != null) setState(() => _country = r);
  }

  Future<void> _run() async {
    final text = _kw.text.trim();
    if (_tag == null && text.isEmpty) {
      setState(() => _error = 'need');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
      _res = [];
    });
    try {
      final r = await ScientistService.instance.expertsByTopic(
        text: text,
        tag: _tag,
        country: _country,
        recent: _recent,
      );
      if (!mounted) return;
      setState(() {
        _res = r;
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        _padded(
            Text(t('net.topic.intro'), style: const TextStyle(fontSize: 14))),
        _padded(_PickerButton(
          icon: Icons.category_outlined,
          label: _tag?.label ?? t('net.any_field'),
          onTap: _pick,
          onClear: _tag == null ? null : () => setState(() => _tag = null),
        )),
        _padded(TextField(
          controller: _kw,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _run(),
          decoration: InputDecoration(
            hintText: t('net.kw.hint'),
            prefixIcon: const Icon(Icons.search),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        )),
        _padded(_PickerButton(
          icon: Icons.public,
          label:
              _country.isEmpty ? t('net.country.any') : countryName(_country),
          onTap: _pickCountry,
          onClear:
              _country.isEmpty ? null : () => setState(() => _country = ''),
        )),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t('net.recent'), style: const TextStyle(fontSize: 14)),
            value: _recent,
            onChanged: (v) => setState(() => _recent = v),
          ),
        ),
        _padded(FilledButton.icon(
          onPressed: _loading ? null : _run,
          icon: const Icon(Icons.search),
          label: Text(t('net.find')),
        )),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(_errText(_error),
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.error, fontSize: 14)),
          )
        else if (_searched && _res.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text(t('net.empty'))),
          )
        else ...[
          if (_res.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(t('net.results', {'n': _res.length}),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          for (final s in _res)
            ScientistCard(s: s, onTap: () => showScientistSheet(context, s)),
        ],
      ],
    );
  }
}

// ---------- По имени ----------

class _NameView extends StatefulWidget {
  const _NameView();

  @override
  State<_NameView> createState() => _NameViewState();
}

class _NameViewState extends State<_NameView> {
  final TextEditingController _q = TextEditingController();
  List<Scientist> _res = [];
  bool _loading = false;
  bool _searched = false;
  String? _error;

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
      _res = [];
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        _padded(
            Text(t('net.name.intro'), style: const TextStyle(fontSize: 14))),
        _padded(TextField(
          controller: _q,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _run(),
          decoration: InputDecoration(
            hintText: t('net.name.hint'),
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
        )),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(_errText(_error),
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.error, fontSize: 14)),
          )
        else if (_searched && _res.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text(t('net.empty'))),
          )
        else
          for (final s in _res)
            ScientistCard(s: s, onTap: () => showScientistSheet(context, s)),
      ],
    );
  }
}

// ---------- Участники Scinode ----------

class _MembersView extends StatefulWidget {
  const _MembersView({required this.active});
  final bool active;

  @override
  State<_MembersView> createState() => _MembersViewState();
}

class _MembersViewState extends State<_MembersView> {
  TagRef? _tag;
  String _country = '';
  List<UserProfile> _res = [];
  bool _loading = false;
  bool _started = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.active) _start();
  }

  @override
  void didUpdateWidget(covariant _MembersView old) {
    super.didUpdateWidget(old);
    if (widget.active && !_started) _start();
  }

  void _start() {
    _started = true;
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await ProfileService.instance
        .searchMembers(tag: _tag?.tag, country: _country);
    if (!mounted) return;
    setState(() {
      _res = r.items;
      _error = r.error;
      _loading = false;
    });
  }

  Future<void> _pick() async {
    final r = await pickTags(
      context,
      multi: false,
      selected: _tag == null ? const [] : [_tag!],
    );
    if (r != null && r.isNotEmpty) {
      setState(() => _tag = r.first);
      _run();
    }
  }

  Future<void> _pickCountry() async {
    final r = await pickCountry(context, selected: _country);
    if (r != null) {
      setState(() => _country = r);
      _run();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final myUid = AuthService.instance.user?.uid;
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        _padded(
            Text(t('net.members.intro'), style: const TextStyle(fontSize: 14))),
        _padded(_PickerButton(
          icon: Icons.category_outlined,
          label: _tag?.label ?? t('net.any_field'),
          onTap: _pick,
          onClear: _tag == null
              ? null
              : () {
                  setState(() => _tag = null);
                  _run();
                },
        )),
        _padded(_PickerButton(
          icon: Icons.public,
          label:
              _country.isEmpty ? t('net.country.any') : countryName(_country),
          onTap: _pickCountry,
          onClear: _country.isEmpty
              ? null
              : () {
                  setState(() => _country = '');
                  _run();
                },
        )),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.error, fontSize: 14)),
                TextButton(
                  onPressed: _run,
                  child: Text(t('search.retry')),
                ),
              ],
            ),
          )
        else if (_res.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(t('net.members.empty'), textAlign: TextAlign.center),
          )
        else
          for (final p in _res)
            MemberCard(
              p: p,
              isMe: p.uid == myUid,
              onTap: () => showMemberSheet(context, p),
            ),
      ],
    );
  }
}
