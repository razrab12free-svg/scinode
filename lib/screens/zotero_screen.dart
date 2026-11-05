import 'package:flutter/material.dart';

import '../models/paper.dart';
import '../models/zotero.dart';
import '../services/library_service.dart';
import '../services/zotero_service.dart';
import '../strings.dart';
import '../utils.dart';

/// Цвет-акцент раздела Zotero (тёплый красный, свой для приложения).
const zoteroAccent = Color(0xFFC2410C);

String zoteroError(Object e) =>
    t('zt.err.${e is ZoteroException ? e.kind : 'network'}');

/// Zotero: подключение по ключу, импорт и экспорт статей.
class ZoteroScreen extends StatefulWidget {
  const ZoteroScreen({super.key, this.service});
  final ZoteroService? service;

  @override
  State<ZoteroScreen> createState() => _ZoteroScreenState();
}

class _ZoteroScreenState extends State<ZoteroScreen> {
  late final ZoteroService _svc = widget.service ?? ZoteroService.instance;
  final TextEditingController _key = TextEditingController();
  bool _busy = false;
  bool _show = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _svc.ensureLoaded();
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _svc.connect(_key.text);
      _key.clear();
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(t('zt.connected_ok'))));
      }
    } catch (e) {
      if (mounted) setState(() => _error = zoteroError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _disconnect() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(t('zt.disconnect')),
        content: Text(t('zt.disconnect_q')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: Text(t('bd.cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
            onPressed: () => Navigator.pop(d, true),
            child: Text(t('zt.disconnect_do')),
          ),
        ],
      ),
    );
    if (ok == true) await _svc.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('zt.title'))),
      body: ListenableBuilder(
        listenable: _svc,
        builder: (ctx, _) {
          if (!_svc.loaded) {
            return const Center(child: CircularProgressIndicator());
          }
          final a = _svc.account;
          return a == null ? _connectView() : _connectedView(a);
        },
      ),
    );
  }

  // --------------------------------------------------------- не подключено

  Widget _connectView() {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    Widget step(int n, String text, {Widget? action}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: zoteroAccent.withAlpha(36),
                child: Text('$n',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: zoteroAccent)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(text, style: const TextStyle(height: 1.35)),
                    ),
                    if (action != null) action,
                  ],
                ),
              ),
            ],
          ),
        );
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottom),
      children: [
        _Hero(
          icon: Icons.sync_alt,
          title: t('zt.hero_title'),
          text: t('zt.hero_text'),
        ),
        const SizedBox(height: 20),
        Text(t('zt.how'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        step(1, t('zt.step1')),
        step(
          2,
          t('zt.step2'),
          action: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  foregroundColor: zoteroAccent),
              onPressed: () => openLink(context, ZoteroService.keysUrl),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('zotero.org/settings/keys'),
            ),
          ),
        ),
        step(3, t('zt.step3')),
        step(4, t('zt.step4')),
        const SizedBox(height: 8),
        TextField(
          controller: _key,
          obscureText: !_show,
          autocorrect: false,
          enableSuggestions: false,
          onSubmitted: (_) => _busy ? null : _connect(),
          decoration: InputDecoration(
            labelText: t('zt.key'),
            hintText: t('zt.key_hint'),
            errorText: _error,
            errorMaxLines: 3,
            prefixIcon: const Icon(Icons.key_outlined),
            suffixIcon: IconButton(
              tooltip: _show ? t('zt.hide') : t('zt.show'),
              icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _show = !_show),
            ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 6),
        Text(t('zt.key_safe'),
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: zoteroAccent, foregroundColor: Colors.white),
          onPressed: _busy ? null : _connect,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.link),
          label: Text(t('zt.connect')),
        ),
        const SizedBox(height: 12),
        Text(t('zt.free'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
      ],
    );
  }

  // ------------------------------------------------------------ подключено

  Widget _connectedView(ZoteroAccount a) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottom),
      children: [
        Material(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: zoteroAccent.withAlpha(36),
                  child: const Icon(Icons.check, color: zoteroAccent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t('zt.connected'),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      Text(
                        a.username.isEmpty
                            ? 'ID ${a.userId}'
                            : '${a.username} · ID ${a.userId}',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        a.canWrite ? t('zt.rw') : t('zt.ro'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: a.canWrite ? const Color(0xFF16A34A) : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _ActionTile(
          icon: Icons.download_outlined,
          title: t('zt.import'),
          text: t('zt.import_sub'),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => ZoteroImportScreen(service: _svc))),
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.upload_outlined,
          title: t('zt.export'),
          text: a.canWrite ? t('zt.export_sub') : t('zt.export_no_write'),
          onTap: a.canWrite
              ? () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => ZoteroExportScreen(service: _svc)))
              : null,
        ),
        const SizedBox(height: 28),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            foregroundColor: scheme.error,
          ),
          onPressed: _disconnect,
          icon: const Icon(Icons.link_off),
          label: Text(t('zt.disconnect')),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: zoteroAccent.withAlpha(22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: zoteroAccent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(text,
                    style: TextStyle(
                        height: 1.35, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.text,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Opacity(
            opacity: enabled ? 1 : 0.55,
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: zoteroAccent.withAlpha(30),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: zoteroAccent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(text,
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ======================================================= выбор коллекции

/// Выбор коллекции: null в результате — отмена; '' — вся библиотека
/// (или корень при экспорте); '+' — новая коллекция.
Future<String?> pickZoteroCollection(
  BuildContext context,
  List<ZoteroCollection> all, {
  String? current,
  bool allowCreate = false,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) {
      final tree = collectionTree(all);
      final bottom = MediaQuery.of(ctx).viewPadding.bottom;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.94,
        builder: (_, sc) => ListView(
          controller: sc,
          padding: EdgeInsets.only(bottom: 16 + bottom),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(t('zt.choose_collection'),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            if (allowCreate)
              ListTile(
                minTileHeight: 56,
                leading: const Icon(Icons.create_new_folder_outlined,
                    color: zoteroAccent),
                title: Text(t('zt.new_collection')),
                onTap: () => Navigator.pop(ctx, '+'),
              ),
            ListTile(
              minTileHeight: 56,
              leading: Icon(current == null || current.isEmpty
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked),
              title: Text(allowCreate ? t('zt.root') : t('zt.all')),
              onTap: () => Navigator.pop(ctx, ''),
            ),
            for (final (c, depth) in tree)
              ListTile(
                minTileHeight: 52,
                contentPadding:
                    EdgeInsets.only(left: 16.0 + 20 * depth, right: 16),
                leading: Icon(current == c.key
                    ? Icons.radio_button_checked
                    : Icons.folder_outlined),
                title:
                    Text(c.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: c.items > 0 ? Text('${c.items}') : null,
                onTap: () => Navigator.pop(ctx, c.key),
              ),
          ],
        ),
      );
    },
  );
}

// =============================================================== импорт

class ZoteroImportScreen extends StatefulWidget {
  const ZoteroImportScreen({super.key, required this.service});
  final ZoteroService service;

  @override
  State<ZoteroImportScreen> createState() => _ZoteroImportScreenState();
}

class _ZoteroImportScreenState extends State<ZoteroImportScreen> {
  ZoteroService get _svc => widget.service;
  List<ZoteroCollection> _collections = const [];
  String _collection = '';
  List<ZoteroItem>? _items;
  Object? _error;
  final Set<String> _picked = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    LibraryService.instance.ensureLoaded();
    _load();
    _svc.collections().then((c) {
      if (mounted) setState(() => _collections = c);
    }, onError: (_) {});
  }

  Future<void> _load() async {
    setState(() {
      _items = null;
      _error = null;
      _picked.clear();
    });
    try {
      final list = await _svc.items(
          collection: _collection.isEmpty ? null : _collection);
      if (mounted) setState(() => _items = list);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  String get _collectionName {
    if (_collection.isEmpty) return t('zt.all');
    for (final c in _collections) {
      if (c.key == _collection) return c.name;
    }
    return t('zt.all');
  }

  Future<void> _chooseCollection() async {
    final k =
        await pickZoteroCollection(context, _collections, current: _collection);
    if (k == null || k == _collection || !mounted) return;
    _collection = k;
    _load();
  }

  bool _can(ZoteroItem z, List<Paper> lib) =>
      z.hasDoi && !inLibrary(z, lib, _svc.account!.userId);

  Future<void> _import(List<Paper> lib) async {
    final items = _items ?? const <ZoteroItem>[];
    final uid = _svc.account!.userId;
    setState(() => _saving = true);
    var n = 0;
    for (final z in items.reversed) {
      if (!_picked.contains(z.key) || !_can(z, lib)) continue;
      await LibraryService.instance.add(z.toPaper(uid));
      n++;
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _picked.clear();
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t('zt.imported', {'n': n}))));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: LibraryService.instance,
      builder: (ctx, _) {
        final lib = LibraryService.instance.items;
        final items = _items;
        final ready = items == null
            ? const <ZoteroItem>[]
            : [
                for (final z in items)
                  if (_can(z, lib)) z
              ];
        final allPicked =
            ready.isNotEmpty && ready.every((z) => _picked.contains(z.key));
        final count = ready.where((z) => _picked.contains(z.key)).length;
        return Scaffold(
          appBar: AppBar(title: Text(t('zt.import'))),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: ActionChip(
                        avatar: const Icon(Icons.folder_outlined, size: 18),
                        label: Text(_collectionName,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        onPressed: _chooseCollection,
                      ),
                    ),
                    if (ready.isNotEmpty)
                      TextButton(
                        style: TextButton.styleFrom(
                            minimumSize: const Size(0, 48)),
                        onPressed: () => setState(() {
                          if (allPicked) {
                            _picked.clear();
                          } else {
                            _picked.addAll(ready.map((z) => z.key));
                          }
                        }),
                        child: Text(allPicked
                            ? t('zt.pick_none')
                            : t('zt.pick_all', {'n': ready.length})),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: _error != null
                    ? _Message(
                        icon: Icons.cloud_off,
                        text: zoteroError(_error!),
                        action: FilledButton.tonal(
                          onPressed: _load,
                          child: Text(t('zt.retry')),
                        ),
                      )
                    : items == null
                        ? _Message(
                            icon: Icons.downloading,
                            text: t('zt.loading'),
                            busy: true)
                        : items.isEmpty
                            ? _Message(
                                icon: Icons.inbox_outlined, text: t('zt.empty'))
                            : RefreshIndicator(
                                onRefresh: _load,
                                child: ListView.separated(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 4, 16, 16),
                                  itemCount: items.length + 1,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (_, i) {
                                    if (i == items.length) {
                                      return Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Text(
                                          t('zt.summary', {
                                            'n': items.length,
                                            'd': items
                                                .where((z) => z.hasDoi)
                                                .length,
                                          }),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: scheme.onSurfaceVariant),
                                        ),
                                      );
                                    }
                                    final z = items[i];
                                    final state = !z.hasDoi
                                        ? _ItemState.noDoi
                                        : inLibrary(
                                                z, lib, _svc.account!.userId)
                                            ? _ItemState.inLibrary
                                            : _ItemState.ready;
                                    return _ZoteroItemCard(
                                      title: z.title,
                                      authors: z.authors,
                                      year: z.year,
                                      venue: z.venue,
                                      doi: z.doi,
                                      state: state,
                                      picked: _picked.contains(z.key),
                                      onTap: state == _ItemState.ready
                                          ? () => setState(() =>
                                              _picked.contains(z.key)
                                                  ? _picked.remove(z.key)
                                                  : _picked.add(z.key))
                                          : null,
                                    );
                                  },
                                ),
                              ),
              ),
            ],
          ),
          bottomNavigationBar: count == 0
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: zoteroAccent,
                          foregroundColor: Colors.white),
                      onPressed: _saving ? null : () => _import(lib),
                      icon: const Icon(Icons.download),
                      label: Text(t('zt.import_do', {'n': count})),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

enum _ItemState { ready, inLibrary, inZotero, noDoi }

class _ZoteroItemCard extends StatelessWidget {
  const _ZoteroItemCard({
    required this.title,
    required this.authors,
    required this.year,
    required this.venue,
    required this.doi,
    required this.state,
    required this.picked,
    this.onTap,
  });
  final String title;
  final List<String> authors;
  final int? year;
  final String venue;
  final String? doi;
  final _ItemState state;
  final bool picked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = state == _ItemState.ready;
    final muted = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);
    final authorLine = authors.isEmpty
        ? ''
        : authors.length <= 3
            ? authors.join(', ')
            : '${authors.take(3).join(', ')} …';
    final meta = [if (year != null) '$year', if (venue.isNotEmpty) venue];
    final (badgeIcon, badgeText, badgeColor) = switch (state) {
      _ItemState.inLibrary => (
          Icons.check_circle,
          t('zt.in_library'),
          const Color(0xFF16A34A)
        ),
      _ItemState.inZotero => (
          Icons.check_circle,
          t('zt.in_zotero'),
          const Color(0xFF16A34A)
        ),
      _ItemState.noDoi => (Icons.block, t('zt.no_doi'), scheme.outline),
      _ItemState.ready => (null, '', scheme.primary),
    };
    return Material(
      color: picked ? zoteroAccent.withAlpha(28) : scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: state == _ItemState.noDoi ? 0.5 : 1,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: active
                      ? Checkbox(
                          value: picked,
                          activeColor: zoteroAccent,
                          onChanged: (_) => onTap?.call(),
                        )
                      : Icon(badgeIcon, color: badgeColor),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      if (authorLine.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(authorLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: muted),
                      ],
                      if (meta.isNotEmpty)
                        Text(meta.join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: muted),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (doi != null)
                            _Tag(text: 'DOI $doi', color: scheme.primary),
                          if (badgeText.isNotEmpty)
                            _Tag(text: badgeText, color: badgeColor),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withAlpha(28),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );
}

