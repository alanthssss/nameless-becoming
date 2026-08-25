# 05 · 关键词表 / Keyword Glossary

> 项目内外沟通用的中英术语对照表。用于设计讨论、代码注释、文档与试玩反馈的统一表达。
> Bilingual glossary for internal and external communication — unified terms for design discussion, code comments, docs, and playtest feedback.

---

## 1. 玩法术语 / Gameplay Terms

| 中文 / CN | English / EN | 说明 / Note |
|-----------|--------------|-------------|
| 无名：成蜂 | Nameless: Becoming | 项目名 / Project name（旧名：归巢之前 Hivebound Seasons） |
| 搜、打、撤 | Search, Fight, Extract | 核心循环类型 / Core loop genre |
| Rogue / 肉鸽 | Roguelike / Roguelite | 候选市场标签；当前不作为已定品类，待外测验证重玩与构筑预期 / Candidate tag pending replay and build evidence |
| 搜 | Search | 寻找花蜜 / Finding nectar |
| 采蜜 | Harvest | 持续采集花蜜 / Sustained nectar gathering |
| 撤 | Extract | 亲自飞回蜂巢 / Flying back to the hive in person |
| 归巢 | Return to hive | 结算动作 / Settlement action |
| 体力 | Stamina / Energy | 核心资源 / Core resource |
| 携蜜 | Carried nectar | 携带中的蜜 / Honey in transit |
| 公共储备 | Public reserve | 蜂群共享储备 / Colony-shared reserve |
| 贪与撤 | Greed vs. Retreat | 核心抉择 / Core decision |
| 再采一朵，还是现在归巢？ | One more flower, or return now? | 核心提问 / Core question |
| 振翅 | Dash | 快速位移技能 / Rapid movement skill |
| 震翼惊退 | Wing Repel | 推开敌人 / Repelling enemies |
| 触角寻迹 | Antenna Sense | 辅助感知技能 / Assistive sensing skill |
| 急转闪避 | Evade | 侧掠闪避 / Sidestep dodge |
| 投蜜诱饵 | Nectar Decoy | 吸引敌人的诱饵 / Enemy-attracting decoy |
| 蜂针 | Sting | 未来可能的不可逆抉择 / Future irreversible choice |

---

## 2. 世界观术语 / Worldbuilding Terms

| 中文 / CN | English / EN | 说明 / Note |
|-----------|--------------|-------------|
| 失律者 | The Unregulated | 偏离自然循环的 Boss / Bosses deviating from the natural cycle |
| 失律之蚊 | The Unregulated Mosquito | 春分 Boss；真实吸取后短暂暴露 / Spring Equinox boss; exposed after a real feed |
| 掠蜜蚁 | Honey-Thief Ant | 偷蜜小怪 / Nectar-stealing enemy |
| 蚊虫 | Mosquito | 追击型小怪 / Chasing enemy |
| 失律之油葫芦 | The Unregulated Field Cricket | 夏至 Boss；落地停顿后暴露 / Summer Solstice boss; exposed after landing |
| 失律之画眉 | The Unregulated Thrush | 秋分 Boss；寻迹揭出真声 / Autumn Equinox boss; sense reveals the true echo |
| 失律之熊 | The Unregulated Bear | 冬至 Boss；闪过冲锋并撞暖息花后暴露 / Winter Solstice boss; exposed after an evaded charge hits a warm bloom |
| 返蜜花 | Return-Nectar Flower | 洒落蜜形成的花 / Flower formed from spilled nectar |
| 调律 | Tuning | 对失律者的非击杀胜利方式 / Non-kill victory against the Unregulated |
| 共鸣实体 | Resonance entity | Boss 暴露后登记调律的位置；不得与春季授粉花粉混为一谈 / Tuning location after boss exposure; distinct from pollination pollen |
| 架空节令 | Fictional World States | 异常关卡概念（初蜜、盛鸣等） |

---

## 3. 节令、色彩与阴阳 / Solar Terms, Colors & Yin-Yang

