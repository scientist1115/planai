// 공부 일정에 맞는 학습 자료 생성: 영단어장 / 한국사 암기(요약·연표·암기송·퀴즈) / 일반 요약·퀴즈
import { createClient } from "npm:@supabase/supabase-js@2";

const OPENAI_KEY = Deno.env.get("OPENAI_API_KEY") ?? "";
const MODEL = Deno.env.get("OPENAI_MODEL") ?? "gpt-4o";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const quiz = {
  type: "array",
  description: "4지선다 퀴즈 5~10문항",
  items: {
    type: "object",
    properties: {
      question: { type: "string" },
      options: { type: "array", items: { type: "string" }, description: "보기 정확히 4개" },
      answer: { type: "integer", description: "정답 보기의 번호 (0~3)" },
      explanation: { type: "string", description: "왜 정답인지 한두 문장" },
    },
    required: ["question", "options", "answer", "explanation"],
  },
};

const TOOLS: Record<string, any> = {
  vocab: {
    name: "make_vocab",
    description: "외우기 쉬운 영단어장을 만든다",
    input_schema: {
      type: "object",
      properties: {
        title: { type: "string" },
        words: {
          type: "array",
          items: {
            type: "object",
            properties: {
              word: { type: "string" },
              part_of_speech: { type: "string", description: "품사 (예: 동사, 명사)" },
              meaning: { type: "string", description: "핵심 한국어 뜻" },
              example: { type: "string", description: "쉬운 영어 예문" },
              example_ko: { type: "string", description: "예문 해석" },
              mnemonic: { type: "string", description: "한국어 연상 암기법 (발음이나 이미지로 연결)" },
            },
            required: ["word", "part_of_speech", "meaning", "example", "example_ko", "mnemonic"],
          },
        },
        quiz,
      },
      required: ["title", "words", "quiz"],
    },
  },
  history: {
    name: "make_history",
    description: "한국사 암기 자료를 만든다",
    input_schema: {
      type: "object",
      properties: {
        title: { type: "string" },
        summary: { type: "string", description: "핵심 흐름 요약 5~8문장" },
        keywords: {
          type: "array",
          items: {
            type: "object",
            properties: { term: { type: "string" }, desc: { type: "string" } },
            required: ["term", "desc"],
          },
        },
        timeline: {
          type: "array",
          items: {
            type: "object",
            properties: { when: { type: "string", description: "연도나 시기" }, what: { type: "string" } },
            required: ["when", "what"],
          },
        },
        song: {
          type: "object",
          properties: {
            melody_hint: { type: "string", description: "따라 부를 만한 잘 알려진 전래동요 등 멜로디 이름" },
            lyrics: { type: "string", description: "직접 창작한 암기송 가사 (핵심 순서·인물·사건이 들어가게)" },
          },
          required: ["lyrics"],
        },
        quiz,
      },
      required: ["title", "summary", "keywords", "timeline", "song", "quiz"],
    },
  },
  general: {
    name: "make_general",
    description: "공부 내용을 요약하고 퀴즈를 만든다",
    input_schema: {
      type: "object",
      properties: {
        title: { type: "string" },
        summary: { type: "string" },
        key_points: { type: "array", items: { type: "string" } },
        quiz,
      },
      required: ["title", "summary", "key_points", "quiz"],
    },
  },
};

const GUIDE: Record<string, string> = {
  vocab: "영어 단어장을 만든다. 사용자가 단어를 주면 그 단어들로, 안 주면 주제와 수준에 맞는 단어 15~20개를 골라라. 사진이나 파일이 있으면 거기 나온 단어를 우선한다. 연상 암기법은 한국 학생이 바로 떠올릴 수 있게 재밌고 짧게 써라.",
  history: "한국사 암기 자료를 만든다. 한국사능력검정시험에 자주 나오는 핵심 위주로, 사실 관계가 정확해야 한다. 암기송 가사는 직접 새로 지어라 — 기존 노래 가사를 인용하지 마라. 멜로디는 누구나 아는 전래동요 같은 것을 추천만 한다.",
  general: "공부 내용을 핵심만 요약하고, 이해를 확인하는 퀴즈를 만든다.",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const auth = req.headers.get("Authorization") ?? "";
    const supa = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: auth } },
    });
    const { data: { user } } = await supa.auth.getUser(auth.replace("Bearer ", ""));
    if (!user) return json({ error: "로그인이 필요해요" }, 401);

    const body = await req.json();
    const kind: string = body.kind;
    const tool = TOOLS[kind];
    if (!tool) return json({ error: "알 수 없는 자료 종류" }, 400);

    // 내 일정인지 확인 (RLS 덕분에 남의 일정은 안 보임)
    const { data: ev } = await supa.from("events").select("id").eq("id", body.event_id).maybeSingle();
    if (!ev) return json({ error: "일정을 찾을 수 없어요" }, 404);

    const { data: profile } = await supa.from("profiles").select("grade,goals").eq("id", user.id).maybeSingle();

    const content: any[] = [];
    const file: string | undefined = body.file;
    const mime: string = body.file_mime ?? "";
    let fileText = "";
    if (file) {
      if (mime.startsWith("image/")) {
        content.push({ type: "image_url", image_url: { url: `data:${mime};base64,${file}` } });
      } else if (mime === "application/pdf") {
        content.push({ type: "file", file: { filename: "material.pdf", file_data: `data:application/pdf;base64,${file}` } });
      } else if (mime === "text/plain") {
        const bytes = Uint8Array.from(atob(file), (c) => c.charCodeAt(0));
        fileText = new TextDecoder().decode(bytes).slice(0, 30000);
      }
    }
    content.push({
      type: "text",
      text: `일정: ${body.event_title ?? ""}
과목: ${body.subject || "-"}
학습자 수준: ${profile?.grade ?? "-"} / 목표: ${profile?.goals || "-"}
요청 내용: ${String(body.text ?? "").slice(0, 6000) || "(없음 — 일정 제목과 과목을 보고 알맞게 정해 줘)"}
${fileText ? "첨부 텍스트:\n" + fileText : ""}`,
    });

    const r = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: { Authorization: `Bearer ${OPENAI_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        model: MODEL,
        max_completion_tokens: 8000,
        tools: [{ type: "function", function: { name: tool.name, description: tool.description, parameters: tool.input_schema } }],
        tool_choice: { type: "function", function: { name: tool.name } },
        messages: [
          { role: "system", content: `너는 학생이 쉽게 외우도록 돕는 학습 자료 제작자다. 모든 설명은 한국어로 쓴다. ${GUIDE[kind]}` },
          { role: "user", content },
        ],
      }),
    });
    if (!r.ok) {
      console.error(await r.text());
      return json({ error: "AI 호출 실패" }, 502);
    }
    const data = await r.json();
    let out: any = null;
    try {
      out = JSON.parse(data.choices?.[0]?.message?.tool_calls?.[0]?.function?.arguments ?? "null");
    } catch (_) { out = null; }
    if (!out) return json({ error: "자료를 만들지 못했어요" }, 502);

    const { data: saved, error } = await supa.from("study_sets").insert({
      user_id: user.id,
      event_id: body.event_id,
      subject: body.subject ?? "",
      kind,
      content: out,
    }).select().single();
    if (error) throw error;
    return json(saved);
  } catch (e) {
    console.error(e);
    return json({ error: String(e) }, 500);
  }
});
