# 敌物候学：小怪生态化重设计 / Enemy Phenology: Ecological Minion Redesign

> 版本 / Version: 草案 v0.1（2026-08-18）
> 状态 / Status: 待审阅 / Pending review
> 关联 / Related: `docs/DESIGN_CONSENSUS.md`、`godot/data/seasons.json`、`godot/data/bosses.json`

---

## 0. 摘要 / Summary

**中文**：将现有四种小怪体系重建为五类小怪——蚊、掠蜜蚁、油葫芦、画眉、熊。前四者分别是春/夏/秋/冬四个 Boss（失律之蚊/油葫芦/画眉/熊）的**常态个体减弱版**，蚂蚁独立保留并生态化。核心原则：**小怪遵循真实物候钟出现在正确的季节；Boss 是同一物种在阴阳极点上"失律"的异化个体**。冬季不再有小怪——寒冷本身是那个季节的敌人。

**English**: Rebuild the enemy roster into five minion types — Mosquito, Raider Ant, Cricket, Hwamei, Bear. Four of them are weakened, *normal* counterparts of the four seasonal bosses ("失律" aberrants); the ant stays independent but ecologized. Core rule: **minions follow real phenology and appear in their correct seasons; bosses are the same species broken out of rhythm at the yin-yang pivot points.** Winter has no minions — the cold itself is that season's enemy.

---

## 1. 设计原则 / Design Principles

1. **小怪无名，Boss 失律 / Minions are nameless; bosses are out-of-rhythm.**
   小怪不需要花哨的名字——它们只是循着物候钟出现的自然本身（呼应"无名"主题）。Boss 才是被命名、被异化的"失律"个体。玩家一整季与常态生态周旋，最后在节令极点上遇见打破循环的那一个。

2. **五种威胁动词，互不重复 / Five distinct threat verbs.**
   追踪（蚊）/ 路径（蚁）/ 爆发（油葫芦）/ 欺骗（画眉）/ 碾压（熊）。学习曲线按此顺序引入。

3. **物候即难度曲线 / Phenology is the difficulty curve.**
   敌人数量不靠人工堆砌，而是跟随时令自然涨落：春醒 → 夏盛 → 秋敛 → 冬寂。

4. **冬季的敌人是寒冷本身 / Winter's enemy is the cold.**
   立冬之后花田寂静，只剩体力消耗与匮乏（`energy_drain 2.2+`、`nectar_scale 0.7x`）。这与"被需要的四季"哲学一致：冬被彼此需要。

---

## 2. 五类小怪档案 / Five Minion Profiles

### 2.1 蚊 · Mosquito —— 追踪型 / Pursuit

- **现实生态 / Real ecology**：越冬卵/成虫在气温稳定 >10°C 后复苏；春雨积水触发羽化；盛夏为种群峰值；霜后消亡。
- **机制（失律之蚊的减弱版）/ Mechanic (weakened Mosquito boss)**：Boss 绕花潮轨道持续吸取；小怪仅在**单朵花附近悬停吸蜜**，玩家靠近或携蜜经过时短距追击。已接近现版行为，微调即可。
- **数值建议 / Stats**: `move_speed 58`（Boss 78）、`impact_range 26`（Boss 39）、`energy_damage 8`（Boss 18）。
- **窗口 / Window**：立春 → 霜降。

### 2.2 掠蜜蚁 · Raider Ant —— 路径型 / Path（重设计）

- **现实生态 / Real ecology**：蚁群沿信息素固定路线在巢与食物源之间巡逻；冬季整群蛰伏；蚂蚁会霸占花蜜源并驱赶传粉者。
- **机制（生态化重设计）/ Mechanic (ecologized redesign)**：不再自由游走，而是沿**固定信息素轨迹**（巢口 → 2~3 朵最富的花之间的折线）往返巡逻。轨迹可读、可预判——携蜜横穿轨迹即被夺蜜。单位数量可因此下调，因为每只蚁的威胁更"实"。
- **数值 / Stats**：沿用现版（`move_speed 58`、`steal_range 29`、`flee 1.4s`），新增轨迹生成。
- **窗口 / Window**：惊蛰 → 立冬（立冬仅留 1 只"收尾个体"）。

