/// 실행할 때 --dart-define 으로 값을 넣거나, 아래 기본값을 직접 바꿔도 됩니다.
/// (anon key는 앱에 들어가도 되는 공개 키입니다. AI API 키는 절대 여기 넣지 마세요!)
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://YOUR-PROJECT.supabase.co');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'YOUR-ANON-KEY');

  /// 카카오 로그인 후 앱으로 돌아오는 주소 (Supabase > Auth > URL Configuration 에도 등록)
  static const authRedirect = 'io.planai.app://login-callback';

  /// 개인정보처리방침 페이지 주소 (스토어 등록 필수)
  static const privacyPolicyUrl = 'https://example.com/planai/privacy';
}
