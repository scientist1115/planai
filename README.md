# PlanAI — 말만 하면 계획이 완성되는 AI 플래너

Flutter(안드로이드·iOS 한 번에) + Supabase(로그인·DB·서버 함수) + OpenAI API로 만든 앱입니다.

## 들어 있는 기능

| 화면 | 기능 |
|---|---|
| 로그인 | 카카오 · 네이버 · Apple(iOS) · 이메일 가입/로그인 |
| 온보딩 | 닉네임, 출생 연도, 학년, 기상/취침 시간, 목표 수집 · 만 14세 미만 보호자 동의 · 약관 동의 |
| **AI 대화 (첫 화면)** | 말이나 사진(시간표·공지)으로 일정 추가 → AI가 날짜·시간·우선순위·과목을 정리해 카드로 제안 → 확인하면 저장 + 알림 예약. 정보가 모자라면 AI가 되묻고, 시간이 없으면 기상·취침 시간과 기존 일정을 보고 빈 시간에 배치. "운동했어" → 습관 체크, "오늘 ○○가 고마웠어" → 감사일기 |
| 달력 | 월간(조감도) / 2주 / 주간 전환, 우선순위 색 점, 습관 달성 ⭐, 이번 달 중요 일정 목록 |
| **하루 상세** | 일정 체크, 우선순위 4칸 매트릭스, 습관 체크, 메모(브레인 덤프), 기분 + 감사일기, **공부 일정의 [학습] 버튼** |
| **학습 시스템** | 영어 → 단어 카드(뜻·예문·연상 암기법) + 퀴즈 / 한국사 → 요약·연표·암기송 가사·퀴즈 / 그 외 → 요약·퀴즈. 텍스트, 교재 사진, PDF·TXT 파일 입력 가능 |
| 습관 | 습관 추가/삭제, 오늘 체크, 이번 달 달성률 |
| 알림 | 일정 10분 전 알림, 매일 기상 시간 아침 브리핑 (기기 안에서 예약 → 서버 필요 없음) |
| 설정 | 기상/취침/목표 수정, 알림, 개인정보처리방침, 로그아웃, **계정 삭제** |
| 스토어 대응 | Apple 로그인, 앱 내 계정 삭제, AI 응답 신고(길게 누르기/깃발 버튼), 14세 미만 보호자 동의 |

## 폴더 구조

```
lib/
  main.dart                 앱 시작, 로그인 여부/온보딩 여부에 따라 화면 분기
  config.dart               Supabase 주소·키, 개인정보처리방침 주소
  models.dart, utils.dart   데이터 모양, 공용 함수
  services/  db.dart  ai.dart  auth.dart  notify.dart
  screens/   login, onboarding, home_shell, chat, calendar, day_detail, study, habits, settings
  widgets/   event_editor, study_widgets(카드·퀴즈·연표·암기송), report
supabase/
  migrations/001_init.sql   DB 표 + 보안 규칙
  functions/ai-chat         대화 → 일정 제안
  functions/ai-study        학습 자료 생성
  functions/naver-login     네이버 로그인 연결
  functions/delete-account  계정 삭제
platform_snippets/          안드로이드·iOS 설정 파일에 붙여 넣을 내용
docs/privacy_policy.md      개인정보처리방침 초안
```

## 설치 순서

### 1. Flutter 프로젝트 만들기
```bash
# Flutter 3.24 이상 설치 후, 이 폴더 안에서
flutter create --org io.planai --project-name planai --platforms android,ios .
flutter pub get
```
`flutter create .` 는 이미 있는 lib 파일은 건드리지 않고 android/ios 폴더만 만들어 줍니다.
그다음 `platform_snippets/` 안의 내용을 AndroidManifest.xml, build.gradle, Info.plist, AppDelegate.swift 에 붙여 넣으세요.