### 2.3 油葫芦 · Cricket —— 爆发型 / Burst（新）

- **现实生态 / Real ecology**：卵越冬，若虫晚春—初夏出土，成虫夏末至秋末鸣叫活动，霜降后死亡。
- **机制（失律之油葫芦的减弱版）/ Mechanic (weakened Cricket boss)**：Boss 全程乱窜并留成串虚影；小怪改为**间歇跳跃**——0.4 秒爆发冲刺（留 1 个 0.5 秒虚影）→ 1.2 秒停顿。威胁在于落点预判，而非持续追踪。
- **数值建议 / Stats**: 爆发速度 110 / 停顿 1.2s、`impact_range 28`、`energy_damage 10`（Boss 15）。
- **窗口 / Window**：小满（若虫，1 只）→ 霜降。夏至起为成虫（2 只）。

### 2.4 画眉 · Hwamei —— 欺骗型 / Deception（新）

- **现实生态 / Real ecology**：繁殖期（约清明—小满）育雏需要大量昆虫蛋白，捕虫压力最高；秋季转食浆果种子，虫压骤降。
- **机制（失律之画眉的减弱版）/ Mechanic (weakened Hwamei boss)**：Boss 用歌声制造幻花之海；小怪栖息不动，每 8 秒在自身附近催生** 1 朵幻花**——外观与真花几乎一致（蜜光颜色略偏），靠近才发现无蜜。不造成任何直接伤害，代价是浪费的时间与被拉长的暴露时长。
- **数值建议 / Stats**: 鸣唱半径 90 / 幻花存在 20s / `energy_damage 0`。
- **窗口 / Window**：清明 → 小满。

### 2.5 熊 · Bear —— 碾压型 / Unfightable Hazard（新）

- **现实生态 / Real ecology**：秋季育肥期（立秋—霜降）疯狂觅食，**掠袭蜂巢取蜜与幼虫是真实行为**；霜降后入眠——冬季的失律之熊正是"该睡不睡/睡错了地方"的异化个体。
- **机制（失律之熊的减弱版）/ Mechanic (weakened Bear boss)**：缓慢 lumbering（不可对抗、不可击退），朝蜂巢或最密花丛移动；**压平沿途花朵**（9 秒不可采），抵达巢区后每 4 秒吃掉 1 滴库存蜜，**吃满 3 滴自行离开**。应对方式是绕行与抢收，不是战斗。
- **数值建议 / Stats**: `move_speed 30`（Boss 52）、压平半径 30 / 9s、接触 `energy_damage 16`、食量 3。
- **窗口 / Window**：立秋 → 霜降。

---

## 3. 二十四节令分布表 / 24-Term Distribution

新分布（蚊/蚁/油葫芦/画眉/熊 → 合计）对比现版合计：

