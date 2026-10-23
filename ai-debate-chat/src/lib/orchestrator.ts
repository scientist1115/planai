import { AIProvider, classifyTopic, getAllProviders, selectDebaters } from "./providers";
import { ChatMessage, DebateResult, DebaterResult } from "./types";

export async function runDebate(
  history: ChatMessage[],
  userPrompt: string
): Promise<DebateResult> {
  const topic = classifyTopic(userPrompt);
  const all = getAllProviders();
  const debaters = selectDebaters(topic, all);

  const baseMessages: ChatMessage[] = [
    {
      role: "system",
      content:
        "당신은 사용자의 질문에 간결하고 실질적인 도움을 주는 AI입니다. 2~4문장으로 핵심만 답하세요.",
    },
    ...history,
    { role: "user", content: userPrompt },
  ];

  // Round 1: each debater answers independently, in parallel.
  const round1 = await Promise.all(
    debaters.map((p) => safeGenerate(p, baseMessages))
  );

  // Round 2: each debater sees everyone else's round-1 answer and reacts
  // (agree / refine / push back), in parallel.
  const round2 = await Promise.all(
    debaters.map((p, i) => {
      const others = debaters
        .map((o, j) => (j === i ? null : `${o.name}의 답변: "${round1[j]}"`))
        .filter(Boolean)
        .join("\n");
      const debateMessages: ChatMessage[] = [
        ...baseMessages,
        { role: "assistant", content: round1[i] },
        {
          role: "user",
          content: `다른 AI의 답변을 참고해서 당신의 답을 1~2문장으로 보완하거나, 동의하지 않는 부분이 있으면 반박하세요.\n\n${others}`,
        },
      ];
      return safeGenerate(p, debateMessages);
    })
  );

  const debaterResults: DebaterResult[] = debaters.map((p, i) => ({
    id: p.id,
    name: p.name,
    tagline: p.tagline,
    color: p.color,
    available: p.available,
    round1: round1[i],
    round2: round2[i],
  }));

  // Synthesis: prefer a real (non-mock) debater as moderator; fall back to the first.
  const moderator = debaters.find((p) => p.available) ?? debaters[0];
  const transcript = debaterResults
    .map((d) => `${d.name} (1차): ${d.round1}\n${d.name} (2차 보완): ${d.round2}`)
    .join("\n\n");

  const final = await safeGenerate(moderator, [
    {
      role: "system",
      content:
        "당신은 여러 AI의 토론 결과를 종합해 사용자에게 줄 최종 답변을 만드는 중재자입니다. 서로 동의한 점과 대립한 점을 반영해 가장 균형 잡히고 실용적인 하나의 답으로 정리하세요. 3~6문장.",
    },
    {
      role: "user",
      content: `질문: ${userPrompt}\n\n토론 내용:\n${transcript}\n\n위 토론을 종합한 최종 답변을 작성하세요.`,
    },
  ]);

  return { topic, debaters: debaterResults, final, synthesizedBy: moderator.name };
}

async function safeGenerate(provider: AIProvider, messages: ChatMessage[]): Promise<string> {
  try {
    return await provider.generate(messages);
  } catch (err) {
    console.error(`[${provider.id}] generate failed`, err);
    return `(${provider.name} 응답 실패: ${err instanceof Error ? err.message : "알 수 없는 오류"})`;
  }
}
