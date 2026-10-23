import { AIProvider } from "./types";
import { createOpenAIProvider } from "./openai";
import { createAnthropicProvider } from "./anthropic";
import { createGeminiProvider } from "./gemini";
import { Topic } from "../types";

export type { AIProvider, ChatMessage, ChatRole } from "./types";
export type { Topic } from "../types";

/** The three fixed seats. Each falls back to a mock persona without an API key. */
export function getAllProviders(): AIProvider[] {
  return [createOpenAIProvider(), createAnthropicProvider(), createGeminiProvider()];
}

const TOPIC_KEYWORDS: Record<Topic, string[]> = {
  code: ["코드", "버그", "함수", "에러", "프로그램", "알고리즘", "code", "bug", "function", "api", "typescript", "python"],
  creative: ["소설", "시", "이야기", "아이디어", "창작", "카피", "브랜드", "이름", "스토리"],
  factual: ["언제", "누구", "어디", "최신", "뉴스", "가격", "몇", "날씨", "사실"],
  analysis: ["비교", "분석", "장단점", "추천", "선택", "전략", "장점", "단점", "vs"],
  general: [],
};

/** Lightweight keyword heuristic — no network call, keeps classification instant. */
export function classifyTopic(prompt: string): Topic {
  const text = prompt.toLowerCase();
  for (const topic of Object.keys(TOPIC_KEYWORDS) as Topic[]) {
    if (topic === "general") continue;
    if (TOPIC_KEYWORDS[topic].some((kw) => text.includes(kw))) {
      return topic;
    }
  }
  return "general";
}

/** Which two (or three) seats are best suited for a given topic. */
const TOPIC_SEATS: Record<Topic, string[]> = {
  code: ["openai", "anthropic"],
  creative: ["anthropic", "gemini"],
  factual: ["gemini", "openai"],
  analysis: ["openai", "anthropic", "gemini"],
  general: ["openai", "anthropic"],
};

export function selectDebaters(topic: Topic, all: AIProvider[]): AIProvider[] {
  const ids = TOPIC_SEATS[topic];
  const byId = new Map(all.map((p) => [p.id, p]));
  return ids.map((id) => byId.get(id)!).filter(Boolean);
}
