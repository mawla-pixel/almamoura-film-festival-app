import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class AuthService {
  AuthService._();

  static String get redirectUri {
    if (kIsWeb) {
      final uri = Uri.base;
      return uri.replace(query: '', fragment: '').toString();
    }
    return 'io.supabase.almamoura://login-callback/';
  }

  static GoTrueClient get _auth => SupabaseService.auth;

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return _auth.signUp(email: email, password: password);
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithPassword(email: email, password: password);
  }

  static Future<bool> signInWithGoogle() {
    return _auth.signInWithOAuth(OAuthProvider.google, redirectTo: redirectUri);
  }

  static Future<void> resetPassword(String email) {
    return _auth.resetPasswordForEmail(email, redirectTo: redirectUri);
  }

  static Future<void> signOut() => _auth.signOut();
}
