"use client";

import { useCallback, useEffect, useRef, useState } from "react";

type Point = { x: number; y: number };
type Flower = Point & { id: number; nectar: number; kind: number; pulse: number };
type Mosquito = Point & { id: number; vx: number; vy: number; stunned: number };
type Phase = "intro" | "playing" | "between" | "won" | "lost";

const terms = [
  { name: "春分", season: "春", yin: 50, yang: 50, goal: 7, flowerRate: 1, enemies: 1, energyDrain: 0.48, palette: ["#d9e8c2", "#f3d59b", "#58784f", "#ffe8a3"], line: "昼夜均分，花潮初醒。" },
  { name: "夏至", season: "夏", yin: 15, yang: 85, goal: 11, flowerRate: 1.2, enemies: 3, energyDrain: 0.62, palette: ["#d8cf76", "#e89643", "#52663d", "#fff0a3"], line: "阳极而阴生，蚊影藏在盛光之后。" },
  { name: "秋分", season: "秋", yin: 50, yang: 50, goal: 14, flowerRate: 0.8, enemies: 4, energyDrain: 0.72, palette: ["#d7a768", "#8f5b43", "#4d5435", "#f4c879"], line: "花期将尽，归途比收获更长。" },
  { name: "冬至", season: "冬", yin: 85, yang: 15, goal: 9, flowerRate: 0.65, enemies: 4, energyDrain: 0.86, palette: ["#b8ced0", "#586c78", "#33494b", "#f4d893"], line: "阴极而阳生，最后一点蜜守着来年的春。" },
] as const;

const allTerms = ["立春","雨水","惊蛰","春分","清明","谷雨","立夏","小满","芒种","夏至","小暑","大暑","立秋","处暑","白露","秋分","寒露","霜降","立冬","小雪","大雪","冬至","小寒","大寒"];

function distance(a: Point, b: Point) { return Math.hypot(a.x - b.x, a.y - b.y); }
function clamp(v: number, min: number, max: number) { return Math.max(min, Math.min(max, v)); }

