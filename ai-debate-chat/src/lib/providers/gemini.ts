import { AIProvider, ChatMessage } from "./types";
import { createMockProvider } from "./mock";

const MODEL = process.env.GEMINI_MODEL || "gemini-2.0-flash";

export function createGeminiProvider(): AIProvider {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    return createMockProvider("gemini", "Gemini", "Google · 최신 정보와 창의적 발상", "sky", "폭넓고 창의적인");
  }

  return {
    id: "gemini",
    name: "Gemini",
    tagline: "Google · 최신 정보와 창의적 발상",
    color: "sky",
    available: true,
    async generate(messages: ChatMessage[]) {
      const system = messages.find((m) => m.role === "system")?.content;
      const contents = messages
        .filter((m) => m.role !== "system")
        .map((m) => ({
          role: m.role === "assistant" ? "model" : "user",
          parts: [{ text: m.content }],
        }));

      const res = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${apiKey}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            contents,
            systemInstruction: system ? { parts: [{ text: system }] } : undefined,
          }),
        }
      );
      if (!res.ok) {
        throw new Error(`Gemini API error ${res.status}: ${await res.text()}`);
      }
      const data = await res.json();
      return data.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
    },
  };
}
