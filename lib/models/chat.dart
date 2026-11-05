/// Модели чата: переписка и сообщение (Firestore `conversations`).
library;

/// Максимальная длина сообщения.
const maxMessageLength = 2000;

/// Длина краткой копии последнего сообщения в списке переписок.
const previewLength = 200;

enum ChatStatus { pending, accepted, declined }

ChatStatus _status(dynamic v) => switch (v) {
      'accepted' => ChatStatus.accepted,
      'declined' => ChatStatus.declined,
      _ => ChatStatus.pending,
    };

/// id переписки пары: uid по алфавиту через «_». У пары одна переписка.
String conversationId(String a, String b) {
  final m = [a, b]..sort();
  return '${m[0]}_${m[1]}';
}

/// Время из Firestore (Timestamp) или null. Не зависим от пакета Firestore:
/// у Timestamp есть метод toDate().
DateTime? readTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  try {
    final d = (v as dynamic).toDate();
    if (d is DateTime) return d;
  } catch (_) {}
  return null;
}

/// Краткая копия последнего сообщения.
class LastMessage {
  const LastMessage({required this.text, required this.from, this.at});
  final String text;
  final String from;
  final DateTime? at;
}

/// Переписка двух участников.
class Conversation {
  const Conversation({
    required this.id,
    required this.members,
    required this.status,
    required this.requester,
    this.updated,
    this.last,
    this.lastRead = const {},
    this.blockedBy = const [],
  });

  final String id;
  final List<String> members;
  final ChatStatus status;
  final String requester;
  final DateTime? updated;
  final LastMessage? last;
  final Map<String, DateTime> lastRead;
  final List<String> blockedBy;

  factory Conversation.fromMap(String id, Map<String, dynamic> m) {
    final l = m['last'];
    final lr = m['lastRead'];
    return Conversation(
      id: id,
      members: [for (final x in (m['members'] as List? ?? const [])) '$x'],
      status: _status(m['status']),
      requester: '${m['requester'] ?? ''}',
      updated: readTime(m['updated']),
      last: l is Map
          ? LastMessage(
              text: '${l['t'] ?? ''}',
              from: '${l['from'] ?? ''}',
              at: readTime(l['at']),
            )
          : null,
      lastRead: {
        if (lr is Map)
          for (final e in lr.entries)
            if (readTime(e.value) != null) '${e.key}': readTime(e.value)!,
      },
      blockedBy: [for (final x in (m['blockedBy'] as List? ?? const [])) '$x'],
    );
  }

  /// Собеседник.
  String other(String me) =>
      members.firstWhere((u) => u != me, orElse: () => '');

  bool get isBlocked => blockedBy.isNotEmpty;
  bool blockedByMe(String me) => blockedBy.contains(me);

  /// Входящий запрос, на который я ещё не ответил.
  bool isIncomingRequest(String me) =>
      status == ChatStatus.pending && requester != me;

  /// Есть непрочитанное сообщение от собеседника.
  bool isUnread(String me) {
    final l = last;
    if (l == null || l.from == me) return false;
    final read = lastRead[me];
    if (read == null) return true;
    final at = l.at;
    return at != null && at.isAfter(read);
  }

  /// Можно ли мне сейчас писать в эту переписку.
  bool canSend(String me) =>
      !isBlocked && status == ChatStatus.accepted && members.contains(me);

  /// Прочитал ли собеседник моё сообщение, отправленное в [at].
  bool readByOther(String me, DateTime? at) {
    final r = lastRead[other(me)];
    if (r == null || at == null) return false;
    return !r.isBefore(at);
  }
}

/// Сообщение.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.from,
    required this.text,
    this.at,
  });
  final String id;
  final String from;
  final String text;

  /// null, пока сервер не поставил время (сообщение ещё отправляется).
  final DateTime? at;

  factory ChatMessage.fromMap(String id, Map<String, dynamic> m) => ChatMessage(
        id: id,
        from: '${m['from'] ?? ''}',
        text: '${m['text'] ?? ''}',
        at: readTime(m['at']),
      );
}

/// Проверка текста перед отправкой. Возвращает ошибку ('empty' / 'long')
/// или null, если текст можно отправлять.
String? validateMessage(String text) {
  final t = text.trim();
  if (t.isEmpty) return 'empty';
  if (t.length > maxMessageLength) return 'long';
  return null;
}

/// Краткая однострочная копия для списка переписок.
String previewOf(String text) {
  final one = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  return one.length <= previewLength ? one : one.substring(0, previewLength);
}

/// Время в списке и в переписке: сегодня — «14:05», вчера — [yesterday],
/// в этом году — «05.11», иначе — «05.11.2025».
String formatChatTime(DateTime at, DateTime now, {required String yesterday}) {
  String two(int x) => x.toString().padLeft(2, '0');
  final a = at.toLocal(), n = now.toLocal();
  final day = DateTime(a.year, a.month, a.day);
  final today = DateTime(n.year, n.month, n.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return '${two(a.hour)}:${two(a.minute)}';
  if (diff == 1) return yesterday;
  if (a.year == n.year) return '${two(a.day)}.${two(a.month)}';
  return '${two(a.day)}.${two(a.month)}.${a.year}';
}

/// Сортировка переписок: сначала входящие запросы, затем по свежести.
List<Conversation> sortConversations(List<Conversation> list, String me) {
  final out = List.of(list);
  out.sort((a, b) {
    final ra = a.isIncomingRequest(me), rb = b.isIncomingRequest(me);
    if (ra != rb) return ra ? -1 : 1;
    final ta = a.last?.at ?? a.updated, tb = b.last?.at ?? b.updated;
    if (ta == null && tb == null) return 0;
    // Время ещё не пришло с сервера — значит, сообщение только что отправлено.
    if (ta == null) return -1;
    if (tb == null) return 1;
    return tb.compareTo(ta);
  });
  return out;
}

/// Сколько переписок требуют внимания (непрочитанные и входящие запросы).
int attentionCount(List<Conversation> list, String me) => list
    .where((c) =>
        !c.blockedByMe(me) &&
        c.status != ChatStatus.declined &&
        (c.isUnread(me) || c.isIncomingRequest(me)))
    .length;