export default function Home() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const gameRef = useRef({
    phase: "intro" as Phase, term: 0, player: { x: 150, y: 270 }, target: null as Point | null,
    flowers: [] as Flower[], mosquitoes: [] as Mosquito[], carried: 0, delivered: 0,
    energy: 100, hive: 3, harvest: false, dash: false, sting: false, stingCd: 0,
    harvestClock: 0, hitCd: 0, time: 0, message: "飞向花朵，采蜜后亲自返回左侧蜂巢。",
  });
  const keysRef = useRef(new Set<string>());
  const [phase, setPhase] = useState<Phase>("intro");
  const [termIndex, setTermIndex] = useState(0);
  const [hud, setHud] = useState({ carried: 0, delivered: 0, energy: 100, hive: 3, stingCd: 0, message: "" });

  const spawnStage = useCallback((index: number) => {
    const g = gameRef.current;
    const data = terms[index];
    g.term = index; g.player = { x: 145, y: 270 }; g.target = null; g.carried = 0;
    g.delivered = 0; g.energy = 100; g.harvestClock = 0; g.hitCd = 0; g.stingCd = 0;
    g.flowers = Array.from({ length: index === 0 ? 7 : 6 }, (_, i) => ({
      id: i, x: 300 + Math.random() * 600, y: 70 + Math.random() * 400,
      nectar: Math.round((3 + Math.random() * 3) * data.flowerRate), kind: i % 3, pulse: Math.random() * 6,
    }));
    g.mosquitoes = Array.from({ length: data.enemies }, (_, i) => ({
      id: i, x: 520 + Math.random() * 370, y: 80 + Math.random() * 380, vx: 0, vy: 0, stunned: 0,
    }));
    g.message = `${data.name}：${data.line}`;
    g.phase = "playing"; setTermIndex(index); setPhase("playing");
  }, []);

  const startGame = useCallback(() => {
    const g = gameRef.current; g.hive = 3; g.time = 0;
    spawnStage(0);
  }, [spawnStage]);

  const nextStage = useCallback(() => {
    const g = gameRef.current;
    if (g.term >= terms.length - 1) { g.phase = "won"; setPhase("won"); return; }
    spawnStage(g.term + 1);
  }, [spawnStage]);

  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      keysRef.current.add(e.key.toLowerCase());
      if ([" ","arrowup","arrowdown","arrowleft","arrowright"].includes(e.key.toLowerCase())) e.preventDefault();
      if (e.key === " ") gameRef.current.harvest = true;
      if (e.key.toLowerCase() === "j") gameRef.current.sting = true;
      if (e.key === "Shift") gameRef.current.dash = true;
    };
    const up = (e: KeyboardEvent) => {
      keysRef.current.delete(e.key.toLowerCase());
      if (e.key === " ") gameRef.current.harvest = false;
      if (e.key.toLowerCase() === "j") gameRef.current.sting = false;
      if (e.key === "Shift") gameRef.current.dash = false;
    };
    window.addEventListener("keydown", down); window.addEventListener("keyup", up);
    return () => { window.removeEventListener("keydown", down); window.removeEventListener("keyup", up); };
  }, []);

  useEffect(() => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext("2d"); if (!ctx) return;
    let frame = 0, last = performance.now(), hudClock = 0;

    function drawBee(x: number, y: number, angle: number) {
      ctx.save(); ctx.translate(x, y); ctx.rotate(angle);
      ctx.fillStyle = "rgba(245,248,230,.62)"; ctx.beginPath(); ctx.ellipse(-5,-11,10,6,-.5,0,Math.PI*2); ctx.ellipse(-5,11,10,6,.5,0,Math.PI*2); ctx.fill();
      ctx.fillStyle = "#2c2a21"; ctx.beginPath(); ctx.ellipse(0,0,15,10,0,0,Math.PI*2); ctx.fill();
      ctx.fillStyle = "#e4ad2d"; ctx.fillRect(-8,-9,5,18); ctx.fillRect(3,-8,5,16);
      ctx.fillStyle = "#f2d678"; ctx.beginPath(); ctx.arc(13,0,7,0,Math.PI*2); ctx.fill(); ctx.restore();
    }

    function update(dt: number) {
      const g = gameRef.current; if (g.phase !== "playing") return;
      const data = terms[g.term]; g.time += dt; g.hitCd = Math.max(0, g.hitCd - dt); g.stingCd = Math.max(0, g.stingCd - dt);
      let dx = 0, dy = 0; const keys = keysRef.current;
      if (keys.has("a") || keys.has("arrowleft")) dx--; if (keys.has("d") || keys.has("arrowright")) dx++;
      if (keys.has("w") || keys.has("arrowup")) dy--; if (keys.has("s") || keys.has("arrowdown")) dy++;
      if (!dx && !dy && g.target) { const d = distance(g.player, g.target); if (d > 8) { dx = (g.target.x-g.player.x)/d; dy = (g.target.y-g.player.y)/d; } else g.target = null; }
      const len = Math.hypot(dx,dy) || 1; const dashing = g.dash && g.energy > 8; const speed = dashing ? 245 : 145;
      g.player.x = clamp(g.player.x + dx/len*speed*dt, 35, 925); g.player.y = clamp(g.player.y + dy/len*speed*dt, 35, 505);
      g.energy = Math.max(0, g.energy - data.energyDrain*dt - (dashing ? 7*dt : 0));

      const near = g.flowers.find(f => f.nectar > 0 && distance(g.player,f) < 44);
      if (g.harvest && near && g.energy > 0) {
        g.harvestClock += dt; g.energy = Math.max(0, g.energy - 2.8*dt);
        if (g.harvestClock >= .48) { g.harvestClock = 0; near.nectar--; g.carried++; g.message = near.nectar ? "花香越来越淡。还要继续停留吗？" : "这朵花已经采尽。"; }
      } else g.harvestClock = 0;

      if (g.sting && g.stingCd <= 0 && g.energy >= 8) {
        g.stingCd = 1.2; g.energy -= 8;
        g.mosquitoes.forEach(m => { if (distance(g.player,m) < 82) m.stunned = 2.2; });
        g.message = "蜂针震开了附近的蚊影。";
      }

      g.mosquitoes.forEach(m => {
        m.stunned = Math.max(0,m.stunned-dt); if (m.stunned) return;
        const d = distance(m,g.player); if (d < 310) { m.vx += (g.player.x-m.x)/Math.max(d,1)*85*dt; m.vy += (g.player.y-m.y)/Math.max(d,1)*85*dt; }
        m.vx *= .985; m.vy *= .985; m.x = clamp(m.x+m.vx,25,935); m.y = clamp(m.y+m.vy,25,515);
        if (d < 25 && g.hitCd <= 0) { g.hitCd = 1.1; g.energy = Math.max(0,g.energy-14); g.carried = Math.max(0,g.carried-2); g.message = "蚊虫刺中了你：体力下降，花蜜洒落。"; }
      });

      if (g.player.x < 100 && g.carried > 0) {
        const amount = g.carried; g.delivered += amount; g.carried = 0; g.energy = 100; g.message = `安全归巢，存入 ${amount} 滴蜜。`;
        if (g.delivered >= data.goal) { g.phase = "between"; setPhase("between"); }
      }
      if (g.energy <= 0) {
        g.hive--; g.carried = 0; g.energy = 100; g.player = {x:145,y:270}; g.target = null; g.message = "你没能带回花蜜。蜂巢的呼吸弱了一分。";
        if (g.hive <= 0) { g.phase = "lost"; setPhase("lost"); }
      }
    }

    function render() {
      const g = gameRef.current, data = terms[g.term] ?? terms[0], [light,warm,deep,gold] = data.palette;
      const grad = ctx.createLinearGradient(0,0,960,540); grad.addColorStop(0,light); grad.addColorStop(1,warm); ctx.fillStyle=grad; ctx.fillRect(0,0,960,540);
      ctx.globalAlpha=.16; ctx.fillStyle=deep; for(let i=0;i<34;i++){const x=(i*97+g.term*33)%960,y=390+Math.sin(i*2.1)*90;ctx.beginPath();ctx.moveTo(x,540);ctx.quadraticCurveTo(x+20,y,x+8,y-70);ctx.lineWidth=5;ctx.strokeStyle=deep;ctx.stroke();}ctx.globalAlpha=1;
      ctx.fillStyle="rgba(31,45,35,.76)";ctx.fillRect(0,0,105,540);ctx.fillStyle=gold;for(let y=30;y<520;y+=38){ctx.beginPath();ctx.arc(55,y,17,0,Math.PI*2);ctx.strokeStyle="rgba(255,226,134,.35)";ctx.stroke();}
      ctx.fillStyle="#fff5c7";ctx.font="600 14px serif";ctx.fillText("蜂 巢",31,28);ctx.font="11px monospace";ctx.fillText("撤离区",31,520);
      g.flowers.forEach(f=>{const colors=["#f2d66f","#e9aab1","#a995c9"];ctx.strokeStyle=deep;ctx.lineWidth=3;ctx.beginPath();ctx.moveTo(f.x,f.y+18);ctx.lineTo(f.x,f.y+46);ctx.stroke();ctx.fillStyle=colors[f.kind];for(let p=0;p<5;p++){const a=p*Math.PI*2/5+f.pulse;ctx.beginPath();ctx.ellipse(f.x+Math.cos(a)*11,f.y+Math.sin(a)*11,9,5,a,0,Math.PI*2);ctx.fill();}ctx.fillStyle=gold;ctx.beginPath();ctx.arc(f.x,f.y,6,0,Math.PI*2);ctx.fill();if(f.nectar<=0){ctx.globalAlpha=.35;ctx.fillStyle=deep;ctx.fillRect(f.x-14,f.y+49,28,3);ctx.globalAlpha=1;}});
      g.mosquitoes.forEach(m=>{ctx.save();ctx.translate(m.x,m.y);ctx.fillStyle=m.stunned?"#79938d":"#442f35";ctx.beginPath();ctx.ellipse(0,0,11,5,.4,0,Math.PI*2);ctx.fill();ctx.strokeStyle="rgba(255,255,255,.6)";ctx.beginPath();ctx.ellipse(-5,-8,9,3,-.5,0,Math.PI*2);ctx.ellipse(5,8,9,3,-.5,0,Math.PI*2);ctx.stroke();ctx.restore();});
      drawBee(g.player.x,g.player.y,g.target?Math.atan2(g.target.y-g.player.y,g.target.x-g.player.x):0);
      const near=g.flowers.find(f=>f.nectar>0&&distance(g.player,f)<44);if(near){ctx.strokeStyle=gold;ctx.lineWidth=2;ctx.beginPath();ctx.arc(near.x,near.y,31+Math.sin(g.time*6)*3,0,Math.PI*2);ctx.stroke();ctx.fillStyle=deep;ctx.font="12px serif";ctx.fillText("按住采蜜",near.x-28,near.y-39);}
    }

    function loop(now:number){const dt=Math.min(.033,(now-last)/1000);last=now;update(dt);render();hudClock+=dt;if(hudClock>.1){hudClock=0;const g=gameRef.current;setHud({carried:g.carried,delivered:g.delivered,energy:Math.round(g.energy),hive:g.hive,stingCd:g.stingCd,message:g.message});}frame=requestAnimationFrame(loop);}
    frame=requestAnimationFrame(loop);return()=>cancelAnimationFrame(frame);
  },[]);

  function setAction(action:"harvest"|"dash"|"sting", on:boolean){gameRef.current[action]=on;}
  const data=terms[termIndex];

  return <main className={`shell term-${termIndex}`}>
    <header className="game-header"><div className="wordmark"><i>◆</i><span><strong>归巢之前</strong><small>HIVEBOUND · 交互原型 0.2</small></span></div><div className="term-name"><small>{data.season} · 阴 {data.yin} / 阳 {data.yang}</small><strong>{data.name}</strong></div><button className="restart" onClick={startGame}>重新开始</button></header>
    <section className="term-ribbon" aria-label="二十四节气路线">{allTerms.map(t=><span key={t} className={t===data.name?"current":["春分","夏至","秋分","冬至"].includes(t)?"mvp":""}>{t}</span>)}</section>
    <div className="hud"><div><small>携带</small><strong>{hud.carried}</strong></div><div><small>本节储蜜</small><strong>{hud.delivered}/{data.goal}</strong></div><div><small>飞行体力</small><strong>{hud.energy}</strong></div><div><small>蜂巢呼吸</small><strong>{"●".repeat(Math.max(0,hud.hive))}{"○".repeat(Math.max(0,3-hud.hive))}</strong></div><div className="yin-yang"><i style={{width:`${data.yin}%`}}/><span>阴阳消长</span></div></div>
    <section className="play-frame">
      <div className="canvas-wrap"><canvas ref={canvasRef} width={960} height={540} onPointerDown={e=>{const r=e.currentTarget.getBoundingClientRect();gameRef.current.target={x:(e.clientX-r.left)*960/r.width,y:(e.clientY-r.top)*540/r.height};}} aria-label="蜜蜂花田游戏区域"/>
        {phase==="intro"&&<div className="overlay"><p className="kicker">四季搜打撤 · 核心交互测试</p><h1>再采一朵，<br/>还是现在归巢？</h1><p>控制蜜蜂飞向花朵，按住采蜜；体力耗尽前，带着花蜜返回左侧蜂巢。</p><button onClick={startGame}>飞入春分</button><small>键盘 WASD / 方向键移动 · 空格采蜜 · Shift 冲刺 · J 蜂针<br/>手机可点按移动，并使用下方动作键</small></div>}
        {phase==="between"&&<div className="overlay compact"><p className="kicker">{data.name}完成</p><h2>{data.line}</h2><p>你已为蜂巢带回足够的蜜。阴阳推移，下一节令正在靠近。</p><button onClick={nextStage}>{termIndex===3?"等待来年":"进入下一节令"}</button></div>}
        {phase==="won"&&<div className="overlay compact"><p className="kicker">一个循环完成</p><h2>冬至一阳生</h2><p>蜂群熬过了四个压缩节令。未来，它们之间将展开为完整的二十四个小关卡。</p><button onClick={startGame}>再走一次四季</button></div>}
        {phase==="lost"&&<div className="overlay compact"><p className="kicker">蜂巢归于寂静</p><h2>这一次没能等到春天</h2><p>远花仍在那里，但带回家的蜜才真正属于蜂群。</p><button onClick={startGame}>重新出巢</button></div>}
      </div>
      <aside className="side-panel"><p className="kicker">当前节令</p><h2>{data.name}</h2><p>{data.line}</p><dl><div><dt>花蜜目标</dt><dd>{data.goal}</dd></div><div><dt>蚊群压力</dt><dd>{"◆".repeat(data.enemies)}</dd></div><div><dt>节律</dt><dd>{data.yin>data.yang?"阴盛，守成为先":data.yang>data.yin?"阳盛，行动为先":"阴阳相半"}</dd></div></dl><blockquote>{hud.message||"飞向花朵，采蜜后亲自返回左侧蜂巢。"}</blockquote><p className="rule">搜：寻找仍有蜜的花<br/>打：用蜂针震开近身蚊虫<br/>撤：飞回左侧蜂巢完成结算</p></aside>
    </section>
    <section className="mobile-actions"><button onPointerDown={()=>setAction("harvest",true)} onPointerUp={()=>setAction("harvest",false)} onPointerLeave={()=>setAction("harvest",false)}><strong>采蜜</strong><span>靠近花朵后按住</span></button><button onPointerDown={()=>setAction("dash",true)} onPointerUp={()=>setAction("dash",false)} onPointerLeave={()=>setAction("dash",false)}><strong>振翅</strong><span>快速飞行，消耗体力</span></button><button disabled={hud.stingCd>0} onPointerDown={()=>setAction("sting",true)} onPointerUp={()=>setAction("sting",false)}><strong>蜂针</strong><span>{hud.stingCd>0?`${hud.stingCd.toFixed(1)} 秒`:"震开附近蚊虫"}</span></button></section>
  </main>;
}
