# 05 · 关键词表 / Keyword Glossary

> 项目内外沟通用的中英术语对照表。用于设计讨论、代码注释、文档与试玩反馈的统一表达。
> Bilingual glossary for internal and external communication — unified terms for design discussion, code comments, docs, and playtest feedback.

---

## 1. 玩法术语 / Gameplay Terms

| 中文 / CN | English / EN | 说明 / Note |
|-----------|--------------|-------------|
| 无名：成蜂 | Nameless: Becoming | 项目名 / Project name（旧名：归巢之前 Hivebound Seasons） |
| 搜、打、撤 | Search, Fight, Extract | 核心循环类型 / Core loop genre |
| 肉鸽 | Roguelike | 品类标签 / Genre tag |
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
| 失律之蚊 | The Unregulated Mosquito | 首个 Boss 原型 / First boss archetype |
| 掠蜜蚁 | Honey-Thief Ant | 偷蜜小怪 / Nectar-stealing enemy |
| 蚊虫 | Mosquito | 追击型小怪 / Chasing enemy |
| 油葫芦 | Field Cricket | Boss 原型：漂泊 / Boss archetype: drifting |
| 画眉 | Thrush | Boss 原型：诱惑 / Boss archetype: allure |
| 返蜜花 | Return-Nectar Flower | 洒落蜜形成的花 / Flower formed from spilled nectar |
| 调律 | Tuning | 对失律者的非击杀胜利方式 / Non-kill victory against the Unregulated |
| 共鸣花粉 | Resonance Pollen | 调律用的花粉团 / Pollen clusters for tuning |
| 架空节令 | Fictional World States | 异常关卡概念（初蜜、盛鸣等） |

---

## 3. 节令与阴阳 / Solar Terms & Yin-Yang

| 中文 / CN | English / EN | 阴阳 / Yin:Yang |
|-----------|--------------|-----------------|
| 二十四节气 | 24 Solar Terms | — |
| 春分 | Spring Equinox | 50:50 |
| 夏至 | Summer Solstice | 15:85（阳极阴生） |
| 秋分 | Autumn Equinox | 50:50 |
| 冬至 | Winter Solstice | 85:15（阴极阳生） |
| 阴阳消长 | Yin-Yang Flux | 组织关卡节奏的核心概念 |

---

## 4. 蜂巢成长 / Hive Upgrades

| 中文 / CN | English / EN | ID | 效果 / Effect |
|-----------|--------------|----|---------------|
| 长翼蜂 | Long-Winged Bee | `long_wing` | 速度 +10%，振翅耗能 -15% |
| 采蜜蜂 | Forager Bee | `forager` | 采蜜间隔 -15%，额外保留 1 滴 |
| 守卫蜂 | Guard Bee | `guard` | 惊退范围 +18%，冷却 -15% |

---

## 5. 技术术语 / Technical Terms

| 中文 / CN | English / EN | 说明 / Note |
|-----------|--------------|-------------|
| 数据驱动 | Data-driven | 数值外部化到 JSON / Values externalized to JSON |
| 三端同源导出 | Single-source export | 同一 Godot 工程导出三端 / One project, three targets |
| Web 承载外壳 | Web shell | 非第二套玩法代码 / Not a second gameplay codebase |
| 传输分片 | Transfer sharding | WASM 拆分传输后重组 / WASM sharded for transfer |
| 程序化占位美术 | Procedural placeholder art | 无外部素材的占位表现 |
| 程序化音效 | Procedural audio | 代码生成的音效与 BGM |
| 蜂巢呼吸 | Hive breaths | 失败损失的生命计数（3 次） |
| 软锁 | Soft-lock | 无法继续但未崩溃的状态（0.9.3 已修复） |
| 拒绝采样 | Rejection sampling | 花朵生成中心距 ≥82px 的算法 |

---

## 6. 文档与流程 / Docs & Process

| 中文 / CN | English / EN | 说明 / Note |
|-----------|--------------|-------------|
| 项目策划记录 | Project Log | `docs/PROJECT_LOG.md` |
| MVP 规格 | MVP Spec | `docs/MVP_SPEC.md` |
| 候选 MVP | Candidate MVP | 0.9 阶段状态 |
| 验收标准 | Acceptance criteria | 1.0 判定依据 |
| 里程碑 | Milestone | 版本交付节点 |
| 试玩记录模板 | Playtest template | 设备/首次归巢时间/失败原因等 |
| 版本门禁 | Version gate | 全部通过才升级版本 |
