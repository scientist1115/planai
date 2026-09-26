// AI 플래너 대화: 사용자의 말(또는 사진)을 일정/습관/하루 기록 "제안"으로 바꿔 돌려준다.
// 실제 저장은 앱에서 사용자가 '모두 추가'를 눌렀을 때만 일어난다.
import { createClient } from "npm:@supabase/supabase-js@2";

const OPENAI_KEY = Deno.env.get("OPENAI_API_KEY") ?? "";
const MODEL = Deno.env.get("OPENAI_MODEL") ?? "gpt-4o";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const CATEGORIES = ["공부", "학교/일", "운동", "약속", "생활", "기타"];
const QUAD = ["", "중요·급함", "중요", "급함", "나중에"];

const tools = [
  {
    name: "propose_events",
    description: "사용자가 말한 할 일을 플래너 일정으로 제안한다. 사용자가 앱에서 확인해야 저장된다.",
    input_schema: {
      type: "object",
      properties: {
        events: {
          type: "array",
          items: {
            type: "object",
            properties: {
              title: { type: "string", description: "짧은 일정 제목" },
              date: { type: "string", description: "YYYY-MM-DD" },
              start: { type: "string", description: "HH:MM (24시간)" },
              end: { type: "string", description: "HH:MM (24시간), 모르면 생략" },
              category: { type: "string", enum: CATEGORIES },
              subject: { type: "string", description: "공부일 때 과목: 영어, 한국사, 수학, 국어, 과학, 사회, 기타" },
              quadrant: { type: "integer", enum: [1, 2, 3, 4], description: "1 중요·급함, 2 중요, 3 급함, 4 나중에" },
            },
            required: ["title", "date", "start", "category", "quadrant"],
          },
        },
      },
      required: ["events"],
    },
  },
  {
    name: "check_habits",
    description: "사용자가 오늘 해낸 습관(예: 운동, 독서)을 체크하자고 제안한다. 등록된 습관 이름이 있으면 그 이름을 그대로 쓴다.",
    input_schema: {
      type: "object",
      properties: { habits: { type: "array", items: { type: "string" } } },
      required: ["habits"],
    },
  },
  {
    name: "save_journal",
    description: "오늘의 감사한 일, 기분(1~5), 떠오른 생각 메모를 하루 기록에 저장하자고 제안한다.",
    input_schema: {
      type: "object",
      properties: {
        gratitude: { type: "string" },
        mood: { type: "integer", minimum: 1, maximum: 5 },
        memo: { type: "string" },
      },
    },
  },
];

