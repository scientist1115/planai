import { AIProvider, ChatMessage } from "./types";
import { createMockProvider } from "./mock";

const MODEL = process.env.ANTHROPIC_MODEL || "claude-sonnet-5-5";

export function createAnthropicProvider(): AIProvider {
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    return createMockProvider("anthropic", "Claude", "Anthropic · 신중하고 근거 중심적", "violet", "신중하고 맥락을 고려한");
  }

  return {
    id: "anthropic",
    name: "Claude",
    tagline: "Anthropic · 신중하고 근거 중심적",
    color: "violet",
    available: true,
    async generate(messages: ChatMessage[]) {
      const system = messages.find((m) => m.role === "system")?.content;
      const rest = messages
        .filter((m) => m.role !== "system")
        .map((m) => ({ role: m.role, content: m.content }));

      const res = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": apiKey,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model: MODEL,
          max_tokens: 1024,
          system,
          messages: rest,
        }),
      });
      if (!res.ok) {
        throw new Error(`Anthropic API error ${res.status}: ${await res.text()}`);
      }
      const data = await res.json();
      return data.content?.[0]?.text ?? "";
    },
  };
}
