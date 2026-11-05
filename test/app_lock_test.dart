import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:scinode/screens/lock_screen.dart';
import 'package:scinode/services/app_lock_service.dart';
import 'package:scinode/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAuth implements DeviceAuth {
  FakeAuth({this.has = true, List<LockResult>? answers})
      : answers = answers ?? [LockResult.ok];
  bool has;
  List<LockResult> answers;
  int calls = 0;
  String? lastReason;

  @override
  Future<bool> available() async => has;

  @override
  Future<LockResult> authenticate(String reason) async {
    lastReason = reason;
    final r = answers[calls < answers.length ? calls : answers.length - 1];
    calls++;
    return r;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  DateTime clock() => now;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 11, 5, 12);
  });

  group('Коды ошибок системы', () {
    test('нет блокировки экрана, слишком много попыток, отмена', () {
      expect(lockResultFor(LocalAuthExceptionCode.noCredentialsSet),
          LockResult.noScreenLock);
      expect(lockResultFor(LocalAuthExceptionCode.temporaryLockout),
          LockResult.lockedOut);
      expect(lockResultFor(LocalAuthExceptionCode.biometricLockout),
          LockResult.lockedOut);
      expect(lockResultFor(LocalAuthExceptionCode.userCanceled),
          LockResult.canceled);
      expect(lockResultFor(LocalAuthExceptionCode.systemCanceled),
          LockResult.canceled);
      expect(lockResultFor(LocalAuthExceptionCode.uiUnavailable),
          LockResult.error);
    });
  });

  group('AppLockService', () {
    test('по умолчанию замок выключен и приложение открыто', () async {
      final s = AppLockService(auth: FakeAuth(), clock: clock);
      await s.load();
      expect(s.enabled, isFalse);
      expect(s.locked, isFalse);
      expect(s.delayMinutes, AppLockService.defaultDelay);
    });

    test('без блокировки экрана замок не включается', () async {
      final a = FakeAuth(has: false);
      final s = AppLockService(auth: a, clock: clock);
      await s.load();
      expect(await s.enable(), LockResult.noScreenLock);
      expect(s.enabled, isFalse);
      expect(a.calls, 0);
    });

    test('включение требует одной проверки, отмена — не включает', () async {
      final a = FakeAuth(answers: [LockResult.canceled, LockResult.ok]);
      final s = AppLockService(auth: a, clock: clock);
      await s.load();
      expect(await s.enable(), LockResult.canceled);
      expect(s.enabled, isFalse);
      expect(await s.enable(), LockResult.ok);
      expect(s.enabled, isTrue);
      expect(s.locked, isFalse);
    });

    test('настройки сохраняются, после перезапуска замок закрыт', () async {
      final s = AppLockService(auth: FakeAuth(), clock: clock);
      await s.load();
      await s.enable();
      await s.setDelay(5);
      await s.setDelay(7); // такого варианта нет — не меняется
      final again = AppLockService(auth: FakeAuth(), clock: clock);
      await again.load();
      expect(again.enabled, isTrue);
      expect(again.delayMinutes, 5);
      expect(again.locked, isTrue);
    });

    test('короткий выход не блокирует, долгий — блокирует', () async {
      final s = AppLockService(auth: FakeAuth(), clock: clock);
      await s.load();
      await s.enable();
      s.didChangeAppLifecycleState(AppLifecycleState.inactive);
      s.didChangeAppLifecycleState(AppLifecycleState.hidden);
      s.didChangeAppLifecycleState(AppLifecycleState.paused);
      now = now.add(const Duration(seconds: 40));
      s.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(s.locked, isFalse);

      // Время считается от первого ухода в фон.
      s.didChangeAppLifecycleState(AppLifecycleState.hidden);
      now = now.add(const Duration(seconds: 30));
      s.didChangeAppLifecycleState(AppLifecycleState.paused);
      now = now.add(const Duration(seconds: 31));
      s.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(s.locked, isTrue);
    });

    test('«Сразу» блокирует при любом возврате', () async {
      final s = AppLockService(auth: FakeAuth(), clock: clock);
      await s.load();
      await s.enable();
      await s.setDelay(0);
      s.didChangeAppLifecycleState(AppLifecycleState.hidden);
      s.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(s.locked, isTrue);
      expect(await s.didPopRoute(), isTrue); // «Назад» не листает экраны
      expect(await s.unlock(), LockResult.ok);
      expect(s.locked, isFalse);
      expect(await s.didPopRoute(), isFalse);
    });

    test('выключенный замок не реагирует на фон', () async {
      final s = AppLockService(auth: FakeAuth(), clock: clock);
      await s.load();
      s.didChangeAppLifecycleState(AppLifecycleState.paused);
      now = now.add(const Duration(hours: 1));
      s.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(s.locked, isFalse);
    });

    test('уход в окно PIN во время проверки не закрывает замок снова',
        () async {
      late AppLockService s;
      final a = _AwayAuth(() {
        // Системное окно PIN — отдельный экран: приложение уходит в фон.
        s.didChangeAppLifecycleState(AppLifecycleState.paused);
        now = now.add(const Duration(minutes: 20));
        s.didChangeAppLifecycleState(AppLifecycleState.resumed);
      });
      s = AppLockService(auth: a, clock: clock);
      SharedPreferences.setMockInitialValues({'lock.on': true});
      await s.load();
      expect(s.locked, isTrue);
      expect(await s.unlock(), LockResult.ok);
      expect(s.locked, isFalse);
      s.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(s.locked, isFalse);
    });

    test(
        'неудача остаётся на экране, блокировку экрана убрали — замок выключен',
        () async {
      SharedPreferences.setMockInitialValues({'lock.on': true});
      final a = FakeAuth(answers: [
        LockResult.lockedOut,
        LockResult.noScreenLock,
      ]);
      final s = AppLockService(auth: a, clock: clock);
      await s.load();
      expect(await s.unlock(), LockResult.lockedOut);
      expect(s.locked, isTrue);
      expect(s.lastResult, LockResult.lockedOut);
      expect(await s.unlock(), LockResult.noScreenLock);
      expect(s.locked, isFalse);
      expect(s.enabled, isFalse);
      final p = await SharedPreferences.getInstance();
      expect(p.getBool('lock.on'), isFalse);
    });
  });

  group('Экран замка', () {
    Future<void> pumpLock(WidgetTester tester, FakeAuth a,
        {String lang = 'ru', Size size = const Size(400, 800)}) async {
      await Strings.instance.setLang(lang);
      SharedPreferences.setMockInitialValues({'lock.on': true});
      AppLockService.instance = AppLockService(auth: a, clock: clock);
      await AppLockService.instance.load();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.2)),
          child: child!,
        ),
        home: const LockScreen(),
      ));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('сразу открывает проверку, при отмене — подсказка и кнопка',
        (tester) async {
      final a = FakeAuth(answers: [LockResult.canceled, LockResult.ok]);
      await pumpLock(tester, a);
      expect(a.calls, 1);
      expect(a.lastReason, t('lock.reason'));
      expect(find.text(t('lock.title')), findsOneWidget);
      expect(find.byKey(const Key('lock.hint')), findsOneWidget);
      expect(AppLockService.instance.locked, isTrue);

      final btn = find.text(t('lock.unlock'));
      expect(tester.getSize(find.byType(FilledButton)).height,
          greaterThanOrEqualTo(48));
      await tester.tap(btn);
      await tester.pump();
      expect(a.calls, 2);
      expect(AppLockService.instance.locked, isFalse);
    });

    for (final lang in ['ru', 'uz', 'en']) {
      testWidgets('узкий телефон, крупный шрифт ($lang)', (tester) async {
        final a = FakeAuth(answers: [LockResult.lockedOut]);
        await pumpLock(tester, a, lang: lang, size: const Size(320, 480));
        expect(tester.takeException(), isNull);
        expect(find.text(t('lock.locked_out')), findsOneWidget);
      });
    }
  });
}

class _AwayAuth implements DeviceAuth {
  _AwayAuth(this.during);
  final void Function() during;

  @override
  Future<bool> available() async => true;

  @override
  Future<LockResult> authenticate(String reason) async {
    during();
    return LockResult.ok;
  }
}
