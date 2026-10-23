import { AIProvider, ChatMessage } from "./types";
import { createMockProvider } from "./mock";

const MODEL = process.env.OPENAI_MODEL || "gpt-4o-mini";

export function createOpenAIProvider(): AIProvider {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    return createMockProvider("openai", "GPT", "OpenAI · 균형잡힌 범용 추론", "emerald", "실용적이고 구조화된");
  }

  return {
    id: "openai",
    name: "GPT",
    tagline: "OpenAI · 균형잡힌 범용 추론",
    color: "emerald",
    available: true,
    async generate(messages: ChatMessage[]) {
      const res = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model: MODEL,
          messages,
          temperature: 0.7,
        }),
      });
      if (!res.ok) {
        throw new Error(`OpenAI API error ${res.status}: ${await res.text()}`);
      }
      const data = await res.json();
      return data.choices?.[0]?.message?.content ?? "";
    },
  };
}
