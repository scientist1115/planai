# AI 토론 챗

질문을 하나 보내면, 질문의 성격(코드/창작/사실확인/비교분석/일반)에 맞춰 2개 이상의 AI가 자동으로 선택되어 1차 답변 → 서로의 답변을 보고 보완/반박하는 토론 → 최종 종합 답변까지 만들어주는 멀티-AI 채팅 앱입니다.

## 실행

```bash
npm install
npm run dev
```

API 키 없이도 바로 동작합니다 (모의 응답 모드). 실제 AI를 연결하려면 `.env.example`을 `.env.local`로 복사하고 필요한 키를 채우세요.

```bash
cp .env.example .env.local
```

- `OPENAI_API_KEY` — https://platform.openai.com
- `ANTHROPIC_API_KEY` — https://console.anthropic.com
- `GEMINI_API_KEY` — https://aistudio.google.com/apikey

키가 설정된 제공자만 실제 모델을 호출하고, 나머지는 자동으로 모의 응답으로 대체되어 섞여서 동작합니다.

## 동작 방식

1. `src/lib/providers/index.ts`의 `classifyTopic`이 키워드 기반으로 질문 주제를 분류합니다.
2. 주제별로 가장 적합한 2~3개 AI(`selectDebaters`)를 선택합니다.
3. `src/lib/orchestrator.ts`의 `runDebate`가 1차 답변 → 상대 답변을 참고한 토론 2차 답변 → 종합자 역할의 AI가 최종 답을 생성하는 3단계를 거칩니다.
4. `src/app/page.tsx`가 왼쪽엔 대화 목록, 오른쪽엔 선택된 AI들의 토론 과정과 최종 답을 보여줍니다.

## 구조

```
src/
  lib/
    types.ts          공용 타입 (ChatMessage, DebateResult 등)
    providers/         AI별 어댑터 (openai/anthropic/gemini) + mock 대체 + 주제 분류/선택
    orchestrator.ts    토론 진행 로직
  app/
    api/chat/route.ts  POST 엔드포인트
    page.tsx           채팅 UI
  components/
    DebatePanel.tsx    오른쪽 토론 패널
```

## 다음 단계로 고려할 것

- 실제 LLM 기반 주제 분류 (지금은 키워드 휴리스틱)
- 스트리밍 응답 (현재는 전체 응답을 기다렸다 한 번에 표시)
- 대화 기록 저장 (현재는 새로고침하면 사라짐)
- 토론 라운드 수/참여 AI 수 사용자 설정
