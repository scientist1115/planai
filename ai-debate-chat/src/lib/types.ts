export type ChatRole = "system" | "user" | "assistant";

export interface ChatMessage {
  role: ChatRole;
  content: string;
}

export type ProviderColor = "emerald" | "violet" | "sky" | "amber";
export type Topic = "code" | "creative" | "factual" | "analysis" | "general";

export interface DebaterResult {
  id: string;
  name: string;
  tagline: string;
  color: ProviderColor;
  available: boolean;
  round1: string;
  round2: string;
}

export interface DebateResult {
  topic: Topic;
  debaters: DebaterResult[];
  final: string;
  synthesizedBy: string;
}

export interface TurnEntry {
  id: string;
  prompt: string;
  status: "loading" | "done" | "error";
  result?: DebateResult;
  error?: string;
}
