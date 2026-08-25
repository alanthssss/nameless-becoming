# 01 · 项目总览 / Project Overview

> 无名：成蜂 · Nameless: Becoming — 一款以蜜蜂生态、二十四节气循环与归巢风险为核心的轻量动作撤离原型。
> A lightweight action-extraction prototype centered on bee ecology, the 24-solar-term cycle, and the risk of making it home.

当前仓库基线 / Current repository baseline：`0.9.5-rc.2`；`origin/main` `f57ea02c`（PR #65），玩法与资产基线来自 PR #63，盲听工具来自 PR #64。
固定候选 / Fixed candidate：`f57ea02c`。

---

## 1. 一句话定位 / One-Line Positioning

**中文 / CN**：玩家控制一只离巢蜜蜂，在 24 个节气节点流转的花田中采蜜、处理生态威胁，并在体力耗尽前把收获带回蜂巢。

**English / EN**: You control a bee across a field progressing through 24 solar-term nodes, gathering nectar, responding to ecological threats, and returning the harvest before stamina runs out.

> 核心问题 / Core question：再采一朵，还是现在归巢？
> One more flower, or return home now?

## 2. 愿景与原则 / Vision & Principles

| 中文 / CN | English / EN |
| --- | --- |
| 体验大于解释；玩家应从操作、画面和声音读懂因果 | Experience over exposition; causality should be readable through play, visuals, and sound |
| 蜂群而非孤胆英雄；归巢和公共资源比击杀重要 | The colony, not a lone hero; returning and shared resources matter more than kills |
| Boss 是偏离循环的“失律者”，胜利是调律而非削血条 | Bosses are “the Unregulated”; victory comes through tuning, not health depletion |
| 四组季节行为必须改变路线、顺序、撤离或资源选择 | Seasonal groups must change route, order, retreat, or resource decisions |
| 自动测试证明实现，不证明理解、有趣、审美或音乐品质 | Automation proves implementation, not comprehension, fun, aesthetics, or music quality |

## 3. 当前可玩结构 / Current Playable Structure

- `godot/data/seasons.json` 保留 24 个数据节点；不再是早期“四个压缩关卡”，也未改成已废止的 `4 × 3`。
  `seasons.json` retains 24 data nodes; the game is neither the old four compressed stages nor the rejected `4 × 3` restructuring.
- 春分、夏至、秋分是显式 Boss 节点；大雪后进入冬至失律之熊。
  Spring Equinox, Summer Solstice, and Autumn Equinox are explicit boss nodes; after Major Snow, the loop ends with the Winter Solstice bear encounter.
- 普通目标为 10～15，基础携带上限为 8，因此至少需要两次归巢。
  Normal goals are 10–15 against a base carry cap of 8, requiring at least two returns.
- 总时长只记录，不设 15～25 或 32～42 分钟通过区间。
  Total duration is measured, not judged against a fixed 15–25 or 32–42 minute range.

### 四组季节行为 / Four Seasonal Behavior Groups

| 组 / Group | 当前行为 / Current behavior |
| --- | --- |
| 春／授粉 Spring / Pollination | 开放花药取粉 → 蜂身松散散粉 → 同型开放柱头 → 结籽；不增加花蜜 / Open anther → loose pollen on bee → compatible visible stigma → seed setting; nectar is unchanged |
| 夏／袭扰 Summer / Raid | 首次真实卸蜜触发有翅劫掠者；其偷取真实花蜜，玩家逐只惊退并追回 / First real deposit triggers winged raiders that steal actual nectar; repel each to recover it |
| 秋／留种 Autumn / Seed | 最后一滴前强制松手，选择采尽或留种；真实归巢使种核成熟 / Release before the final drop, then harvest all or leave seed; a real return matures it |
| 冬／暖点 Winter / Warmth | 寒区降温减速；携蜜依次点亮 3 个暖点，逐段开放路线 / Cold slows the bee; spend carried nectar on three sequential warm relays to open the route |

### 四位失律者 / Four Unregulated Bosses

