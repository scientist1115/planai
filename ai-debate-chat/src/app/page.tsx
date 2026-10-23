"use client";

import { useEffect, useRef, useState } from "react";
import { ChatMessage, DebateResult, TurnEntry } from "@/lib/types";
import { DebatePanel, DebatePanelLoading } from "@/components/DebatePanel";

const STORAGE_KEY = "ai-debate-chat:turns";

export default function Home() {
  const [turns, setTurns] = useState<TurnEntry[]>([]);
  const [input, setInput] = useState("");
  const [activeId, setActiveId] = useState<string | null>(null);
  const [sending, setSending] = useState(false);
  const [mobileView, setMobileView] = useState<"chat" | "debate">("chat");
  const historyRef = useRef<ChatMessage[]>([]);

  // Restore a previous session from this browser, if any.
  useEffect(() => {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return;
      const saved: TurnEntry[] = JSON.parse(raw);
      const finished = saved.filter((t) => t.status !== "loading");
      setTurns(finished);
      setActiveId(finished[finished.length - 1]?.id ?? null);
      historyRef.current = finished.flatMap((t): ChatMessage[] =>
        t.result ? [{ role: "user", content: t.prompt }, { role: "assistant", content: t.result.final }] : []
      );
    } catch {
      // ignore corrupt/unavailable storage
    }
  }, []);

  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(turns));
    } catch {
      // storage can be full or blocked; the chat still works in-memory
    }
  }, [turns]);

  async function send() {
    const prompt = input.trim();
    if (!prompt || sending) return;

    const id = crypto.randomUUID();
    const entry: TurnEntry = { id, prompt, status: "loading" };
    setTurns((prev) => [...prev, entry]);
    setActiveId(id);
    setInput("");
    setSending(true);
    setMobileView("debate");

    const history = historyRef.current;

    try {
      const res = await fetch("/api/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ prompt, history }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "요청 실패");

      const result = data as DebateResult;
      historyRef.current = [
        ...history,
        { role: "user", content: prompt },
        { role: "assistant", content: result.final },
      ];
      setTurns((prev) =>
        prev.map((t) => (t.id === id ? { ...t, status: "done", result } : t))
      );
    } catch (err) {
      setTurns((prev) =>
        prev.map((t) =>
          t.id === id
            ? { ...t, status: "error", error: err instanceof Error ? err.message : "오류" }
            : t
        )
      );
    } finally {
      setSending(false);
    }
  }

  const activeTurn = turns.find((t) => t.id === activeId) ?? turns[turns.length - 1];

  return (
    <div className="flex flex-col flex-1 min-h-0 bg-zinc-50 dark:bg-zinc-950">
      {/* Shared top bar: title + mobile tab switcher (always reachable from either pane) */}
      <header className="border-b border-zinc-200 dark:border-zinc-800 px-5 py-3 flex items-center justify-between gap-3 shrink-0">
        <div>
          <h1 className="text-base font-semibold">AI 토론 챗</h1>
          <p className="text-xs text-zinc-500">
            질문마다 성격에 맞는 2개 이상의 AI가 토론해서 답을 만들어요
          </p>
        </div>
        <div className="md:hidden flex rounded-full border border-zinc-300 dark:border-zinc-700 overflow-hidden text-xs shrink-0">
          <button
            onClick={() => setMobileView("chat")}
            className={`px-3 py-1 ${mobileView === "chat" ? "bg-zinc-900 text-zinc-50 dark:bg-zinc-100 dark:text-zinc-900" : "text-zinc-600 dark:text-zinc-400"}`}
          >
            대화
          </button>
          <button
            onClick={() => setMobileView("debate")}
            className={`px-3 py-1 ${mobileView === "debate" ? "bg-zinc-900 text-zinc-50 dark:bg-zinc-100 dark:text-zinc-900" : "text-zinc-600 dark:text-zinc-400"}`}
          >
            토론
          </button>
        </div>
      </header>

      <div className="flex flex-1 min-h-0">
      {/* Main chat column */}
      <div className={`flex-col flex-1 min-w-0 ${mobileView === "chat" ? "flex" : "hidden md:flex"}`}>
        <div className="flex-1 overflow-y-auto px-5 py-4 space-y-4">
          {turns.length === 0 && (
            <p className="text-sm text-zinc-400">
              아래에 질문을 입력해보세요. 예: &ldquo;리액트랑 스벨트 중 뭐가 나아?&rdquo;
            </p>
          )}
          {turns.map((t) => (
            <button
              key={t.id}
              onClick={() => setActiveId(t.id)}
              className={`block w-full text-left rounded-lg px-3 py-2 transition-colors ${
                t.id === activeId
                  ? "bg-white dark:bg-zinc-900 ring-1 ring-zinc-300 dark:ring-zinc-700"
                  : "hover:bg-white/60 dark:hover:bg-zinc-900/60"
              }`}
            >
              <p className="text-sm font-medium text-zinc-900 dark:text-zinc-100">{t.prompt}</p>
              {t.status === "loading" && <p className="text-xs text-zinc-400 mt-1">토론 중…</p>}
              {t.status === "error" && <p className="text-xs text-red-500 mt-1">{t.error}</p>}
              {t.status === "done" && t.result && (
                <p className="text-xs text-zinc-500 mt-1 line-clamp-2">{t.result.final}</p>
              )}
            </button>
          ))}
        </div>

        <div className="border-t border-zinc-200 dark:border-zinc-800 p-4">
          <div className="flex gap-2">
            <input
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter" && !e.shiftKey) {
                  e.preventDefault();
                  send();
                }
              }}
              placeholder="질문을 입력하세요…"
              className="flex-1 rounded-full border border-zinc-300 dark:border-zinc-700 bg-white dark:bg-zinc-900 px-4 py-2 text-sm outline-none focus:ring-2 focus:ring-zinc-400"
            />
            <button
              onClick={send}
              disabled={sending || !input.trim()}
              className="rounded-full bg-zinc-900 dark:bg-zinc-100 text-zinc-50 dark:text-zinc-900 px-5 py-2 text-sm font-medium disabled:opacity-40"
            >
              보내기
            </button>
          </div>
        </div>
      </div>

      {/* Side debate panel */}
      <aside
        className={`w-full md:w-[380px] flex-col border-l border-zinc-200 dark:border-zinc-800 bg-white dark:bg-zinc-900/40 overflow-y-auto p-4 ${
          mobileView === "debate" ? "flex" : "hidden md:flex"
        }`}
      >
        <h2 className="text-sm font-semibold mb-3 text-zinc-700 dark:text-zinc-300">AI 토론 패널</h2>
        {!activeTurn && (
          <p className="text-sm text-zinc-400">질문을 보내면 여기에 AI들의 토론이 나타나요.</p>
        )}
        {activeTurn?.status === "loading" && <DebatePanelLoading />}
        {activeTurn?.status === "error" && (
          <p className="text-sm text-red-500">{activeTurn.error}</p>
        )}
        {activeTurn?.status === "done" && activeTurn.result && (
          <DebatePanel result={activeTurn.result} />
        )}
      </aside>
      </div>
    </div>
  );
}
