import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';

class AuthService {
  static GoTrueClient get _a => Supabase.instance.client.auth;

  /// 카카오: Supabase가 기본 지원하는 OAuth 공급자
  static Future<void> kakao() async {
    await _a.signInWithOAuth(OAuthProvider.kakao, redirectTo: AppConfig.authRedirect);
  }

  /// 네이버: Supabase 기본 공급자가 아니라서,
  /// 앱에서 네이버 토큰을 받고 → Edge Function(naver-login)이 검증 → 일회용 로그인 토큰을 돌려줌
  static Future<void> naver() async {
    final res = await FlutterNaverLogin.logIn();
    if (res.status != NaverLoginStatus.loggedIn) {
      throw Exception('네이버 로그인이 취소되었어요');
    }
    final token = await FlutterNaverLogin.currentAccessToken;
    final r = await Supabase.instance.client.functions.invoke(
      'naver-login',
      body: {'access_token': token.accessToken},
    );
    final data = r.data is String ? jsonDecode(r.data as String) : r.data;
    final hash = (data as Map)['token_hash'] as String;
    await _a.verifyOTP(type: OtpType.magiclink, tokenHash: hash);
  }

  /// Apple: 카카오·네이버 로그인을 넣으면 iOS 심사에서 필수 (App Store 가이드라인 4.8)
  static Future<void> apple() async {
    final rawNonce = _a.generateRawNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
    final cred = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      nonce: hashedNonce,
    );
    final idToken = cred.identityToken;
    if (idToken == null) throw Exception('Apple 로그인 정보를 받지 못했어요');
    await _a.signInWithIdToken(provider: OAuthProvider.apple, idToken: idToken, nonce: rawNonce);
  }

  /// 반환값: 이메일 인증이 필요하면 true
  static Future<bool> signUpEmail(String email, String password) async {
    final res = await _a.signUp(email: email, password: password);
    return res.session == null;
  }

  static Future<void> signInEmail(String email, String password) async {
    await _a.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() => _a.signOut();

  /// 앱 안에서 계정 삭제 (애플·구글 둘 다 필수 요건)
  static Future<void> deleteAccount() async {
    await Supabase.instance.client.functions.invoke('delete-account');
    await _a.signOut();
  }
}
