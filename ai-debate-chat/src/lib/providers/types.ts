import { ChatMessage, ProviderColor } from "../types";

export type { ChatMessage, ChatRole } from "../types";

export interface AIProvider {
  /** Stable id used as a React key and in API responses. */
  id: string;
  /** Display name shown in the UI, e.g. "GPT". */
  name: string;
  /** Short brand/persona description shown under the name. */
  tagline: string;
  /** Tailwind color token used for avatar/badge accents. */
  color: ProviderColor;
  /** True when a real API key is configured; false means mock mode. */
  available: boolean;
  generate(messages: ChatMessage[]): Promise<string>;
}
