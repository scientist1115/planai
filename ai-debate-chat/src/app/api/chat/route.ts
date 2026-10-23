import { NextRequest, NextResponse } from "next/server";
import { runDebate } from "@/lib/orchestrator";
import { ChatMessage } from "@/lib/types";

export async function POST(req: NextRequest) {
  const body = await req.json();
  const prompt: string = body?.prompt;
  const history: ChatMessage[] = Array.isArray(body?.history) ? body.history : [];

  if (!prompt || typeof prompt !== "string" || !prompt.trim()) {
    return NextResponse.json({ error: "prompt is required" }, { status: 400 });
  }

  try {
    const result = await runDebate(history, prompt.trim());
    return NextResponse.json(result);
  } catch (err) {
    console.error("debate failed", err);
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "debate failed" },
      { status: 500 }
    );
  }
}
