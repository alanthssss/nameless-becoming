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
      if (event.data?.type === "nameless-game-ready") setPhase("ready");
      if (event.data?.type === "nameless-game-error") setPhase("error");
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
        <div><strong>无名：成蜂</strong><span>可玩垂直切片 · 私人试玩构建</span></div>
        <p>四季循环 · 采蜜归巢 · 失律者调律</p>
      </header>
      <section className="game-stage">
        {phase === "idle" ? (
          <div className="launch-card">
            <p>四季搜打撤 · PLAYABLE DEMO</p>
            <h1>再采一朵，还是现在归巢？</h1>
            <button onClick={launch}>进入试玩</button>
            <small>推荐使用键盘与横屏；首次点击会允许浏览器播放音乐。</small>
          </div>
        ) : (
          <>
            <iframe
              key={attempt}
              src="/game/index.html"
              title="无名：成蜂 Godot Web 游戏"
              allow="autoplay; fullscreen"
            />
            {phase === "loading" && (
              <div className="load-state" role="status" aria-live="polite">
                <span className="season-loader" aria-hidden="true" />
                <strong>正在唤醒蜂群</strong>
                <small>首次需要下载约 10 MB 游戏核心；启动成功后会自动进入。</small>
              </div>
            )}
            {phase === "error" && (
              <div className="load-state load-error" role="alert">
                <strong>蜂群还没有醒来</strong>
                <small>检查网络后重试；已完成的本地进度不会受影响。</small>
                <button onClick={launch}>重新载入</button>
              </div>
            )}
          </>
        )}
      </section>
      <p className="build-note">当前版本用于验证核心循环、节令机制与操作理解，不代表最终美术和音乐品质。</p>
    </main>
  );
}
