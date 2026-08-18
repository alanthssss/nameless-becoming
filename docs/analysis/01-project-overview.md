# 01 · 项目总览 / Project Overview

> 归巢之前 · Hivebound Seasons — 一款以蜜蜂生态、四季循环与东方节气为核心的轻量"搜、打、撤"肉鸽游戏原型。
> Hivebound Seasons — a lightweight "search, fight, extract" roguelike prototype centered on bee ecology, seasonal cycles, and Eastern solar terms.

---

## 1. 一句话定位 / One-Line Positioning

**中文 / CN**：玩家控制一只离巢蜜蜂，在逐渐失衡的四个节令中寻找花蜜、对抗生态威胁，并在体力耗尽前带着收获归巢；每次归巢都要选择蜂群接下来如何生存。

**English / EN**: You control a bee away from the hive, gathering nectar across four gradually unbalancing solar terms, fending off ecological threats, and returning home with your harvest before your stamina runs out — each return is a decision about how the colony will survive next.

> 核心问题 / Core question：玩家是否会因为"再采一朵"的诱惑承担风险，并在撤离成功后愿意继续下一节令？
> Will players take risks for the temptation of "one more flower," and be willing to continue into the next solar term after a successful extraction?

---

## 2. 项目愿景与设计原则 / Vision & Design Principles

**中文 / CN**：以蜜蜂文明为载体，制作一款具有东方生态寓言气质的游戏。玩家不是被台词告知答案，而是在采集、劳动、归巢、季节变化和生命循环中自行感受世界。

**English / EN**: A game carrying a bee civilization as its vessel, with the temperament of an Eastern ecological fable. Players are not told answers through dialogue; they feel the world through gathering, labor, returning home, seasonal change, and the cycle of life.

**设计原则 / Design Principles**：

| 中文 / CN | English / EN |
|-----------|--------------|
| 体验大于解释 | Experience over exposition |
| 大 Boss 保持民间寓言感，小怪与环境负责生态叙事 | Big bosses keep a folk-fable feel; mobs and environments carry ecological narrative |
| Boss 是偏离自然循环的"失律者"，并非绝对恶人 | Bosses are "the Unregulated" deviating from the natural cycle, not absolute villains |
| 四季既是自然变化，也是文明与精神状态 | Seasons are both natural change and civilizational/mental states |
| 所有扩展内容必须建立在可玩的核心互动上 | All extensions must build on a playable core interaction |

---

## 3. 世界观共识 / Worldview Consensus

### 主角 / Protagonist

**中文 / CN**：人在梦中变成一只蜜蜂，最初并不知道自己属于工蜂、雄蜂、蜂王或其他身份。主角的意义通过行动与循环显现，而不是通过大量独白解释。

**English / EN**: A person becomes a bee in a dream, initially unaware whether they are a worker, a drone, a queen, or something else. The protagonist's meaning emerges through action and cycles, not through lengthy monologue.

### 失律者 Boss 原型 / "The Unregulated" Boss Archetypes

| 原型 / Archetype | 主题方向 / Theme | 季节状态 / Season |
|------------------|------------------|-------------------|
| 蚊 / Mosquito | 贪婪、持续索取 / Greed, endless taking | 春末至盛夏 / Late spring to midsummer |
| 油葫芦 / Field Cricket | 油滑、漂泊、不愿归巢 / Slippery, drifting, refusing home | 夏末 / Late summer |
| 熊 / Bear | 停滞、疲惫、不愿苏醒 / Stagnation, fatigue, refusing to wake | 冬 / Winter |
| 画眉 / Thrush | 诱惑、沉溺、不愿告别 / Allure, indulgence, refusing farewell | 秋 / Autumn |

### 架空节令 / Fictional World States

**中文 / CN**：曾讨论的世界状态包括初蜜、盛鸣、长渴、静巢、逆潮、空花、无昼、灰雨。未来可作为普通二十四节气之外的异常关卡或终局章节。

**English / EN**: Previously discussed world states include First Honey, Loud Singing, Long Thirst, Still Nest, Reversed Tide, Empty Flowers, Sunless Days, and Gray Rain. They may serve as anomalous stages or an endgame chapter beyond the regular 24 solar terms.

---

## 4. 当前状态 / Current Status

**中文 / CN**：当前版本为 **候选 MVP 0.9.4**，维护 Web、macOS universal、Windows x86_64 三个发行端，均由同一个 `godot/` 工程导出。正式单机方向已转入 Godot 4，旧网页原型作为历史验证保留。

**English / EN**: Current version is **Candidate MVP 0.9.4**, maintaining three distribution targets — Web, macOS universal, and Windows x86_64 — all exported from the same `godot/` project. The official single-player direction has moved to Godot 4; the older web prototype is kept as historical validation.

**在线试玩 / Play Online**: https://hivebound-seasons.alanthssss.chatgpt.site

---

## 5. 核心验证问题 / Core Validation Questions

**中文 / CN**：项目仍处于早期原型阶段，以下四个问题决定后续方向：

**English / EN**: The project is still an early prototype; these four questions decide the next direction:

1. 飞行与采蜜是否让玩家感觉自己在控制一只蜜蜂？
   Does flying and harvesting make players feel they are controlling a bee?
2. 蚊虫靠近时，是否会产生"再采一点还是立即撤退"的犹豫？
   When mosquitoes close in, does the player hesitate between "one more sip" and "retreat now"?
3. 四个压缩节令的压力变化是否清晰？
   Is the pressure change across the four compressed solar terms clear?
4. 失败后是否愿意马上再进行一次循环？
   After failure, does the player immediately want to run the cycle again?