| 中文 / CN | English / EN | 说明 / Note |
|-----------|--------------|-------------|
| 二十四节气 | 24 Solar Terms | 当前 24 数据节点推进；不是旧四关或已废止的 `4 × 3` / Current 24-node progression, not the old four stages or rejected `4 × 3` |
| 四正色 | Four Zhengse | 玄/青/朱/白，阴阳消长的四个正色 |
| 玄 | Xuan | 阴之极 `#101420`，冬之正色 |
| 青 | Qing | 春分之正色 `#008080` |
| 朱 | Zhu | 阳之极 `#DC3C3C`，夏之正色 |
| 白 | Bai | 秋分之正色 `#F5F5F5` |
| 两至两分 | The two solstices & two equinoxes | 四正色的文化／色彩锚点；不等于四个数组内守关关卡 |
| 守关 Boss | Gate boss | 历史结构用语；当前应写“显式 Boss 节点”或“大雪后终点熊” |
| 春分 | Spring Equinox | 正青；`seasons.json` 显式失律之蚊节点 |
| 夏至 | Summer Solstice | 正朱；`seasons.json` 显式失律之油葫芦节点 |
| 秋分 | Autumn Equinox | 正白；`seasons.json` 显式失律之画眉节点 |
| 冬至 | Winter Solstice | 正玄；大雪后由状态流进入失律之熊，不是第 25 个数据条目 |
| 阴阳消长 | Yin-Yang Flux | 组织关卡色调与节奏的核心概念 |

---

## 4. 蜂巢成长与身份 / Hive Upgrades & Identity

| 中文 / CN | English / EN | ID | 效果 / Effect |
|-----------|--------------|----|---------------|
| 长翼蜂 | Long-Winged Bee | `long_wing` | 速度 +10%，振翅耗能 -15% |
| 采蜜蜂 | Forager Bee | `forager` | 采蜜间隔 -15%，额外保留 1 滴 |
| 守卫蜂 | Guard Bee | `guard` | 惊退范围 +18%，冷却 -15% |
| 属性节点 | Attribute node | — | 三选一升级去职业化后的纯能力构筑 |
| 成就徽章 | Achievement badge | — | 未承诺候选；不在当前 MVP，只能由重玩／身份表达证据触发 |
| 侦察 | Scouting | — | 当前只有蜂巢活动表现；徽章达阶解锁属历史候选，未实现 |

## 4.1 四季机制 / Seasonal Mechanics

| 中文 / CN | English / EN | 归属 / Season | 玩法 / Gameplay |
|-----------|--------------|---------------|-----------------|
| 授粉 | Pollination | 春 | 开放花药 → 蜂身散粉 → 同型开放柱头 → 结籽；不产蜜 |
| 袭扰（代码 ID：征召） | Raid (`conscription`) | 夏 | 首次真实卸蜜触发实体劫掠者；逐只惊退并追回花蜜 |
| 留种（代码 ID：储备） | Seed choice (`reserve`) | 秋 | 最后一滴前松手；采尽或留种并在真实归巢后成熟 |
| 暖点（代码 ID：抱团） | Warmth relay (`huddle`) | 冬 | 寒冷减速 + 3 个顺序蜂蜡暖点 + 路线开放 |

---

## 5. 技术术语 / Technical Terms

| 中文 / CN | English / EN | 说明 / Note |
|-----------|--------------|-------------|
| 数据驱动 | Data-driven | 主要可配值在多个 JSON；状态机与部分手感参数仍在脚本 / Primary tunables in multiple JSON files; state machines and some feel constants remain in scripts |
| 三端同源导出 | Single-source export | 同一 Godot 工程导出三端 / One project, three targets |
| Web 承载外壳 | Web shell | 非第二套玩法代码 / Not a second gameplay codebase |
| 传输分片 | Transfer sharding | WASM 拆分传输后重组 / WASM sharded for transfer |
| 程序化占位美术 | Procedural placeholder art | 无外部素材的占位表现 |
| 程序化音效 | Procedural audio | 高频动作 cue；当前背景音乐为 8 个独立 WAV，不再由旧单一循环承担 |
| 蜂巢呼吸 | Hive breaths | 失败损失的生命计数（3 次） |
| 软锁 | Soft-lock | 无法继续但未崩溃的状态（0.9.3 已修复） |
| 拒绝采样 | Rejection sampling | 花朵生成中心距 ≥82px 的算法 |

---

## 6. 文档与流程 / Docs & Process

| 中文 / CN | English / EN | 说明 / Note |
|-----------|--------------|-------------|
| 玩家反馈整改与验证记录 | Feedback implementation and validation | 当前事实与证据边界：`docs/PLAYER_FEEDBACK_ACTION_PLAN_2026-08-24.md` |
| 项目策划记录 | Project Log | 历史记录：`docs/PROJECT_LOG.md`，不直接作为现行规格 |
| MVP 规格 | MVP Spec | 当前范围：`docs/MVP_SPEC.md` |
| 候选 MVP | Candidate MVP | 0.9 阶段状态 |
| 验收标准 | Acceptance criteria | 1.0 判定依据 |
| 里程碑 | Milestone | 版本交付节点 |
| 试玩记录模板 | Playtest template | 设备/首次归巢时间/失败原因等 |
| 版本门禁 | Version gate | 全部通过才升级版本 |
