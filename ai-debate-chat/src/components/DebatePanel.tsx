import { DebateResult } from "@/lib/types";
import { colorClasses } from "./colors";

const TOPIC_LABEL: Record<DebateResult["topic"], string> = {
  code: "코드 / 기술",
  creative: "창작 / 아이디어",
  factual: "사실 확인",
  analysis: "비교 / 분석",
  general: "일반",
};

export function DebatePanelLoading() {
  return (
    <div className="flex flex-col gap-3 animate-pulse">
      <div className="h-4 w-24 rounded bg-zinc-200 dark:bg-zinc-800" />
      {[0, 1].map((i) => (
        <div key={i} className="rounded-xl border border-zinc-200 dark:border-zinc-800 p-3 space-y-2">
          <div className="h-3 w-20 rounded bg-zinc-200 dark:bg-zinc-800" />
          <div className="h-3 w-full rounded bg-zinc-200 dark:bg-zinc-800" />
          <div className="h-3 w-2/3 rounded bg-zinc-200 dark:bg-zinc-800" />
        </div>
      ))}
      <p className="text-xs text-zinc-400">AI들이 토론 중입니다…</p>
    </div>
  );
}

export function DebatePanel({ result }: { result: DebateResult }) {
  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <span className="text-xs font-medium text-zinc-500 dark:text-zinc-400">
          주제: {TOPIC_LABEL[result.topic]}
        </span>
        <span className="text-xs text-zinc-400">{result.debaters.length}개 AI 토론</span>
      </div>

      {result.debaters.map((d) => {
        const c = colorClasses[d.color];
        return (
          <div key={d.id} className={`rounded-xl border ${c.border} ${c.bg} p-3 space-y-2`}>
            <div className="flex items-center gap-2">
              <span className={`h-2 w-2 rounded-full ${c.dot}`} />
              <span className={`text-sm font-semibold ${c.text}`}>{d.name}</span>
              <span className="text-[11px] text-zinc-400">{d.tagline}</span>
            </div>
            <div className="text-sm text-zinc-700 dark:text-zinc-300">
              <span className="text-[11px] font-medium uppercase text-zinc-400">1차 답변</span>
              <p className="mt-0.5">{d.round1}</p>
            </div>
            <div className="text-sm text-zinc-700 dark:text-zinc-300 border-t border-dashed border-zinc-300 dark:border-zinc-700 pt-2">
              <span className="text-[11px] font-medium uppercase text-zinc-400">토론 후 보완</span>
              <p className="mt-0.5">{d.round2}</p>
            </div>
          </div>
        );
      })}

      <div className="rounded-xl border-2 border-zinc-900 dark:border-zinc-100 p-3 bg-zinc-900 text-zinc-50 dark:bg-zinc-100 dark:text-zinc-900">
        <span className="text-[11px] font-semibold uppercase opacity-70">
          최종 종합 ({result.synthesizedBy})
        </span>
        <p className="mt-1 text-sm">{result.final}</p>
      </div>
    </div>
  );
}