| # | 节令 | 蚊 | 蚁 | 油葫芦 | 画眉 | 熊 | 新合计 | 原合计 | 关键生态依据 / Key ecology |
|---|------|----|----|--------|------|----|--------|--------|---------------------------|
| 1 | 冬至 | 0 | 0 | 0 | 0 | 0 | **0** | 0 | 蛰伏。Boss 失律之熊在此 / Dormant; Bear boss here |
| 2 | 小寒 | 0 | 0 | 0 | 0 | 0 | **0** | 1 | 严寒蛰伏 / Deep dormancy |
| 3 | 大寒 | 0 | 0 | 0 | 0 | 0 | **0** | 1 | 至寒；教学期 / Coldest; tutorial |
| 4 | 立春 | 1 | 0 | 0 | 0 | 0 | **1** | 1 | 三候"蛰虫始振" / First stirrings |
| 5 | 雨水 | 1 | 0 | 0 | 0 | 0 | **1** | 1 | 暖日零星活动 / Sporadic warm-day flyers |
| 6 | 惊蛰 | 1 | 1 | 0 | 0 | 0 | **2** | 3 | 春雷惊百虫：蚊+蚁同醒 / Insects awaken together |
| 7 | 春分 | 2 | 1 | 0 | 0 | 0 | **3** | 3 | 蚊渐稳。Boss 失律之蚊 / Mosquito boss |
| 8 | 清明 | 2 | 1 | 0 | 1 | 0 | **4** | 4 | 画眉育雏开始 / Hwamei breeding begins |
| 9 | 谷雨 | 3 | 1 | 0 | 1 | 0 | **5** | 4 | 雨后积水→蚊羽化 / Rain pools breed mosquitoes |
| 10 | 立夏 | 3 | 1 | 0 | 1 | 0 | **5** | 4 | 繁殖季持续 / Breeding continues |
| 11 | 小满 | 3 | 1 | 1 | 1 | 0 | **6** | 6 | 油葫芦若虫出土 / Cricket nymphs emerge |
| 12 | 芒种 | 4 | 1 | 1 | 0 | 0 | **6** | 6 | 蚊趋峰 / Mosquitoes climbing to peak |
| 13 | 夏至 | 3 | 1 | 2 | 0 | 0 | **6** | 5 | 油葫芦成虫。Boss 失律之油葫芦 / Cricket boss |
| 14 | 小暑 | 4 | 1 | 2 | 0 | 0 | **7** | 5 | 高温高湿=蚊峰 / Peak mosquito weather |
| 15 | 大暑 | 4 | 1 | 2 | 0 | 0 | **7** | 6 | 双峰并至 / Double peak |
| 16 | 立秋 | 3 | 1 | 2 | 0 | 1 | **7** | 6 | 熊出：秋季育肥 / Bear hyperphagia begins |
| 17 | 处暑 | 3 | 1 | 2 | 0 | 1 | **7** | 7 | 画眉转食浆果；熊掠巢 / Hwamei to fruit; bears raid |
| 18 | 白露 | 3 | 1 | 2 | 0 | 1 | **7** | 6 | 夜凉蚊缓降 / Cooling nights, mosquitoes easing |
| 19 | 秋分 | 2 | 1 | 2 | 0 | 1 | **6** | 5 | Boss 失律之画眉 / Hwamei boss |
| 20 | 寒露 | 2 | 1 | 2 | 0 | 1 | **6** | 5 | 熊抓紧育肥 / Final fattening |
| 21 | 霜降 | 1 | 1 | 1 | 0 | 1 | **4** | 6 | 降霜：虫随霜消 / Frost kills insects |
| 22 | 立冬 | 0 | 1 | 0 | 0 | 0 | **1** | 6 | 水始冰：蚁收尾归巢 / Ants wind down |
| 23 | 小雪 | 0 | 0 | 0 | 0 | 0 | **0** | 4 | 万物寂 / Silence |
| 24 | 大雪 | 0 | 0 | 0 | 0 | 0 | **0** | 4 | 只剩寒冷与彼此 / Only the cold, and each other |

**说明 / Notes**

- 蚊、油葫芦、蚁在各自消亡节令保留"末代个体"再归零，制造渐弱的尾声而非断崖。
- 蚁从现版峰值 2~3 只降为全程 ≤1 只：轨迹化重设计后单位威胁密度更高，总量需下调。
- 熊按"每节令至多 1 只"处理——碾压型敌人成群会摧毁可玩性，且真实蜂场袭击多为独个个体。

---

## 4. Boss—小怪叙事结构 / Boss–Minion Narrative

```
常态个体（循物候钟）  ——异化——▶  失律个体（困在极点上）
蚊    立春→霜降              失律之蚊    春分（贪婪·索取不归还）
油葫芦 小满→霜降              失律之油葫芦 夏至（油滑·漂泊不归）
画眉  清明→小满              失律之画眉  秋分（沉溺·不肯告别）
熊    立秋→霜降              失律之熊    冬至（停滞·不愿苏醒）
```

