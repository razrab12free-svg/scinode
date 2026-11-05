import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/chat.dart';
import '../services/chat_service.dart';
import '../strings.dart';
import '../widgets/scientist_card.dart' show initials;

String chatError(Object e) =>
    t('chat.err.${e is ChatException ? e.kind : 'other'}');

/// Список переписок.
class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key, this.service});
  final ChatService? service;

  @override
  Widget build(BuildContext context) {
    final svc = service ?? ChatService.instance;
    return Scaffold(
      appBar: AppBar(title: Text(t('chat.title'))),
      body: !svc.available
          ? _Center(icon: Icons.lock_outline, text: t('chat.not_ready'))
          : StreamBuilder<List<Conversation>>(
              stream: svc.conversations(),
              builder: (ctx, snap) {
                if (snap.hasError) {
                  return _Center(
                      icon: Icons.cloud_off, text: chatError(snap.error!));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final me = svc.me;
                final all = snap.data!;
                final requests = all
                    .where((c) => c.isIncomingRequest(me) && !c.isBlocked)
                    .toList();
                final dialogs =
                    all.where((c) => !requests.contains(c)).toList();
                if (all.isEmpty) {
                  return _Center(
                    icon: Icons.forum_outlined,
                    title: t('chat.empty_title'),
                    text: t('chat.empty_text'),
                  );
                }
                return ListView(
                  padding: EdgeInsets.only(
                      bottom: 16 + MediaQuery.of(ctx).viewPadding.bottom),
                  children: [
                    if (requests.isNotEmpty) ...[
                      _Header(t('chat.requests')),
                      for (final c in requests)
                        _ConversationTile(c: c, svc: svc),
                    ],
                    if (dialogs.isNotEmpty) ...[
                      if (requests.isNotEmpty) _Header(t('chat.dialogs')),
                      for (final c in dialogs)
                        _ConversationTile(c: c, svc: svc),
                    ],
                  ],
                );
              },
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        child: Text(text,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary)),
      );
}

class _Center extends StatelessWidget {
  const _Center({required this.icon, required this.text, this.title});
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
                style: const TextStyle(fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

/// Имя собеседника из его профиля (с запасным вариантом).
class _Name extends StatelessWidget {
  const _Name({required this.uid, required this.svc, required this.builder});
  final String uid;
  final ChatService svc;
  final Widget Function(String name) builder;

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: svc.profileOf(uid),
        builder: (ctx, snap) {
          final p = snap.data;
          final name = p == null || p.name.isEmpty
              ? (snap.connectionState == ConnectionState.done
                  ? t('chat.deleted_user')
                  : '…')
              : p.name;
          return builder(name);
        },
      );
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.c, required this.svc});
  final Conversation c;
  final ChatService svc;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final me = svc.me;
    final other = c.other(me);
    final unread = c.isUnread(me) || c.isIncomingRequest(me);
    final last = c.last;
    final at = last?.at;
    final preview =
        last == null ? '' : (last.from == me ? t('chat.you') : '') + last.text;

    return _Name(
      uid: other,
      svc: svc,
      builder: (name) => ListTile(
        minTileHeight: 72,
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: scheme.primary.withAlpha(36),
          child: Text(initials(name),
              style: TextStyle(
                  color: scheme.primary, fontWeight: FontWeight.w800)),
        ),
        title: Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontWeight: unread ? FontWeight.w800 : FontWeight.w600)),
        subtitle: Text(
          c.isBlocked
              ? t('chat.blocked_other')
              : c.status == ChatStatus.declined
                  ? t('chat.declined')
                  : preview,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: unread ? scheme.onSurface : scheme.onSurfaceVariant,
            fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (at != null)
              Text(
                formatChatTime(at, DateTime.now(),
                    yesterday: t('chat.yesterday')),
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            if (unread) ...[
              const SizedBox(height: 6),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                    color: scheme.primary, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) =>
              ChatScreen(otherUid: other, otherName: name, service: svc),
        )),
      ),
    );
  }
}

