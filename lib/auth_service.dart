import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_config.dart';
import 'strings.dart';

class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const String cancelled = '__cancelled__';

  bool initDone = false;
  bool ready = false;
  String? error;
  bool _googleInit = false;

  Future<void> init() async {
    if (!firebaseConfigured) {
      initDone = true;
      notifyListeners();
      return;
    }
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: firebaseOptions);
      }
      ready = true;
      FirebaseAuth.instance.authStateChanges().listen((_) => notifyListeners());
      try {
        await FirebaseAuth.instance
            .authStateChanges()
            .first
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    } catch (e) {
      error = '$e';
    }
    initDone = true;
    notifyListeners();
  }

  User? get user {
    if (!ready) return null;
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Возвращает null при успехе, [cancelled] при отмене или текст ошибки.
  Future<String?> signInWithGoogle() async {
    if (!ready) return t('login.not_configured');
    try {
      final g = GoogleSignIn.instance;
      if (!_googleInit) {
        await g.initialize(serverClientId: googleWebClientId);
        _googleInit = true;
      }
      final account = await g.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) return t('login.failed');
      final cred = GoogleAuthProvider.credential(idToken: idToken);
      await FirebaseAuth.instance.signInWithCredential(cred);
      notifyListeners();
      return null;
    } catch (e) {
      final s = e.toString().toLowerCase();
      if (s.contains('cancel')) return cancelled;
      // Пользователю — понятный текст, без технических подробностей.
      if (s.contains('network') ||
          s.contains('unavailable') ||
          s.contains('socket') ||
          s.contains('timeout')) {
        return t('login.err.network');
      }
      return t('login.failed_hint');
    }
  }

  Future<void> signOut() async {
    try {
      if (_googleInit) await GoogleSignIn.instance.signOut();
    } catch (_) {}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    notifyListeners();
  }
}
