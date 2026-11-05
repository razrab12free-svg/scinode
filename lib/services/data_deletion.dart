import 'package:firebase_auth/firebase_auth.dart';

import '../auth_service.dart';
import '../strings.dart';
import 'chat_service.dart';
import 'library_service.dart';
import 'pdf_store.dart';
import 'profile_service.dart';
import 'reading_progress.dart';

/// «Удалить мои данные»: переписки, профиль, библиотека, PDF, прогресс чтения.
/// Возвращает null при успехе или краткое описание того, что не удалось.
Future<String?> deleteMyData() async {
  final errors = <String>[];

  // 1. Переписки и сообщения (пока мы ещё вошли в аккаунт).
  final chat = ChatService.instance;
  if (chat.available) {
    try {
      await chat.deleteAllMine();
    } on ChatException catch (e) {
      errors.add(t('chat.err.${e.kind}'));
    } catch (_) {
      errors.add(t('chat.err.other'));
    }
  }

  // 2. Опубликованный профиль и черновик.
  final pErr = await ProfileService.instance.deleteAll();
  if (pErr != null) errors.add(pErr);

  // 3. Данные на телефоне.
  await LibraryService.instance.clearAll();
  await PdfStore.instance.clearAll();
  await ReadingProgress.instance.clearAll();

  if (errors.isNotEmpty) return errors.join('; ');

  // 4. Аккаунт входа. Firebase может попросить войти заново —
  //    тогда просто выходим, данные уже удалены.
  if (AuthService.instance.ready) {
    try {
      await FirebaseAuth.instance.currentUser?.delete();
    } catch (_) {}
  }
  await AuthService.instance.signOut();
  return null;
}