| Boss | 暴露条件 / Exposure condition |
| --- | --- |
| 失律之蚊 / Mosquito | 完成一次真实吸取 / Completes a real feed |
| 失律之油葫芦 / Field cricket | 跳跃真实落地 / Actually lands after a jump |
| 失律之画眉 / Thrush | 寻迹揭出真声 / Sense reveals the true echo |
| 失律之熊 / Bear | 玩家闪过冲锋，熊撞上暖息花 / Player evades the charge and the bear hits a warm bloom |

四位都需要 3 次调律，但后续阶段更快、窗口更短；不再把四位写成共用“引到花粉团按三次”的旧 Boss。
Each requires three tunings, with faster phases and shorter windows; they no longer share the old “lure to pollen and press three times” description.

## 4. 当前产品状态 / Current Product Status

| 领域 / Area | 当前事实 / Current fact | 尚未证明 / Not yet proven |
| --- | --- | --- |
| 工程 / Engineering | Web、macOS universal、Windows x86_64 同源导出；9 组 Godot 回归和 Web 门禁通过；标准输出尺寸的等比 HUD 安全框与饮蜜指针入口已接入 | Windows 真机完整流程、真实原生触屏与未覆盖设备表现 |
| 教学 / Tutorial | 老师傅“示范 → 模仿 → 无提示实践”已接入，关键动作由真实结果推进 | 陌生玩家无口头帮助；当前正常路线没有固定的延迟急转复测机会 |
| 音乐 / Music | 4 首探索 + 4 首 Boss 变奏，共 8 个独立 WAV；A–H 匿名盲听工具已合并并自动校验 | Alan 尚未完成主观盲听；配对、情绪、耐循环和实机混音待验证 |
| 视觉 / Visuals | 低噪地表、独立蜂巢、8 种季节花与机制实体已接入 | 运动中的画风统一和目标可读性 |
| 发行 / Release | `f57ea02c` 固定候选 artifact 已构建并复验 SHA-256 | Windows 真机、完整人工流程和外部试玩 |

## 5. 证据边界 / Evidence Boundary

- **实现事实 / Implemented facts**：PR #63 的玩法／资产、PR #64 的盲听工具和 PR #65 的 HUD 响应式／饮蜜指针输入均已进入 `origin/main` `f57ea02c`。
- **开发者自测 / Developer verification**：自动流程、构建、哈希、静态快照。
- **Alan 方向门禁 / Alan direction gate**：PR #63 整体方向与 PR #65 HUD 视觉／按钮方向均允许合并并继续，不等于逐项、原生触屏或发行验收。
- **外部玩家 / Independent players**：当前证据数为 **0**。

详细状态以 [`../PLAYER_FEEDBACK_ACTION_PLAN_2026-08-24.md`](../PLAYER_FEEDBACK_ACTION_PLAN_2026-08-24.md) 为准。
For detailed status, use [`PLAYER_FEEDBACK_ACTION_PLAN_2026-08-24.md`](../PLAYER_FEEDBACK_ACTION_PLAN_2026-08-24.md).

## 6. 当前验证问题 / Current Validation Questions

1. 陌生玩家能否不经口头提示完成第一趟，并用自己的话说明寻迹、惊退与急转的事实、操作和成功证据？当前正常路线没有固定的延迟急转复测机会；如需验证约 3 分钟后的保持，应先提供固定复测切片。
   Can a new player complete the first trip unaided and explain the facts, operation, and success evidence for sense, repel, and evade? The normal route has no fixed delayed evade retest; a dedicated slice is required before measuring retention after roughly three minutes.
2. 玩家能否不看文字分辨开放花药、同型柱头、蜂身散粉与结籽？
   Can players distinguish open anthers, compatible stigmas, pollen on the bee, and seed setting without text?
3. 四组机制是否真实改变路线、顺序、撤离或资源选择，而不是仍被概括为“都是采蜜”？
   Do the four groups change route, order, retreat, or resource choices instead of still feeling like “just harvesting”?
4. 四位 Boss 的失败原因能否分别复述？
   Can players explain the distinct failure rule of each boss?
5. 8 轨能否盲听配对并在循环中保持舒适？
   Can the eight tracks be paired in blind listening and remain comfortable in loops?
6. 各节点／Boss 的实际时长中，有多少是有判断的行动，多少是无决策重复？
   How much node/boss time is decision-making versus repetition?
