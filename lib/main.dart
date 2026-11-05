import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'screens/home_shell.dart';
import 'screens/lock_screen.dart';
import 'screens/login_screen.dart';
import 'services/app_lock_service.dart';
import 'services/library_service.dart';
import 'services/openalex_service.dart';
import 'strings.dart';
import 'theme.dart';
import 'widgets/logo.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ScinodeApp());
}

class ScinodeApp extends StatefulWidget {
  const ScinodeApp({super.key});

  @override
  State<ScinodeApp> createState() => _ScinodeAppState();
}

class _ScinodeAppState extends State<ScinodeApp> {
  @override
  void initState() {
    super.initState();
    Strings.instance.load();
    AuthService.instance.init();
    OpenAlexService.instance.load();
    AppLockService.instance.load();
    AuthService.instance.addListener(_onAuth);
  }

  void _onAuth() {
    LibraryService.instance.ensureLoaded();
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_onAuth);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(
          [Strings.instance, AuthService.instance, AppLockService.instance]),
      builder: (context, _) {
        final s = Strings.instance;
        final a = AuthService.instance;
        final lock = AppLockService.instance;
        // Замок закрывает приложение только у вошедшего человека.
        final locked = lock.locked && a.user != null;
        final Widget home;
        if (!s.loaded || !a.initDone || !lock.loaded) {
          home = const _Splash();
        } else if (a.user == null) {
          home = LoginScreen();
        } else {
          home = HomeShell();
        }
        return MaterialApp(
          title: 'Scinode',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.system,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: mq.textScaler.clamp(
                  minScaleFactor: 1.0,
                  maxScaleFactor: 1.2,
                ),
              ),
              // Обёртки есть всегда, чтобы экраны под замком не теряли
              // своё состояние; пока замок закрыт, они не видны и не активны.
              child: Stack(
                children: [
                  TickerMode(
                    enabled: !locked,
                    child: ExcludeSemantics(excluding: locked, child: child!),
                  ),
                  if (locked) const Positioned.fill(child: LockScreen()),
                ],
              ),
            );
          },
          home: home,
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: LogoMark(size: 96)));
  }
}
