"use client";

import { useEffect, useState } from "react";

type LaunchPhase = "idle" | "loading" | "ready" | "error";

export default function Home() {
  const [phase, setPhase] = useState<LaunchPhase>("idle");
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    if (phase !== "loading") return;
    const onMessage = (event: MessageEvent) => {
      if (event.origin !== window.location.origin) return;
      if (event.data?.type === "see-you-at-the-hive-ready") setPhase("ready");
      if (event.data?.type === "see-you-at-the-hive-error") setPhase("error");
    };
    window.addEventListener("message", onMessage);
    const timeout = window.setTimeout(() => setPhase("error"), 60000);
    return () => {
      window.removeEventListener("message", onMessage);
      window.clearTimeout(timeout);
    };
  }, [phase, attempt]);

  function launch() {
    setAttempt((value) => value + 1);
    setPhase("loading");
  }

  return (
    <main className="game-shell">
      <header>
        <div><strong>一会儿巢里见</strong><span>SEE YOU AT THE HIVE · 四季邻里动作冒险</span></div>
        <p>花田有事 · 搭把翅膀 · 巢里见</p>
      </header>
      <section className="game-stage">
        {phase === "idle" ? (
          <div className="launch-card">
            <p>春夏秋冬 · 花田与蜂巢 · SINGLE-PLAYER</p>
            <h1>花田有事，搭把翅膀。</h1>
            <button onClick={launch}>进入游戏</button>
            <small>推荐使用键盘或手柄与横屏；首次点击会允许浏览器播放音乐。</small>
          </div>
        ) : (
          <>
            <iframe
              key={attempt}
              src="/game/index.html"
              title="一会儿巢里见 Godot Web 游戏"
              allow="autoplay; fullscreen"
            />
            {phase === "loading" && (
              <div className="load-state" role="status" aria-live="polite">
                <span className="season-loader" aria-hidden="true" />
                <strong>正在开巢门</strong>
                <small>首次需要加载游戏核心；启动成功后会自动进入。</small>
              </div>
            )}
            {phase === "error" && (
              <div className="load-state load-error" role="alert">
                <strong>蜂群还没有醒来</strong>
                <small>检查网络后重试；稍后再飞也没关系。</small>
                <button onClick={launch}>重新载入</button>
              </div>
            )}
          </>
        )}
      </section>
      <p className="build-note">四季旅程 · 本机存档 · 键盘、手柄与触控 · 主蜂巢结算 / 整候断点</p>
    </main>
  );
}