/// Переписка с одним собеседником (в том числе ещё не начатая).
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.otherUid,
    required this.otherName,
    this.service,
  });
  final String otherUid;
  final String otherName;
  final ChatService? service;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatService _svc = widget.service ?? ChatService.instance;
  late final String _me = _svc.me;
  late final String _cid = conversationId(_me, widget.otherUid);
  final TextEditingController _text = TextEditingController();
  late final Stream<Conversation?> _conv = _svc.conversation(_cid);
  // Подписку на сообщения открываем, только когда переписка уже существует:
  // до этого правила не дают читать её сообщения.
  Stream<List<ChatMessage>>? _messages;
  DateTime? _markedAt;
  bool _sending = false;
  bool? _profileOk;

  @override
  void initState() {
    super.initState();
    _text.addListener(_onText);
    _svc.myProfilePublished().then((v) {
      if (mounted) setState(() => _profileOk = v);
    });
  }

  void _onText() => setState(() {});

  @override
  void dispose() {
    _text.removeListener(_onText);
    _text.dispose();
    super.dispose();
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) _toast(chatError(e));
    }
  }

  Future<void> _send(Conversation? c) async {
    final text = _text.text;
    final err = validateMessage(text);
    if (err != null) {
      _toast(t('chat.err.$err'));
      return;
    }
    setState(() => _sending = true);
    // Офлайн Firestore сохранит сообщение и отправит позже — не ждём сервера
    // дольше нескольких секунд, чтобы поле ввода не «зависало».
    final f =
        c == null ? _svc.start(widget.otherUid, text) : _svc.send(c.id, text);
    _text.clear();
    try {
      await f.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      if (mounted) _toast(t('chat.err.network'));
    } catch (e) {
      if (mounted) {
        _text.text = text; // вернём текст, чтобы не потерять
        _toast(chatError(e));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmBlock(Conversation c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(t('chat.block')),
        content: Text(t('chat.block_q')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: Text(t('pdf.cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
            onPressed: () => Navigator.pop(d, true),
            child: Text(t('chat.block')),
          ),
        ],
      ),
    );
    if (ok == true) await _run(() => _svc.block(c.id));
  }

  Future<void> _messageActions(Conversation? c, ChatMessage m) async {
    final mine = m.from == _me;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              minTileHeight: 56,
              leading: const Icon(Icons.copy),
              title: Text(t('chat.copy')),
              onTap: () => Navigator.pop(ctx, 'copy'),
            ),
            if (!mine && c != null)
              ListTile(
                minTileHeight: 56,
                leading: Icon(Icons.flag_outlined,
                    color: Theme.of(ctx).colorScheme.error),
                title: Text(t('chat.report'),
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                onTap: () => Navigator.pop(ctx, 'report'),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: m.text));
      if (mounted) _toast(t('chat.copied'));
    } else if (action == 'report' && c != null) {
      final reason = await showDialog<String>(
        context: context,
        builder: (_) => const _ReportDialog(),
      );
      if (reason == null || !mounted) return;
      await _run(() async {
        await _svc.report(c.id, m, reason);
        if (mounted) _toast(t('chat.report_sent'));
      });
    }
  }

  Widget _banner(String text, {List<Widget> actions = const []}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text,
              style:
                  TextStyle(fontSize: 14, color: scheme.onSecondaryContainer)),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
  }

  Widget _composer(Conversation? c) {
    final scheme = Theme.of(context).colorScheme;
    final len = _text.text.trim().length;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _text,
                minLines: 1,
                maxLines: 6,
                maxLength: maxMessageLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: t('chat.hint'),
                  filled: true,
                  counterText: len > maxMessageLength - 200
                      ? '$len / $maxMessageLength'
                      : '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: IconButton.filled(
                tooltip: t('chat.send'),
                iconSize: 24,
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                ),
                onPressed: _sending || len == 0 ? null : () => _send(c),
                icon: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Icon(Icons.send),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Нижняя часть экрана в зависимости от состояния переписки.
  Widget _bottom(Conversation? c) {
    if (_profileOk == false) return _banner(t('chat.need_profile'));
    if (c == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [_banner(t('chat.new_note')), _composer(null)],
      );
    }
    if (c.blockedByMe(_me)) {
      return _banner(t('chat.blocked_me'), actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: () => _run(() => _svc.unblock(c.id)),
          child: Text(t('chat.unblock')),
        ),
      ]);
    }
    if (c.isBlocked) return _banner(t('chat.blocked_other'));
    if (c.status == ChatStatus.declined) return _banner(t('chat.declined'));
    if (c.status == ChatStatus.pending) {
      if (c.requester == _me) return _banner(t('chat.wait'));
      return _banner(t('chat.incoming', {'name': widget.otherName}), actions: [
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(120, 48)),
          onPressed: () => _run(() => _svc.accept(c.id)),
          child: Text(t('chat.accept')),
        ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: () => _run(() => _svc.decline(c.id)),
          child: Text(t('chat.decline')),
        ),
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: () => _confirmBlock(c),
          child: Text(t('chat.block')),
        ),
      ]);
    }
    return _composer(c);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<Conversation?>(
      stream: _conv,
      builder: (ctx, convSnap) {
        final c = convSnap.data;
        if (c != null) {
          _messages ??= _svc.messages(_cid);
          // Отмечаем прочитанным один раз на каждое новое сообщение.
          final at = c.last?.at;
          if (c.isUnread(_me) && at != null && at != _markedAt) {
            _markedAt = at;
            _svc.markRead(c);
          }
        }
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: scheme.primary.withAlpha(36),
                  child: Text(initials(widget.otherName),
                      style: TextStyle(
                          fontSize: 13,
                          color: scheme.primary,
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(widget.otherName,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            actions: [
              if (c != null)
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'block') _confirmBlock(c);
                    if (v == 'unblock') _run(() => _svc.unblock(c.id));
                  },
                  itemBuilder: (_) => [
                    if (c.blockedByMe(_me))
                      PopupMenuItem(
                          value: 'unblock', child: Text(t('chat.unblock')))
                    else
                      PopupMenuItem(
                          value: 'block', child: Text(t('chat.block'))),
                  ],
                ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  key: ValueKey(_messages != null),
                  stream: _messages,
                  builder: (ctx, snap) {
                    if (snap.hasError) {
                      return Center(child: Text(t('chat.err.load')));
                    }
                    final list = snap.data ?? const <ChatMessage>[];
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final m = list[list.length - 1 - i];
                        return _Bubble(
                          m: m,
                          mine: m.from == _me,
                          read: c?.readByOther(_me, m.at) ?? false,
                          onLongPress: () => _messageActions(c, m),
                        );
                      },
                    );
                  },
                ),
              ),
              // Нижняя часть не залезает под системную полосу жестов.
              SafeArea(top: false, child: _bottom(c)),
            ],
          ),
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.m,
    required this.mine,
    required this.read,
    required this.onLongPress,
  });
  final ChatMessage m;
  final bool mine;
  final bool read;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = mine ? scheme.primary : scheme.surfaceContainerHighest;
    final fg = mine ? scheme.onPrimary : scheme.onSurface;
    final at = m.at;
    final time = at == null
        ? t('chat.sending')
        : formatChatTime(at, DateTime.now(), yesterday: t('chat.yesterday'));
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(mine ? 18 : 4),
                bottomRight: Radius.circular(mine ? 4 : 18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    m.text,
                    style: TextStyle(fontSize: 15, height: 1.35, color: fg),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(time,
                        style:
                            TextStyle(fontSize: 11, color: fg.withAlpha(180))),
                    if (mine && at != null) ...[
                      const SizedBox(width: 4),
                      Semantics(
                        label: read ? t('chat.read') : t('chat.sent'),
                        child: Icon(read ? Icons.done_all : Icons.done,
                            size: 15, color: fg.withAlpha(200)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog();

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final TextEditingController _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t('chat.report_title')),
      content: TextField(
        controller: _c,
        maxLength: 300,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: t('chat.report_hint'),
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('pdf.cancel'))),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
          onPressed: () => Navigator.pop(context, _c.text.trim()),
          child: Text(t('chat.report')),
        ),
      ],
    );
  }
}
