import 'package:flutter/material.dart';

import '../services/app_lock_service.dart';
import '../strings.dart';
import '../widgets/logo.dart';

/// Экран замка поверх всего приложения. Сразу открывает системную
/// проверку (отпечаток / лицо / PIN), повторить можно кнопкой.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _unlock();
    });
  }

  Future<void> _unlock() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final r = await AppLockService.instance.unlock();
    // Блокировку экрана на телефоне убрали — замок выключился сам.
    if (r == LockResult.noScreenLock) {
      messenger?.showSnackBar(SnackBar(
        content: Text(t('lock.turned_off')),
        duration: const Duration(seconds: 8),
      ));
    }
  }

  String? _hint(LockResult? r) {
    switch (r) {
      case LockResult.lockedOut:
        return t('lock.locked_out');
      case LockResult.error:
        return t('lock.error');
      case LockResult.canceled:
        return t('lock.canceled');
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([AppLockService.instance, Strings.instance]),
      builder: (context, _) {
        final lock = AppLockService.instance;
        final hint = _hint(lock.lastResult);
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LogoMark(size: 96),
                    const SizedBox(height: 20),
                    Icon(Icons.lock_outline, size: 36, color: scheme.primary),
                    const SizedBox(height: 12),
                    Text(
                      t('lock.title'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t('lock.text'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15),
                    ),
                    if (hint != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        hint,
                        key: const Key('lock.hint'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: scheme.error),
                      ),
                    ],
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(220, 56),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: lock.busy ? null : _unlock,
                      icon: const Icon(Icons.fingerprint, size: 28),
                      label: Text(t('lock.unlock'),
                          style: const TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