class _Message extends StatelessWidget {
  const _Message(
      {required this.icon, required this.text, this.action, this.busy = false});
  final IconData icon;
  final String text;
  final Widget? action;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            busy
                ? const CircularProgressIndicator()
                : Icon(icon, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant)),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

// =============================================================== экспорт

class ZoteroExportScreen extends StatefulWidget {
  const ZoteroExportScreen({super.key, required this.service});
  final ZoteroService service;

  @override
  State<ZoteroExportScreen> createState() => _ZoteroExportScreenState();
}

class _ZoteroExportScreenState extends State<ZoteroExportScreen> {
  ZoteroService get _svc => widget.service;
  List<ZoteroCollection> _collections = const [];
  String _collection = '';
  Set<String>? _have;
  Object? _error;
  final Set<String> _picked = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    LibraryService.instance.ensureLoaded();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _have = null;
    });
    try {
      final r = await Future.wait([
        _svc.libraryDois(refresh: true),
        _svc.collections(),
      ]);
      if (!mounted) return;
      setState(() {
        _have = r[0] as Set<String>;
        _collections = r[1] as List<ZoteroCollection>;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  String get _collectionName {
    if (_collection.isEmpty) return t('zt.root');
    for (final c in _collections) {
      if (c.key == _collection) return c.name;
    }
    return t('zt.root');
  }

  Future<void> _chooseCollection() async {
    final k = await pickZoteroCollection(context, _collections,
        current: _collection, allowCreate: true);
    if (k == null || !mounted) return;
    if (k != '+') {
      setState(() => _collection = k);
      return;
    }
    final name = await _askName();
    if (name == null || !mounted) return;
    try {
      final key = await _svc.createCollection(name);
      if (!mounted) return;
      setState(() {
        _collections = [
          ..._collections,
          ZoteroCollection(key: key, name: name),
        ];
        _collection = key;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(zoteroError(e))));
      }
    }
  }

  Future<String?> _askName() {
    final c = TextEditingController(text: 'Scinode');
    return showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(t('zt.new_collection')),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: 100,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d), child: Text(t('bd.cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
            onPressed: () {
              final v = c.text.trim();
              if (v.isNotEmpty) Navigator.pop(d, v);
            },
            child: Text(t('bd.create')),
          ),
        ],
      ),
    ).whenComplete(c.dispose);
  }

  bool _inZotero(Paper p) {
    final d = normDoi(p.doi);
    return d != null && (_have?.contains(d) ?? false);
  }

  Future<void> _send(List<Paper> lib) async {
    final papers = [
      for (final p in lib)
        if (_picked.contains(p.id) && !_inZotero(p)) p
    ];
    setState(() => _saving = true);
    try {
      final r = await _svc.export(papers,
          collection: _collection.isEmpty ? null : _collection);
      if (!mounted) return;
      setState(() {
        _picked.clear();
        _have = {
          ..._have ?? {},
          for (final p in papers)
            if (normDoi(p.doi) != null) normDoi(p.doi)!,
        };
      });
      await showDialog<void>(
        context: context,
        builder: (d) => AlertDialog(
          icon: Icon(
            r.failed.isEmpty ? Icons.check_circle : Icons.warning_amber,
            color: r.failed.isEmpty ? const Color(0xFF16A34A) : null,
          ),
          title: Text(t('zt.export_done')),
          content: Text([
            t('zt.export_created', {'n': r.created}),
            if (r.skipped > 0) t('zt.export_skipped', {'n': r.skipped}),
            if (r.failed.isNotEmpty)
              '${t('zt.export_failed', {'n': r.failed.length})}\n'
                  '${r.failed.take(5).join('\n')}',
          ].join('\n')),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
              onPressed: () => Navigator.pop(d),
              child: Text(t('bd.ok')),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(zoteroError(e))));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LibraryService.instance,
      builder: (ctx, _) {
        final lib = LibraryService.instance.items;
        final ready = [
          for (final p in lib)
            if (!_inZotero(p)) p
        ];
        final count = ready.where((p) => _picked.contains(p.id)).length;
        final allPicked =
            ready.isNotEmpty && ready.every((p) => _picked.contains(p.id));
        Widget body;
        if (_error != null) {
          body = _Message(
            icon: Icons.cloud_off,
            text: zoteroError(_error!),
            action: FilledButton.tonal(
                onPressed: _load, child: Text(t('zt.retry'))),
          );
        } else if (_have == null) {
          body = _Message(
              icon: Icons.downloading, text: t('zt.checking'), busy: true);
        } else if (lib.isEmpty) {
          body = _Message(
              icon: Icons.bookmark_border, text: t('zt.library_empty'));
        } else {
          body = ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            itemCount: lib.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final p = lib[i];
              final inZ = _inZotero(p);
              return _ZoteroItemCard(
                title: p.title,
                authors: p.authors,
                year: p.year,
                venue: p.venue,
                doi: normDoi(p.doi),
                state: inZ ? _ItemState.inZotero : _ItemState.ready,
                picked: _picked.contains(p.id),
                onTap: inZ
                    ? null
                    : () => setState(() => _picked.contains(p.id)
                        ? _picked.remove(p.id)
                        : _picked.add(p.id)),
              );
            },
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(t('zt.export'))),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: ActionChip(
                        avatar: const Icon(Icons.folder_outlined, size: 18),
                        label: Text('${t('zt.to')}: $_collectionName',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        onPressed: _have == null ? null : _chooseCollection,
                      ),
                    ),
                    if (ready.isNotEmpty && _have != null)
                      TextButton(
                        style: TextButton.styleFrom(
                            minimumSize: const Size(0, 48)),
                        onPressed: () => setState(() {
                          if (allPicked) {
                            _picked.clear();
                          } else {
                            _picked.addAll(ready.map((p) => p.id));
                          }
                        }),
                        child: Text(allPicked
                            ? t('zt.pick_none')
                            : t('zt.pick_all', {'n': ready.length})),
                      ),
                  ],
                ),
              ),
              Expanded(child: body),
            ],
          ),
          bottomNavigationBar: count == 0
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: zoteroAccent,
                          foregroundColor: Colors.white),
                      onPressed: _saving ? null : () => _send(lib),
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.upload),
                      label: Text(t('zt.export_do', {'n': count})),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
