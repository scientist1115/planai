-- PlanAI 데이터베이스 (Supabase SQL Editor에 붙여넣고 실행)
-- 모든 표에 RLS(행 수준 보안)를 켜서, 각 사용자는 자기 데이터만 볼 수 있어요.

create extension if not exists pgcrypto;

-- 사용자 기본 정보 (온보딩)
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nickname text not null default '',
  birth_year int,
  grade text,
  wake_time text default '07:00',
  sleep_time text default '23:00',
  goals text,
  guardian_consent boolean default false,   -- 만 14세 미만 보호자 동의
  guardian_name text,
  agreed_at timestamptz,                    -- 약관/개인정보 동의 시각
  onboarded boolean default false,
  created_at timestamptz default now()
);

-- 일정
create table public.events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null,
  start_at timestamptz not null,
  end_at timestamptz,
  category text not null default '기타',
  subject text,                                            -- 공부일 때 과목
  quadrant smallint not null default 4 check (quadrant between 1 and 4),  -- 1 중요·급함 / 2 중요 / 3 급함 / 4 나중에
  done boolean not null default false,
  notes text,
  created_at timestamptz default now()
);
create index events_user_start on public.events (user_id, start_at);

-- 습관 & 체크 기록
create table public.habits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  emoji text default '✅',
  created_at timestamptz default now()
);

create table public.habit_logs (
  id uuid primary key default gen_random_uuid(),
  habit_id uuid not null references public.habits(id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  day date not null,
  unique (habit_id, day)
);

-- 하루 기록: 메모(브레인 덤프) · 감사일기 · 기분
create table public.day_journals (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  day date not null,
  memo text,
  gratitude text,
  mood smallint check (mood between 1 and 5),
  updated_at timestamptz default now(),
  primary key (user_id, day)
);

-- AI가 만든 학습 자료 (단어장, 암기송, 연표, 퀴즈)
create table public.study_sets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  event_id uuid references public.events(id) on delete cascade,
  subject text,
  kind text not null check (kind in ('vocab', 'history', 'general')),
  content jsonb not null,
  created_at timestamptz default now()
);

-- AI 대화 기록
create table public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  role text not null check (role in ('user', 'assistant')),
  content text not null,
  meta text,          -- AI가 제안한 일정 요약 (화면엔 안 보이고, 다음 대화 때 AI가 참고)
  created_at timestamptz default now()
);
create index chat_user_time on public.chat_messages (user_id, created_at);

-- AI 응답 신고 (구글 플레이 AI 콘텐츠 정책)
create table public.ai_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  source text,
  content text,
  reason text,
  created_at timestamptz default now()
);

-- ── 보안: 자기 데이터만 ──
alter table public.profiles      enable row level security;
alter table public.events        enable row level security;
alter table public.habits        enable row level security;
alter table public.habit_logs    enable row level security;
alter table public.day_journals  enable row level security;
alter table public.study_sets    enable row level security;
alter table public.chat_messages enable row level security;
alter table public.ai_reports    enable row level security;

create policy own_profile on public.profiles      for all using (id = auth.uid())      with check (id = auth.uid());
create policy own_events  on public.events        for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy own_habits  on public.habits        for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy own_logs    on public.habit_logs    for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy own_journal on public.day_journals  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy own_study   on public.study_sets    for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy own_chat    on public.chat_messages for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy report_ins  on public.ai_reports    for insert with check (user_id = auth.uid());
create policy report_sel  on public.ai_reports    for select using (user_id = auth.uid());