玩家在每个季节与"守时的自然"周旋，随后在阴阳极点遇见"失时的同类"。Boss 战本质上是**把一个迷失的常态个体引回循环**（调律机制），而非杀死它——小怪体系为这个叙事提供了铺垫：它们本来都是守时的。

**English**: The player contends with *punctual nature* all season, then meets the *unpunctual one of the same kind* at the yin-yang pivot. Boss fights are about guiding a lost normal individual back into the cycle (tuning), not killing — and the minion system foreshadows this: they were all punctual to begin with.

---

## 5. 平衡影响与验收 / Balance Impact & Acceptance

**变动最大的三处 / Three biggest shifts**:

1. **小寒/大寒 1→0**：前三个节令成为纯净教学期（仅授粉机制）。生态上越冬蚊不应活动。
2. **立冬—大雪 6/4/4→1/0/0**：冬季转为"纯匮乏季"。压力完全来自 `energy_drain`（2.2→2.3）与 `nectar_scale`（0.74→0.70）。若实测过空，**只允许**立冬保留 1 蚁，不得回填蚊虫。
3. **霜降 6→4 与立冬 6→1 的"入冬寂静"**：秋天以可感知的衰减收尾，是本设计想要的情绪时刻，不是失误。

**验收标准 / Acceptance criteria**:

- [ ] 每节令新合计与原合计偏差 ≤ +2（下降不设限，属有意设计）；
- [ ] 五类小怪行为动词互不重复（追踪/路径/爆发/欺骗/碾压）；
- [ ] 每个出现窗口在表内有物候依据；
- [ ] 熊单节令 ≤1 只；画眉全程无直接伤害；
- [ ] `godot/tests/flow_test.gd` 通过：24 节令状态流含新字段仍可贯通；
- [ ] 冬季三节令（立冬—大雪）实测体感：紧张度由体力与花量承担，不感到"空转"。

---

## 6. 实施要点 / Implementation Notes

- `seasons.json` schema 扩展：将 `enemies`（现=蚊）拆分为 `mosquitoes` / `ants` / `crickets` / `thrushes` / `bears` 五字段；向后兼容期可保留 `enemies` 作为 `mosquitoes` 别名。
- `main.gd` 需新增三种更新循环（`update_crickets` / `update_thrushes` / `update_bears`）与蚁轨迹生成；画眉幻花复用现有花渲染层（加 `phantom` 标记）。
- `balance.json` 增加各小怪分区（建议值见第 2 节）。
- 失律 Boss 数值不动——本设计只调整常态个体。

---

## 7. 生态依据速查 / Ecology Quick Reference

| 物种 | 越冬态 | 春 | 夏 | 秋 | 冬 | 对蜂的真实关系 |
|------|--------|-----|-----|-----|-----|----------------|
| 蚊 | 卵/成虫 | 惊蛰前后复苏、渐增 | 峰值 | 回落、霜后消亡 | 蛰伏 | 无直接关系（游戏内为风格化的"索取者"） |
| 蚁 | 全群蛰伏 | 惊蛰后恢复觅食 | 活跃 | 持续、渐止 | 蛰伏 | 真实盗蜜/霸占花蜜源 |
| 油葫芦 | 卵 | — | 若虫→成虫 | 成虫鸣唱、霜后死 | — | 无直接关系（秋虫符号） |
| 画眉 | 留鸟/迁徙 | 繁殖育雏（虫食） | 晚窝 | 转食浆果 | — | 繁殖期真实捕虫（含蜂） |
| 熊 | 冬眠 | 出眠 | 觅食 | 育肥+掠巢 | 冬眠 | 真实掠袭蜂巢 |

> 游戏不模拟捕食链本身——蚊子与油葫芦对蜂无真实威胁，机制上是"索取/骚扰"的风格化符号；蚁、画眉、熊与蜂的关系则是写实的。这条边界与既有设计共识一致（体验大于解释）。
