import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/note.dart';
import '../models/paper.dart';
import '../services/library_service.dart';
import '../services/note_service.dart';
import '../strings.dart';
import '../utils.dart';
import '../widgets/board_widgets.dart' show fireAndReport, confirmDanger;
import '../widgets/grant_card.dart' show dateLabel;
import '../widgets/math_markdown.dart';
import '../widgets/math_toolbar.dart';
import 'card_sheet.dart';
import 'paper_actions.dart';
import 'paper_sheet.dart';

// ------------------------------------------------------------- переходы

Future<void> openNote(BuildContext context, String id,
        {NoteService? service}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => NoteEditorScreen(noteId: id, service: service),
    ));

Future<void> openNewNote(BuildContext context,
        {NotePaper? paper, NoteCard? card, NoteService? service}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) =>
          NoteEditorScreen(paper: paper, card: card, service: service),
    ));

/// Заметки к статье: если их нет — сразу новая, иначе список и «Новая».
Future<void> openPaperNotes(BuildContext context, Paper p,
    {int? page, NoteService? service}) async {
  final svc = service ?? NoteService.instance;
  final link = NotePaper(id: p.id, title: p.title, doi: p.doiShort, page: page);
  if (!svc.available) {
    _toast(context, t('nt.not_ready'));
    return;
  }
  List<Note> all;
  try {
    all = await svc.notes().first.timeout(const Duration(seconds: 5));
  } catch (_) {
    all = const [];
  }
  if (!context.mounted) return;
  final mine = [
    for (final n in all)
      if (n.paper?.id == p.id) n
  ];
  if (mine.isEmpty) return openNewNote(context, paper: link, service: svc);
  final pick = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(t('nt.for_paper'),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ),
          ListTile(
            minTileHeight: 56,
            leading: const Icon(Icons.add),
            title: Text(
                page == null ? t('nt.new') : t('nt.new_page', {'p': page})),
            onTap: () => Navigator.pop(ctx, ''),
          ),
          for (final n in mine)
            ListTile(
              minTileHeight: 56,
              leading: const Icon(Icons.edit_note),
              title: Text(
                  n.displayTitle.isEmpty ? t('nt.untitled') : n.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              subtitle: n.paper?.page == null
                  ? null
                  : Text(t('nt.page', {'p': n.paper!.page!})),
              onTap: () => Navigator.pop(ctx, n.id),
            ),
        ],
      ),
    ),
  );
  if (pick == null || !context.mounted) return;
  if (pick.isEmpty) return openNewNote(context, paper: link, service: svc);
  return openNote(context, pick, service: svc);
}

void _toast(BuildContext context, String text) =>
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));

// --------------------------------------------------------------- список

