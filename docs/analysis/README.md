# 无名：成蜂 · 项目分析文档集

> 本文档集将上一轮的项目分析整理为分层的中英双语文档，避免单一长文档造成阅读负担。
> This document set restructures the project analysis into layered bilingual (中文/EN) documents, avoiding the burden of a single lengthy file.

**项目版本 / Project Version**: 候选 MVP 0.9.5-rc.2（当前源码与固定 artifact 为 `de78f2c`，包含 PR #76 秋季双轨）
**同步日期 / Sync Date**: 2026-08-25

> 01–04 描述当前产品与执行边界；05–07 是专项参考，若与当前实现冲突，应回到 `godot/`、`MVP_SPEC.md` 和 `PLAYER_FEEDBACK_ACTION_PLAN_2026-08-24.md` 核对。`PROJECT_LOG.md` 是历史记录，不是现行规格。
> Documents 01–04 describe the current product and execution boundary. Documents 05–07 are specialist references; when they conflict with implementation, check `godot/`, `MVP_SPEC.md`, and `PLAYER_FEEDBACK_ACTION_PLAN_2026-08-24.md`. `PROJECT_LOG.md` is historical, not a current spec.

---

## 文档结构 / Document Hierarchy

| # | 文档 / Document | 内容 / Contents | 适合阅读对象 / Audience |
|---|-----------------|-----------------|------------------------|
| 01 | [项目总览](01-project-overview.md) | 一句话定位、愿景、世界观、当前状态 | 所有人 / Everyone |
| 02 | [技术架构](02-technical-architecture.md) | Godot 核心、Web 外壳、数据驱动、测试、三端导出 | 开发者 / Developers |
| 03 | [玩法与设计](03-gameplay-design.md) | 核心循环、操作、四季、敌人、Boss、成长 | 设计者 / Designers |
| 04 | [阶段目标](04-stage-goals.md) | 版本历程、当前目标、MVP 验收、里程碑 | 项目管理者 / PMs |
| 05 | [关键词表](05-keyword-glossary.md) | 中英术语对照表 | 所有人 / Everyone |
| 06 | [数值设计总览](06-numeric-design.md) | 关键数值、设置依据、交互与反馈清单、调参工作流 | 设计者 / Designers |
| 07 | [竞品对比分析](07-competitive-analysis.md) | 品类坐标、8 款竞品详析、六维矩阵、优劣与机会威胁 | 设计者/发行 / Designers & Publishing |

---

## 阅读建议 / How to Read

- **快速了解项目**：读 01 与 05 即可 / For a quick overview, read 01 and 05.
- **技术协作**：读 02 与 04 / For technical collaboration, read 02 and 04.
- **设计讨论**：读 03 / For design discussion, read 03.

> 每个文档内部采用「中文在前、英文在后」的双语段落结构。
> Each document uses a bilingual section structure: Chinese first, then English.

---

## 相关外部文档 / Related External Docs

| 文档 / Document | 路径 / Path | 说明 / Note |
|-----------------|-------------|-------------|
| 玩家反馈整改与验证 / Feedback Implementation & Validation | `docs/PLAYER_FEEDBACK_ACTION_PLAN_2026-08-24.md` | 当前实现事实、证据等级、执行矩阵与外测标准（中文） |
| MVP 规格 / MVP Spec | `docs/MVP_SPEC.md` | 当前候选范围与验收标准（中文） |
| 设计共识与实现差距 / Design Consensus & Gaps | `docs/DESIGN_CONSENSUS.md` | 当前稳定共识、实现边界与证据触发任务（中文） |
| 项目策划记录 / Project Log | `docs/PROJECT_LOG.md` | 历史版本决策；保留被后续推翻的旧方案（中文） |
| 色彩体系 / Color System | `docs/COLOR_SYSTEM.md` | 二十四节气阴阳消长色谱：四正色与连续色彩区间；不定义现行关卡拓扑（中文） |