### 2. Supabase
1. supabase.com 에서 새 프로젝트 만들기 (지역: Seoul)
2. SQL Editor 에 `supabase/migrations/001_init.sql` 붙여 넣고 Run
3. Supabase CLI 설치 후:
```bash
supabase login
supabase link --project-ref <프로젝트 ref>
supabase secrets set OPENAI_API_KEY=sk-...
supabase functions deploy ai-chat
supabase functions deploy ai-study
supabase functions deploy delete-account
supabase functions deploy naver-login --no-verify-jwt
```
4. Authentication > URL Configuration > Redirect URLs 에 `io.planai.app://login-callback` 추가

### 3. 로그인 연결
- **카카오**: developers.kakao.com 에서 앱 만들기 → 카카오 로그인 켜기 → Redirect URI 에 `https://<프로젝트>.supabase.co/auth/v1/callback` 등록 → 동의항목에서 닉네임·이메일 설정. Supabase > Authentication > Providers > Kakao 에 REST API 키와 Client Secret 입력.
- **네이버**: developers.naver.com 에서 애플리케이션 등록 (사용 API: 네이버 로그인, 제공 정보: 이메일·별명). 안드로이드 패키지명과 iOS 번들 ID, URL 스킴 등록 후 `flutter_naver_login` 패키지 README 대로 클라이언트 ID/시크릿을 앱 설정에 넣기.
- **Apple**: Apple Developer 에서 App ID 에 Sign in with Apple 켜기 → Xcode Capabilities 에 추가 → Supabase > Providers > Apple 에 번들 ID 입력.

### 4. 실행
```bash
flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJ...
```

## 스토어 출시 체크리스트

**공통**
- [ ] 개인정보처리방침을 웹에 올리고 `config.dart` 의 주소 바꾸기 (`docs/privacy_policy.md` 초안 참고)
- [ ] 앱 아이콘, 스크린샷(대화 → 제안 카드 → 달력 → 단어 카드 순서 추천), 앱 설명
- [ ] 앱 이름 "PlanAI"가 이미 쓰이고 있는지 두 스토어에서 검색

**Google Play** (개발자 등록 25달러, 1회)
- [ ] 개인 계정은 테스터 12명 이상으로 14일 이상 비공개 테스트 후 정식 출시 신청 가능
- [ ] 데이터 보안(Data safety) 양식: 이름/이메일, 사용자 입력 콘텐츠(일정·일기), 사진 → "앱 기능" 목적
- [ ] 콘텐츠 등급 설문, 타깃 연령 설정 (13세 미만을 타깃에 넣으면 '가족 정책'까지 지켜야 해서 복잡해져요)
- [ ] 계정 삭제 안내 웹페이지 URL (앱 밖에서도 삭제 요청 방법 안내)
- [ ] `flutter build appbundle --release` (서명 키 만들기: Flutter 공식 문서 "Build and release an Android app")

**App Store** (연 99달러)
- [ ] Sign in with Apple 포함됨 ✅, 앱 내 계정 삭제 포함됨 ✅
- [ ] 개인정보 라벨(App Privacy) 작성
- [ ] 심사용 데모 계정(이메일 로그인) 준비해서 심사 메모에 적기
- [ ] Xcode 에서 Archive → App Store Connect 업로드 → TestFlight 로 먼저 테스트

## 참고
- AI 모델은 Supabase secret `OPENAI_MODEL` 로 바꿀 수 있어요 (기본값 `gpt-4o`). 이미지·도구 호출(function calling)을 지원하는 모델이면 됩니다.
- AI 비용은 사용량만큼 나오니, 출시 전 OpenAI 대시보드(Billing → Limits)에서 월 사용 한도를 걸어 두세요.
- 만 14세 미만 보호자 동의는 지금 "체크 + 이름" 방식이에요. 실제 출시 땐 보호자 휴대폰 인증 같은 확인 절차를 붙이는 게 안전합니다.
- 네이버 로그인은 이메일로 계정을 연결하므로, 운영 전에 네이버 토큰이 우리 앱에서 발급된 것인지 확인하는 절차를 추가하면 더 안전해요.
