import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'api_client.dart';
import 'local_storage_service.dart';
import 'secure_token_storage.dart';
import 'session_management.dart';
import 'user_data_clear_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result of a Google Sign-In attempt.
class GoogleSignInResult {
  final bool success;
  final bool isFallback; // true = backend doesn't support /auth/google yet, profile pre-filled
  final bool isNewUser;
  final String? token;
  final String? email;
  final String? name;
  final String? photoUrl;
  final String? error;

  const GoogleSignInResult({
    required this.success,
    this.isFallback = false,
    this.isNewUser = false,
    this.token,
    this.email,
    this.name,
    this.photoUrl,
    this.error,
  });
}

class GoogleAuthService {
  // Load Google OAuth Client ID from environment - never hardcode
  static const String _googleClientId = String.fromEnvironment(
    'GOOGLE_OAUTH_CLIENT_ID',
    defaultValue: '', // If empty, fallback sign-in will be used
  );

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: _googleClientId.isNotEmpty ? _googleClientId : null,
  );

  /// Sign in with Google and attempt backend authentication.
  /// Returns a [GoogleSignInResult] describing the outcome.
  static Future<GoogleSignInResult> signIn() async {
    try {
      // 1. Trigger native Google account picker
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        return const GoogleSignInResult(
          success: false,
          error: 'Sign-in was cancelled',
        );
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;
      final String email = account.email;
      final String name = account.displayName ?? '';
      final String? photoUrl = account.photoUrl;

      if (kDebugMode) {
        debugPrint('✅ Google Sign-In: $email');
      }

      // 2. Try backend Google auth endpoint
      try {
        final response = await ApiClient.postJson('/auth/google', {
          'google_token': idToken ?? '',
          'email': email,
          'name': name,
          'photo_url': photoUrl ?? '',
        });

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final token = (data['token'] ?? data['access_token'])?.toString();

          if (token != null && token.isNotEmpty) {
            if (kDebugMode) debugPrint('🧹 Clearing old user data before Google login...');
            await UserDataClearService.clearAllUserData();
            await LocalStorageService.clearOrphanSalesBoxes();

            final extractedUserId = data['user_id'] != null
                ? int.tryParse(data['user_id'].toString()) ?? 0
                : 0;

            final deviceId = await SessionManagementService.getDeviceId();
            await SessionManagementService.initializeSession(
              userId: extractedUserId,
              accessToken: token,
              refreshToken: data['refresh_token']?.toString(),
              userName: name,
              userEmail: email,
              role: data['role']?.toString() ?? 'OWNER',
              deviceId: deviceId,
            );

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_name', name);
            await prefs.setString('email', email);
            if (data['shop_name'] != null) {
              await prefs.setString('shop_name', data['shop_name'].toString());
            }

            return GoogleSignInResult(
              success: true,
              isNewUser: data['is_new_user'] == true,
              token: token,
              email: email,
              name: name,
              photoUrl: photoUrl,
            );
          }
        }

        // Backend returned non-200 — handle gracefully
        if (kDebugMode) {
          debugPrint('⚠️ Backend /auth/google returned ${response.statusCode}, using fallback');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Backend Google auth error: $e — using profile pre-fill fallback');
        }
      }

      // 3. Fallback: If backend doesn't support /auth/google yet, we route to register
      return GoogleSignInResult(
        success: true,
        isFallback: true,
        email: email,
        name: name,
        photoUrl: photoUrl,
      );
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('❌ Google Sign-In error: $e');
      return GoogleSignInResult(
        success: false,
        error: 'Google Sign-In failed. Please try again.',
      );
    }
  }

  /// Sign out from Google
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  /// Check if a user is currently signed in via Google
  static Future<bool> isSignedIn() async {
    return _googleSignIn.isSignedIn();
  }
}
