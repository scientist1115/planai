import { AIProvider, ChatMessage } from "./types";

/**
 * Deterministic, dependency-free stand-in used whenever a real provider
 * has no API key configured, so the app is fully usable out of the box.
 */
export function createMockProvider(
  id: string,
  name: string,
  tagline: string,
  color: AIProvider["color"],
  stance: string
): AIProvider {
  return {
    id,
    name: `${name} (Mock)`,
    tagline,
    color,
    available: false,
    async generate(messages: ChatMessage[]) {
      const lastUser = [...messages].reverse().find((m) => m.role === "user");
      const prompt = lastUser?.content ?? "";
      await delay(400 + Math.random() * 500);
      return `[모의 응답 - API 키 미설정] "${truncate(prompt, 60)}"에 대한 ${stance} 관점의 답변입니다. 실제 ${name} 답변을 받으려면 .env.local에 API 키를 추가하세요.`;
    },
  };
}

function truncate(s: string, n: number) {
  return s.length > n ? s.slice(0, n) + "…" : s;
}

function delay(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