/// «Заметки»: все мои заметки с формулами.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, this.service});
  final NoteService? service;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  late final NoteService _svc = widget.service ?? NoteService.instance;
  late final Stream<List<Note>>? _notes = _svc.available ? _svc.notes() : null;
  final TextEditingController _q = TextEditingController();
  NoteFilter _filter = NoteFilter.all;

  @override
  void initState() {
    super.initState();
    _q.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = _notes;
    return Scaffold(
      appBar: AppBar(title: Text(t('nt.title'))),
      floatingActionButton: s == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => openNewNote(context, service: _svc),
              icon: const Icon(Icons.add),
              label: Text(t('nt.new')),
            ),
      body: s == null
          ? _Empty(icon: Icons.lock_outline, text: t('nt.not_ready'))
          : StreamBuilder<List<Note>>(
              stream: s,
              builder: (ctx, snap) {
                if (snap.hasError) {
                  return _Empty(icon: Icons.cloud_off, text: t('nt.err.load'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snap.data!;
                if (all.isEmpty) {
                  return _Empty(
                    icon: Icons.functions,
                    title: t('nt.empty_title'),
                    text: t('nt.empty_text'),
                  );
                }
                final shown = [
                  for (final n in all)
                    if (noteMatches(n, _filter, _q.text)) n
                ];
                return ListView(
                  padding: EdgeInsets.fromLTRB(
                      16, 8, 16, 96 + MediaQuery.of(ctx).viewPadding.bottom),
                  children: [
                    TextField(
                      controller: _q,
                      decoration: InputDecoration(
                        hintText: t('nt.search'),
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final f in NoteFilter.values)
                          ChoiceChip(
                            label: Text(t('nt.f.${f.name}')),
                            selected: _filter == f,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _filter = f),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (shown.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(t('lib.nothing'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.onSurfaceVariant)),
                      ),
                    for (final n in shown)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: NoteTile(
                          note: n,
                          onTap: () => openNote(context, n.id, service: _svc),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

/// Карточка заметки: заголовок, начало текста с формулами, привязки.
class NoteTile extends StatelessWidget {
  const NoteTile({super.key, required this.note, this.onTap});
  final Note note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = note;
    final title = n.displayTitle;
    final formulas = allFormulas(n.body).length;
    final muted = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title.isEmpty ? t('nt.untitled') : title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              if (n.body.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                // Начало заметки с формулами, обрезанное по высоте.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 84),
                  child: ClipRect(
                    child: IgnorePointer(
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: MathMarkdown(n.body.length > 600
                            ? n.body.substring(0, 600)
                            : n.body),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (n.paper != null)
                    _Meta(
                        icon: Icons.article_outlined,
                        text: n.paper!.page == null
                            ? n.paper!.title
                            : '${n.paper!.title} · ${t('nt.page', {
                                    'p': n.paper!.page!
                                  })}'),
                  if (n.card != null)
                    _Meta(icon: Icons.task_alt, text: n.card!.title),
                  if (formulas > 0)
                    _Meta(
                        icon: Icons.functions,
                        text: t('nt.formulas', {'n': formulas})),
                  if (n.updated != null)
                    Text(dateLabel(n.updated!), style: muted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.onSurfaceVariant;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 3),
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: c)),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text, this.title});
  final IconData icon;
  final String text;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: scheme.primary.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: scheme.primary),
            ),
            const SizedBox(height: 16),
            if (title != null) ...[
              Text(title!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
            ],
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- редактор

/// Редактор заметки: текст с панелью формул и просмотр.
/// Новая заметка ([noteId] == null) создаётся при первом вводе.
class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({
    super.key,
    this.noteId,
    this.paper,
    this.card,
    this.service,
  });
  final String? noteId;
  final NotePaper? paper;
  final NoteCard? card;
  final NoteService? service;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final NoteService _svc = widget.service ?? NoteService.instance;
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();
  final FocusNode _bodyFocus = FocusNode();
  late String? _id = widget.noteId;
  late NotePaper? _paper = widget.paper;
  late NoteCard? _card = widget.card;
  StreamSubscription<Note?>? _sub;
  Timer? _debounce;
  bool _loaded = false;
  bool _preview = false;
  bool _dirty = false;
  bool _deleted = false;
  String _savedTitle = '';
  String _savedBody = '';

  @override
  void initState() {
    super.initState();
    final id = _id;
    if (id == null) {
      _loaded = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _bodyFocus.requestFocus());
    } else {
      _sub = _svc.note(id).listen(_onRemote, onError: (_) {});
    }
    _title.addListener(_changed);
    _body.addListener(_changed);
  }

  /// Первая загрузка с сервера (дальше редактирует только этот экран).
  void _onRemote(Note? n) {
    if (!mounted) return;
    if (n == null) {
      if (_loaded && !_deleted) setState(() => _deleted = true);
      return;
    }
    setState(() {
      _paper = n.paper;
      _card = n.card;
      if (!_loaded) {
        _loaded = true;
        _savedTitle = n.title;
        _savedBody = n.body;
        _title.text = n.title;
        _body.text = n.body;
        _dirty = false;
      }
    });
  }

  void _changed() {
    if (_title.text == _savedTitle && _body.text == _savedBody) return;
    _dirty = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 900), _save);
  }

  void _save() {
    _debounce?.cancel();
    if (!_dirty || _deleted || !_svc.available) return;
    final title = _title.text, body = _body.text;
    final id = _id;
    if (id == null) {
      if (title.trim().isEmpty && body.trim().isEmpty) return;
      final r =
          _svc.create(title: title, body: body, paper: _paper, card: _card);
      _id = r.id;
      if (mounted) fireAndReport(context, r.done);
    } else {
      final f = _svc.save(id, title: title, body: body);
      if (mounted) {
        fireAndReport(context, f);
      } else {
        unawaited(f.catchError((_) {}));
      }
    }
    _savedTitle = title;
    _savedBody = body;
    _dirty = false;
  }

  @override
  void dispose() {
    _save();
    _sub?.cancel();
    _title.dispose();
    _body.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  Future<void> _copy(String text, String done) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) _toast(context, done);
  }

  Future<void> _linkPaper() async {
    await LibraryService.instance.ensureLoaded();
    if (!mounted) return;
    final lib = LibraryService.instance.items;
    if (lib.isEmpty) {
      _toast(context, t('bd.c.no_library'));
      return;
    }
    final p = await showModalBottomSheet<Paper>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding:
            EdgeInsets.only(bottom: 16 + MediaQuery.of(ctx).viewPadding.bottom),
        children: [
          for (final p in lib)
            ListTile(
              minTileHeight: 56,
              leading: const Icon(Icons.article_outlined),
              title:
                  Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(p.authorsLine,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.pop(ctx, p),
            ),
        ],
      ),
    );
    if (p == null || !mounted) return;
    _setPaper(NotePaper(id: p.id, title: p.title, doi: p.doiShort));
  }

  void _setPaper(NotePaper? p) {
    setState(() => _paper = p);
    final id = _id;
    if (id != null) fireAndReport(context, _svc.setPaper(id, p));
  }

  void _openPaper(NotePaper np) {
    Paper? p;
    for (final x in LibraryService.instance.items) {
      if (x.id == np.id) p = x;
    }
    if (p != null) {
      if (!openReader(context, p, page: np.page)) showPaperSheet(context, p);
    } else if (np.doi != null) {
      openLink(context, 'https://doi.org/${np.doi}');
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDanger(context,
        title: t('nt.delete'), text: t('nt.delete_q'));
    if (!ok || !mounted) return;
    _deleted = true;
    _debounce?.cancel();
    final id = _id;
    if (id != null) fireAndReport(context, _svc.delete(id));
    Navigator.of(context).pop();
  }

  Future<void> _menu() async {
    final formulas = allFormulas(_body.text);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        Widget item(String v, IconData icon, String label, {Color? color}) =>
            ListTile(
              minTileHeight: 56,
              leading: Icon(icon, color: color),
              title: Text(label, style: TextStyle(color: color)),
              onTap: () => Navigator.pop(ctx, v),
            );
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                item('copy', Icons.copy, t('nt.copy_text')),
                if (formulas.isNotEmpty)
                  item('formulas', Icons.functions,
                      t('nt.copy_formulas', {'n': formulas.length})),
                if (_paper == null)
                  item('link', Icons.add_link, t('nt.link_paper'))
                else
                  item('unlink', Icons.link_off, t('nt.unlink_paper')),
                item('delete', Icons.delete_outline, t('nt.delete'),
                    color: scheme.error),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'copy':
        await _copy(_body.text, t('nt.copied'));
      case 'formulas':
        await _copy(formulas.join('\n\n'), t('nt.copied_formulas'));
      case 'link':
        await _linkPaper();
      case 'unlink':
        _setPaper(null);
      case 'delete':
        await _delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_deleted) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(t('nt.deleted'))),
      );
    }
    final keyboard = MediaQuery.of(context).viewInsets.bottom > 0;
    return PopScope(
      onPopInvokedWithResult: (_, __) => _save(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_id == null ? t('nt.new') : t('nt.note')),
          actions: [
            IconButton(
              tooltip: _preview ? t('nt.edit') : t('nt.preview'),
              isSelected: _preview,
              icon: Icon(_preview ? Icons.edit_outlined : Icons.visibility),
              onPressed: () {
                FocusScope.of(context).unfocus();
                setState(() => _preview = !_preview);
              },
            ),
            IconButton(
              tooltip: t('lib.more'),
              icon: const Icon(Icons.more_vert),
              onPressed: _menu,
            ),
          ],
        ),
        body: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_paper != null || _card != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (_paper != null)
                            ActionChip(
                              avatar:
                                  const Icon(Icons.article_outlined, size: 18),
                              label: Text(
                                _paper!.page == null
                                    ? _paper!.title
                                    : '${_paper!.title} · ${t('nt.page', {
                                            'p': _paper!.page!
                                          })}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onPressed: () => _openPaper(_paper!),
                            ),
                          if (_card != null)
                            ActionChip(
                              avatar: const Icon(Icons.task_alt, size: 18),
                              label: Text(_card!.title,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              onPressed: () => showCardSheet(
                                  context, _card!.boardId, _card!.cardId),
                            ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: TextField(
                      controller: _title,
                      maxLength: maxNoteTitle,
                      readOnly: _preview,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800),
                      decoration: InputDecoration(
                        hintText: t('nt.title_hint'),
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    ),
                  ),
                  Expanded(
                    child: _preview
                        ? SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                            child: _body.text.trim().isEmpty
                                ? Text(t('nt.preview_empty'),
                                    style: TextStyle(
                                        color: scheme.onSurfaceVariant))
                                : SizedBox(
                                    width: double.infinity,
                                    child: MathMarkdown(_body.text,
                                        selectable: true),
                                  ),
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: TextField(
                              controller: _body,
                              focusNode: _bodyFocus,
                              maxLength: maxNoteBody,
                              maxLines: null,
                              expands: true,
                              keyboardType: TextInputType.multiline,
                              textAlignVertical: TextAlignVertical.top,
                              textCapitalization: TextCapitalization.sentences,
                              style: const TextStyle(fontSize: 16, height: 1.4),
                              decoration: InputDecoration(
                                hintText: t('nt.body_hint'),
                                border: InputBorder.none,
                                counterText: '',
                              ),
                            ),
                          ),
                  ),
                  if (!_preview)
                    MathToolbar(controller: _body)
                  else
                    SizedBox(height: MediaQuery.of(context).viewPadding.bottom),
                  if (!_preview && !keyboard)
                    SizedBox(height: MediaQuery.of(context).viewPadding.bottom),
                ],
              ),
      ),
    );
  }
}
