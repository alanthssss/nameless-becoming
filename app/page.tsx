"use client";

import { useState } from "react";

export default function Home() {
  const [started, setStarted] = useState(false);
  return (
    <main className="game-shell">
      <header>
        <div><strong>无名：成蜂</strong><span>Godot 同源 Web 版 · v0.9.5-rc.1</span></div>
        <p>Web · macOS · Windows 使用同一份关卡与玩法代码</p>
      </header>
      <section className="game-stage">
        {!started ? (
          <div className="launch-card">
            <p>四季搜打撤 · MVP</p>
            <h1>再采一朵，还是现在归巢？</h1>
            <button onClick={() => setStarted(true)}>启动 Web 版</button>
            <small>首次点击同时允许浏览器播放游戏音乐。推荐使用键盘与横屏。</small>
          </div>
        ) : (
          <iframe src="/game/index.html" title="无名：成蜂 Godot Web 游戏" allow="autoplay; fullscreen" />
        )}
      </section>
    </main>
  );
}
