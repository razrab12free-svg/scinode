import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../strings.dart';

/// Итог проверки владельца телефона.
enum LockResult {
  /// Отпечаток, лицо или PIN подтверждены.
  ok,

  /// Человек закрыл окно или ошибся — можно попробовать снова.
  canceled,

  /// На телефоне нет блокировки экрана (PIN, графического ключа, пароля).
  noScreenLock,

  /// Слишком много неудачных попыток — телефон временно не даёт проверять.
  lockedOut,

  /// Окно проверки сейчас нельзя показать или другая ошибка.
  error,
}

/// Проверка через систему телефона (отпечаток, лицо, PIN). В тестах
/// подменяется, поэтому вынесена отдельно.
abstract class DeviceAuth {
  /// Есть ли на телефоне блокировка экрана или биометрия.
  Future<bool> available();

  Future<LockResult> authenticate(String reason);
}

class LocalDeviceAuth implements DeviceAuth {
  final _auth = LocalAuthentication();

  @override
  Future<bool> available() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<LockResult> authenticate(String reason) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        // Отпечаток или лицо, а если не вышло — PIN/ключ телефона.
        biometricOnly: false,
        persistAcrossBackgrounding: true,
        authMessages: [
          AndroidAuthMessages(
            signInTitle: t('lock.sys_title'),
            cancelButton: t('bd.cancel'),
          ),
        ],
      );
      return ok ? LockResult.ok : LockResult.canceled;
    } on LocalAuthException catch (e) {
      return lockResultFor(e.code);
    } catch (_) {
      return LockResult.error;
    }
  }
}

/// Перевод кода ошибки библиотеки в понятный итог.
LockResult lockResultFor(LocalAuthExceptionCode code) {
  switch (code) {
    case LocalAuthExceptionCode.noCredentialsSet:
      return LockResult.noScreenLock;
    case LocalAuthExceptionCode.temporaryLockout:
    case LocalAuthExceptionCode.biometricLockout:
      return LockResult.lockedOut;
    case LocalAuthExceptionCode.userCanceled:
    case LocalAuthExceptionCode.systemCanceled:
    case LocalAuthExceptionCode.timeout:
    case LocalAuthExceptionCode.userRequestedFallback:
      return LockResult.canceled;
    default:
      return LockResult.error;
  }
}

/// Замок приложения: при открытии Scinode и при возврате после паузы
/// просит отпечаток / лицо / PIN телефона. Включается в «Профиле».
/// Настройка хранится только на этом телефоне.
class AppLockService extends ChangeNotifier with WidgetsBindingObserver {
  AppLockService({DeviceAuth? auth, DateTime Function()? clock})
      : _auth = auth ?? LocalDeviceAuth(),
        _clock = clock ?? DateTime.now;

  static AppLockService instance = AppLockService();

  /// Варианты «блокировать после» (в минутах); 0 — сразу.
  static const delays = [0, 1, 5, 15];
  static const defaultDelay = 1;

  static const _kOn = 'lock.on';
  static const _kDelay = 'lock.delay';

  DeviceAuth _auth;
  final DateTime Function() _clock;

  bool loaded = false;
  bool enabled = false;
  int delayMinutes = defaultDelay;

  /// Сейчас показан экран замка.
  bool locked = false;

  /// Идёт системная проверка (окно отпечатка / ввод PIN).
  bool busy = false;

  /// Последний неуспешный итог — для подсказки на экране замка.
  LockResult? lastResult;

  DateTime? _wentAway;
  bool _observing = false;

  @visibleForTesting
  set auth(DeviceAuth a) => _auth = a;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      enabled = p.getBool(_kOn) ?? false;
      final d = p.getInt(_kDelay) ?? defaultDelay;
      delayMinutes = delays.contains(d) ? d : defaultDelay;
    } catch (_) {}
    // При запуске приложения замок закрыт сразу.
    locked = enabled;
    loaded = true;
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Включить замок: сначала проверяем, что на телефоне есть блокировка,
  /// и что это владелец (одна успешная проверка).
  Future<LockResult> enable() async {
    if (!await _auth.available()) return LockResult.noScreenLock;
    final r = await _check(t('lock.reason_enable'));
    if (r == LockResult.ok) {
      enabled = true;
      locked = false;
      await _save();
      notifyListeners();
    }
    return r;
  }

  Future<void> disable() async {
    enabled = false;
    locked = false;
    lastResult = null;
    await _save();
    notifyListeners();
  }

  Future<void> setDelay(int minutes) async {
    if (!delays.contains(minutes)) return;
    delayMinutes = minutes;
    await _save();
    notifyListeners();
  }

  /// Снять замок. Если блокировку экрана на телефоне убрали, замок
  /// выключается сам: без неё проверить владельца нечем, а убрать её
  /// может только тот, кто знает PIN телефона.
  Future<LockResult> unlock() async {
    if (!locked || busy) return LockResult.canceled;
    final r = await _check(t('lock.reason'));
    if (r == LockResult.ok) {
      locked = false;
      lastResult = null;
    } else if (r == LockResult.noScreenLock) {
      enabled = false;
      locked = false;
      lastResult = r;
      await _save();
    } else {
      lastResult = r;
    }
    notifyListeners();
    return r;
  }

  Future<LockResult> _check(String reason) async {
    busy = true;
    notifyListeners();
    try {
      return await _auth.authenticate(reason);
    } finally {
      busy = false;
      // Окно PIN — отдельный экран системы: уход в фон во время проверки
      // не считается.
      _wentAway = null;
      notifyListeners();
    }
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kOn, enabled);
      await p.setInt(_kDelay, delayMinutes);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!enabled || busy) return;
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _wentAway ??= _clock();
    } else if (state == AppLifecycleState.resumed) {
      final away = _wentAway;
      _wentAway = null;
      if (away != null &&
          !locked &&
          _clock().difference(away) >= Duration(minutes: delayMinutes)) {
        locked = true;
        lastResult = null;
        notifyListeners();
      }
    }
  }

  /// Пока замок закрыт, кнопка «Назад» не листает экраны под ним.
  @override
  Future<bool> didPopRoute() async => locked;
}
