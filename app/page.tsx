"use client";

import { useMemo, useState } from "react";

type Season = "春" | "夏" | "秋" | "冬";
type LogEntry = { id: number; text: string; tone?: "good" | "bad" };

const seasons: Season[] = ["春", "夏", "秋", "冬"];
const seasonData = {
  春: { icon: "🌱", title: "初蜜", note: "花潮苏醒，采集更加丰厚。", sky: "spring" },
  夏: { icon: "☀️", title: "盛鸣", note: "蚊群出没，远处的花更甜，也更危险。", sky: "summer" },
  秋: { icon: "🍂", title: "长渴", note: "花期将尽，每一次出巢都要慎重。", sky: "autumn" },
  冬: { icon: "❄️", title: "静巢", note: "停止采集，用储蜜守住蜂群。", sky: "winter" },
};

const flowerTypes = [
  { icon: "🌼", name: "蒲公英", honey: 2, risk: 0.08 },
  { icon: "🌸", name: "山樱", honey: 3, risk: 0.16 },
  { icon: "🪻", name: "夜铃花", honey: 5, risk: 0.3 },
];

export default function Home() {
  const [started, setStarted] = useState(false);
  const [ended, setEnded] = useState(false);
  const [seasonIndex, setSeasonIndex] = useState(0);
  const [energy, setEnergy] = useState(10);
  const [carried, setCarried] = useState(0);
  const [stored, setStored] = useState(0);
  const [hive, setHive] = useState(8);
  const [distance, setDistance] = useState(0);
  const [runs, setRuns] = useState(0);
  const [threat, setThreat] = useState(0);
  const [result, setResult] = useState("");
  const [log, setLog] = useState<LogEntry[]>([
    { id: 0, text: "风里有新花的气味。蜂巢正在等待第一批蜜。" },
  ]);

  const season = seasons[seasonIndex];
  const info = seasonData[season];
  const maxDistance = season === "秋" ? 3 : 4;
  const returnCost = Math.max(1, distance);
  const canReturn = energy >= returnCost;
  const winterNeed = 18;

  const visibleFlowers = useMemo(() => {
    if (season === "冬") return [];
    const count = Math.min(3, 1 + distance);
    return flowerTypes.slice(0, count);
  }, [season, distance]);

  function note(text: string, tone?: LogEntry["tone"]) {
    setLog((items) => [{ id: Date.now() + Math.random(), text, tone }, ...items].slice(0, 5));
  }

  function reset() {
    setStarted(true);
    setEnded(false);
    setSeasonIndex(0);
    setEnergy(10);
    setCarried(0);
    setStored(0);
    setHive(8);
    setDistance(0);
    setRuns(0);
    setThreat(0);
    setResult("");
    setLog([{ id: 1, text: "初蜜时节。先采花，再在体力耗尽前归巢。", tone: "good" }]);
  }

  function travel() {
    if (energy <= distance + 1 || distance >= maxDistance) return;
    const next = distance + 1;
    setDistance(next);
    setEnergy((v) => v - 1);
    setThreat((v) => Math.min(100, v + (season === "夏" ? 20 : 10)));
    note(next >= 3 ? "你飞进了远花田。蜜香浓得发烫。" : "你离蜂巢更远了一些。");
  }

  function collect(index: number) {
    const flower = flowerTypes[index];
    if (!flower || energy < 2) return;
    const seasonBonus = season === "春" ? 1 : season === "秋" ? -1 : 0;
    const gain = Math.max(1, flower.honey + seasonBonus + Math.floor(distance / 2));
    const danger = flower.risk + threat / 250 + (season === "夏" ? 0.12 : 0);
    setEnergy((v) => v - 2);
    setCarried((v) => v + gain);
    setThreat((v) => Math.min(100, v + 12));

    if (Math.random() < danger) {
      const loss = Math.min(2, gain);
      setCarried((v) => Math.max(0, v - loss));
      setEnergy((v) => Math.max(0, v - 1));
      note(`蚊影掠过！${loss} 滴蜜洒进草丛。`, "bad");
    } else {
      note(`${flower.name}：获得 ${gain} 滴花蜜。`, "good");
    }
  }

  function returnHive() {
    if (!canReturn || distance === 0) return;
    const delivered = carried;
    setEnergy(10);
    setStored((v) => v + delivered);
    setCarried(0);
    setDistance(0);
    setThreat(0);
    setRuns((v) => v + 1);
    note(`安全归巢，储存 ${delivered} 滴蜜。`, "good");
  }

  function emergencyReturn() {
    if (distance === 0) return;
    const saved = Math.floor(carried / 2);
    setStored((v) => v + saved);
    setCarried(0);
    setEnergy(10);
    setDistance(0);
    setThreat(0);
    setHive((v) => Math.max(0, v - 1));
    note(`你跌撞着归巢，只保住 ${saved} 滴蜜。蜂群士气 -1。`, "bad");
  }

  function nextSeason() {
    if (distance > 0) return;
    if (seasonIndex < 2) {
      const upkeep = seasonIndex === 0 ? 4 : 6;
      const paid = Math.min(stored, upkeep);
      const shortage = upkeep - paid;
      setStored((v) => Math.max(0, v - upkeep));
      setHive((v) => Math.max(0, v - shortage));
      setSeasonIndex((v) => v + 1);
      setRuns(0);
      setEnergy(10);
      note(shortage ? `季节更替，储蜜不足，蜂群失去 ${shortage} 点活力。` : `交付 ${upkeep} 滴季节口粮，蜂群平稳换季。`, shortage ? "bad" : "good");
      return;
    }
    if (seasonIndex === 2) {
      setSeasonIndex(3);
      setDistance(0);
      note("静巢降临。现在只能相信一路积下的蜜。", "good");
    }
  }

  function faceWinter() {
    const score = stored + hive * 2;
    const won = stored >= winterNeed && hive > 0;
    setEnded(true);
    setResult(
      won
        ? `春风再次吹进巢口。你留下了 ${stored - winterNeed} 滴余蜜，${hive} 点蜂群活力保存至新年。`
        : score >= 20
          ? "蜂群听见了春雷，却没能全部醒来。你们离下一个春天只差一点。"
          : "巢律渐渐安静。不是每一次循环都能等到春天。"
    );
  }

  if (!started) {
    return (
      <main className="landing">
        <div className="sun-disc" />
        <section className="intro-card">
          <p className="eyebrow">四季搜打撤 · 原型 0.1</p>
          <h1>归巢之前</h1>
          <p className="subtitle">一只蜜蜂，一座渐冷的蜂巢，以及每次都想再多采一朵花的念头。</p>
          <div className="pillars">
            <span>搜 · 寻找远花</span><span>打 · 躲避失律者</span><span>撤 · 带蜜归巢</span>
          </div>
          <button className="primary big" onClick={reset}>开始第一个春天</button>
          <p className="hint">目标：在冬季前储存 18 滴蜜，并守住蜂群。</p>
        </section>
      </main>
    );
  }

  return (
    <main className={`game ${info.sky}`}>
      <header className="topbar">
        <div className="brand"><span className="bee-mark">◆</span><strong>归巢之前</strong><small>HIVEBOUND</small></div>
        <div className="season-track" aria-label="四季进度">
          {seasons.map((s, i) => <span key={s} className={i === seasonIndex ? "active" : i < seasonIndex ? "done" : ""}>{s}</span>)}
        </div>
        <button className="quiet" onClick={reset}>重新开始</button>
      </header>

      <section className="status-row">
        <div><small>体力</small><strong>⚡ {energy}/10</strong></div>
        <div><small>携带花蜜</small><strong>◉ {carried}</strong></div>
        <div><small>巢内储蜜</small><strong>⬡ {stored}</strong></div>
        <div><small>蜂群活力</small><strong>♥ {hive}</strong></div>
        <div className="risk"><small>危险气味</small><strong>{threat}%</strong></div>
      </section>

      <div className="game-grid">
        <aside className="season-panel panel">
          <div className="season-icon">{info.icon}</div>
          <p className="eyebrow">{season} · {info.title}</p>
          <h2>{season === "冬" ? "守住这一口呼吸" : distance === 0 ? "巢口仍有余温" : `离巢 ${distance} 格`}</h2>
          <p>{info.note}</p>
          <div className="route">
            {[0, 1, 2, 3, 4].map((step) => <span key={step} className={step <= distance ? "reached" : ""}>{step === 0 ? "巢" : "·"}</span>)}
          </div>
          {season !== "冬" && <p className="cost">返回蜂巢需要 {returnCost} 点体力</p>}
        </aside>

        <section className="field panel">
          {ended ? (
            <div className="ending">
              <span>✦</span><p className="eyebrow">本次循环结束</p><h2>{stored >= winterNeed && hive > 0 ? "蜂群等到了春天" : "花潮没有如期归来"}</h2><p>{result}</p><button className="primary" onClick={reset}>再经历一次四季</button>
            </div>
          ) : season === "冬" ? (
            <div className="winter-choice">
              <span className="winter-mark">❄</span><p className="eyebrow">静巢结算</p><h2>过冬需要 {winterNeed} 滴蜜</h2>
              <div className="winter-meter"><i style={{ width: `${Math.min(100, stored / winterNeed * 100)}%` }} /></div>
              <p>当前储蜜 {stored}，蜂群活力 {hive}。踏入静巢后，本轮无法返回。</p>
              <button className="primary" onClick={faceWinter}>点燃冬巢</button>
            </div>
          ) : (
            <>
              <div className="field-head"><div><p className="eyebrow">{distance === 0 ? "蜂巢边缘" : distance >= 3 ? "远花田" : "野花径"}</p><h2>{distance === 0 ? "选择这一次要走多远" : "花粉正在风里发亮"}</h2></div><span className="run-count">本季出巢 {runs} 次</span></div>
              <div className="flowers">
                {visibleFlowers.map((flower, i) => (
                  <button key={flower.name} className="flower-card" onClick={() => collect(i)} disabled={energy < 2}>
                    <span className="flower-icon">{flower.icon}</span><strong>{flower.name}</strong><small>约 {Math.max(1, flower.honey + (season === "春" ? 1 : season === "秋" ? -1 : 0) + Math.floor(distance / 2))} 滴蜜</small><em>采集消耗 2 体力</em>
                  </button>
                ))}
              </div>
              <div className="actions">
                <button onClick={travel} disabled={distance >= maxDistance || energy <= distance + 1}>深入花田 <span>风险与收益上升</span></button>
                {distance > 0 && canReturn && <button className="primary" onClick={returnHive}>安全归巢 <span>带回全部花蜜</span></button>}
                {distance > 0 && !canReturn && <button className="danger" onClick={emergencyReturn}>紧急撤离 <span>损失一半花蜜</span></button>}
              </div>
            </>
          )}
        </section>

        <aside className="journal panel">
          <p className="eyebrow">巢内札记</p>
          <div className="log-list">{log.map((item) => <p key={item.id} className={item.tone}>{item.text}</p>)}</div>
          {!ended && season !== "冬" && distance === 0 && (
            <button className="season-button" onClick={nextSeason} disabled={runs === 0}>进入下一季 <span>{seasonIndex === 2 ? "花田将关闭" : "消耗季节口粮"}</span></button>
          )}
          <div className="objective"><small>本轮目标</small><strong>冬前储蜜 ≥ {winterNeed}</strong><span>活着回来，比多采一朵更重要。</span></div>
        </aside>
      </div>
    </main>
  );
}