function fmt(iso: string, tz: string) {
  return new Date(iso).toLocaleString("ko-KR", {
    timeZone: tz, month: "numeric", day: "numeric", weekday: "short",
    hour: "2-digit", minute: "2-digit", hour12: false,
  });
}

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
    const message: string = String(body.message ?? "").slice(0, 4000);
    const now: string = String(body.now ?? "");
    const tz: string = String(body.tz ?? "Asia/Seoul");
    const image: string | undefined = body.image;
    const imageMime: string = body.image_mime ?? "image/jpeg";

    const from = new Date(Date.now() - 24 * 3600e3).toISOString();
    const to = new Date(Date.now() + 14 * 24 * 3600e3).toISOString();
    const [{ data: profile }, { data: habits }, { data: events }, { data: history }] = await Promise.all([
      supa.from("profiles").select("*").eq("id", user.id).maybeSingle(),
      supa.from("habits").select("name"),
      supa.from("events").select("title,start_at,end_at,category,subject,quadrant,done")
        .gte("start_at", from).lt("start_at", to).order("start_at").limit(80),
      supa.from("chat_messages").select("role,content,meta").order("created_at", { ascending: false }).limit(16),
    ]);

    const eventLines = (events ?? []).map((e: any) =>
      `- ${fmt(e.start_at, tz)}${e.end_at ? "~" + fmt(e.end_at, tz).split(" ").pop() : ""} ${e.title} [${e.category}${e.subject ? "/" + e.subject : ""}/${QUAD[e.quadrant] ?? ""}]${e.done ? " (완료)" : ""}`
    ).join("\n") || "(없음)";

    const system = `너는 'PlanAI' 앱의 플래너 비서다. 사람들이 플래너를 안 쓰는 이유는 시간과 일정을 하나하나 고르기 귀찮아서다. 너는 사용자가 대화로 말한 내용을 일정으로 정리해 주는 역할이다.

현재 시각(사용자 기준): ${now} / 시간대: ${tz}
사용자 정보: 닉네임 ${profile?.nickname ?? "-"}, 출생연도 ${profile?.birth_year ?? "-"}, 학년/신분 ${profile?.grade ?? "-"}, 기상 ${profile?.wake_time ?? "07:00"}, 취침 ${profile?.sleep_time ?? "23:00"}, 목표: ${profile?.goals || "-"}
등록된 습관: ${(habits ?? []).map((h: any) => h.name).join(", ") || "(없음)"}
앞으로 2주 일정:
${eventLines}

규칙:
1. "내일", "모레", "다음 주 금요일" 같은 말은 현재 시각 기준으로 정확한 YYYY-MM-DD로 바꾼다.
2. 무엇을 할지 또는 어느 날인지 알 수 없으면 도구를 쓰지 말고 짧게 되묻는다. 질문은 한 번에 하나만.
3. 날짜는 아는데 시간이 없으면, 기상~취침 사이에서 기존 일정과 겹치지 않는 알맞은 시간을 직접 골라 제안하고 "시간은 ○시로 잡았어요, 바꾸고 싶으면 말해 주세요"처럼 알려 준다. 학생이면 평일 낮(08:30~16:00)은 학교 시간으로 보고 피한다.
4. 시험·마감·수행평가처럼 큰 일은 그 날짜에 일정을 넣고, 사용자가 원하거나 "계획 짜줘"라고 하면 준비 일정을 며칠에 나눠 여러 개 제안한다.
5. quadrant: 1=곧 닥친 시험·마감(중요·급함), 2=꾸준히 할 공부·운동·준비(중요), 3=급하지만 덜 중요한 잡일, 4=나머지.
6. 공부 일정은 category를 '공부'로, subject를 반드시 채운다.
7. 사용자가 습관을 해냈다고 말하면 check_habits, 감사한 일·기분·떠오른 생각을 말하면 save_journal을 쓴다.
8. 사진이 오면 시간표·공지·계획표에서 날짜와 시간을 읽어 일정으로 제안한다.
9. 답은 친근한 존댓말로 3문장 이내. 제안한 일정을 글로 다시 나열하지 말고(앱이 카드로 보여 준다) 핵심만 말한다.
10. 일정과 상관없는 질문에도 짧게 도와주되 플래너 비서 역할을 유지한다.`;

    // 대화 기록 → 메시지 (같은 역할이 연달아 오면 합침, 첫 메시지는 user)
    const msgs: any[] = [];
    for (const h of (history ?? []).slice().reverse()) {
      const role = h.role === "user" ? "user" : "assistant";
      const text = h.content + (h.meta ? "\n" + h.meta : "");
      const last = msgs[msgs.length - 1];
      if (last && last.role === role) last.content += "\n" + text;
      else msgs.push({ role, content: text });
    }
    while (msgs.length && msgs[0].role !== "user") msgs.shift();

    const userContent: any[] = [];
    if (image) userContent.push({ type: "image_url", image_url: { url: `data:${imageMime};base64,${image}` } });
    userContent.push({ type: "text", text: message || "이 사진에서 일정을 찾아 줘" });
    const last = msgs[msgs.length - 1];
    if (last && last.role === "user") {
      last.content = [{ type: "text", text: last.content }, ...userContent];
    } else {
      msgs.push({ role: "user", content: userContent });
    }

    const r = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: { Authorization: `Bearer ${OPENAI_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        model: MODEL,
        max_completion_tokens: 1500,
        tools: tools.map((t) => ({
          type: "function",
          function: { name: t.name, description: t.description, parameters: t.input_schema },
        })),
        messages: [{ role: "system", content: system }, ...msgs],
      }),
    });
    if (!r.ok) {
      console.error(await r.text());
      return json({ error: "AI 호출 실패" }, 502);
    }
    const data = await r.json();
    const msg = data.choices?.[0]?.message ?? {};

    let reply: string = msg.content ?? "";
    const outEvents: any[] = [];
    const outHabits: string[] = [];
    let journal: any = null;
    for (const tc of msg.tool_calls ?? []) {
      let args: any = {};
      try { args = JSON.parse(tc.function?.arguments || "{}"); } catch (_) { continue; }
      const name = tc.function?.name;
      if (name === "propose_events") outEvents.push(...(args.events ?? []));
      else if (name === "check_habits") outHabits.push(...(args.habits ?? []));
      else if (name === "save_journal") journal = args;
    }
    reply = reply.trim() ||
      (outEvents.length ? "이렇게 정리해 봤어요. 확인하고 추가해 주세요." : "알겠어요!");

    // 제안 내용을 meta에 남겨서, "4시 말고 5시로" 같은 다음 말을 AI가 이해할 수 있게 한다
    const metaParts: string[] = [];
    if (outEvents.length) {
      metaParts.push("[제안한 일정: " + outEvents.map((e) => `${e.date} ${e.start}${e.end ? "~" + e.end : ""} ${e.title}`).join(" / ") + "]");
    }
    if (outHabits.length) metaParts.push("[제안한 습관 체크: " + outHabits.join(", ") + "]");
    if (journal) metaParts.push("[제안한 하루 기록: " + JSON.stringify(journal) + "]");

    await supa.from("chat_messages").insert([
      { user_id: user.id, role: "user", content: (image ? "📷 " : "") + (message || "(사진)") },
      { user_id: user.id, role: "assistant", content: reply, meta: metaParts.join(" ") || null },
    ]);

    return json({ reply, events: outEvents, habits: outHabits, journal });
  } catch (e) {
    console.error(e);
    return json({ error: String(e) }, 500);
  }
});
