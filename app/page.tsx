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
        <div><strong>一会儿巢里见</strong><span>可玩垂直切片 · 私人试玩构建</span></div>
        <p>花田办事 · 彼此搭手 · 记得回家</p>
      </header>
      <section className="game-stage">
        {phase === "idle" ? (
          <div className="launch-card">
            <p>春季往返路线 · PLAYABLE SLICE</p>
            <h1>花田有事，搭把翅膀。</h1>
            <button onClick={launch}>进入试玩</button>
            <small>推荐使用键盘与横屏；首次点击会允许浏览器播放声音。</small>
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
                <strong>正在唤醒蜂群</strong>
                <small>首次需要下载约 10 MB 游戏核心；启动成功后会自动进入。</small>
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
      <p className="build-note">当前版本用于验证往返路线、场景切换与操作可读性，不代表最终美术和音乐品质。</p>
    </main>
  );
}
