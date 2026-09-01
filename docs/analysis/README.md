# 历史项目分析与专项参考文档集

> 本文档集保留上一轮的分层项目分析和专项参考；其中旧标题、旧循环与旧范围只作历史追溯，不能覆盖当前商业规格。
> This document set preserves a historical layered analysis and dated specialist references. It is not the current product specification.

**历史快照版本 / Historical Snapshot**: 候选 MVP 0.9.5-rc.2（当时源码基线 `a58358c3ac90d6edac8a654777beb378d978b688` 已含 PR #90／#91；最近固定桌面 artifact `57aefc4933db88968777b11ea1d1679c6374842a` 只作历史 Main 局部反馈来源，不可用于下一轮 B01）
**同步日期 / Sync Date**: 2026-08-26

> Desktop build run `32867365895` 的 macOS／Windows artifact、sidecar 和 pack verifier 已通过。B01 第一次 exact-ticket 进程因交接失败没有结果，第二次经进程／代码／原话证据链判定进入 `Main`；错配短表只作 Alan Main 局部自测，尚无有效 B01 运行结果。Windows 真机和外部玩家仍待验证。

> 01–05 是旧 MVP 阶段的历史分析；06 是当前／历史混合的数值专项，必须按章节证据日期使用；07 是需要按核查日期更新的竞品专项。当前产品身份与商业范围只由 [`../design/commercial-product-requirements.md`](../design/commercial-product-requirements.md) 和 [`../design/solar-term-campaign-production-spec.md`](../design/solar-term-campaign-production-spec.md) 定义；根目录 README 只提供摘要与索引。
> Documents 01–05 are historical MVP analysis. Document 06 mixes dated and current numeric snapshots, while 07 is a dated competitive reference. Current identity and scope are defined only by the commercial requirements and campaign production specification; the repository README is an index and summary.

---

## 文档结构 / Document Hierarchy

| # | 文档 / Document | 内容 / Contents | 适合阅读对象 / Audience |
|---|-----------------|-----------------|------------------------|
| 01 | [项目总览](01-project-overview.md) | 一句话定位、愿景、世界观、当前状态 | 所有人 / Everyone |
| 02 | [技术架构](02-technical-architecture.md) | Godot 核心、Web 外壳、数据驱动、测试、三端导出 | 开发者 / Developers |
| 03 | [玩法与设计](03-gameplay-design.md) | 核心循环、操作、四季、敌人、Boss、成长 | 设计者 / Designers |
| 04 | [阶段目标](04-stage-goals.md) | 版本历程、当前目标、MVP 验收、里程碑 | 项目管理者 / PMs |
| 05 | [关键词表](05-keyword-glossary.md) | 中英术语对照表 | 所有人 / Everyone |
| 06 | [数值设计总览](06-numeric-design.md) | 当前／历史混合的数值快照、设置依据与调参工作流；按章节日期使用 | 设计者 / Designers |
| 07 | [竞品对比分析](07-competitive-analysis.md) | 结合 Alan 偏好的 20 款独立及相邻游戏市场对比、参照职责、制作优先级、Demo 与验证指标 | 设计者/发行 / Designers & Publishing |

---

## 阅读建议 / How to Read

- **了解当前产品**：从根目录 README 的“文档事实源与边界”开始，不把 01–05 当现行规格；06 只按具体章节的证据日期使用。
- **追溯旧 MVP**：按 01 → 04 阅读；05 提供当时的术语背景。
- **竞品参考**：读取 07，并在做商业决定前按文档日期重新核查外部数据。

> 每个文档内部采用「中文在前、英文在后」的双语段落结构。
> Each document uses a bilingual section structure: Chinese first, then English.

---

## 相关外部文档 / Related External Docs

| 文档 / Document | 路径 / Path | 说明 / Note |
|-----------------|-------------|-------------|
| 商业成品要求 / Commercial Product Requirements | `docs/design/commercial-product-requirements.md` | 当前商业身份、完整范围与发行退出清单的唯一事实源（中文） |
| 三候战役制作规格 / Campaign Production Spec | `docs/design/solar-term-campaign-production-spec.md` | 当前 24 章节、360 项内容目标与存档边界的唯一专项规格（中文） |
| 成熟度与生产重量 / Maturity & Production Weight | `docs/GAME_MATURITY_AND_PRODUCTION_ASSESSMENT.md` | 从两份权威规格派生的当前评估，不另立范围（中文） |
| 玩家反馈整改与验证 / Feedback Implementation & Validation | `docs/PLAYER_FEEDBACK_ACTION_PLAN_2026-08-24.md` | 历史执行记录、证据等级与外测方法；冲突时服从当前规格（中文） |
| MVP 规格 / MVP Spec | `docs/MVP_SPEC.md` | 旧 MVP 范围与验收标准，不是当前商业范围（中文） |
| 设计共识与实现差距 / Design Consensus & Gaps | `docs/DESIGN_CONSENSUS.md` | 历史共识与实现差距；冲突时服从当前规格（中文） |
| 项目策划记录 / Project Log | `docs/PROJECT_LOG.md` | 历史版本决策；保留被后续推翻的旧方案（中文） |
| 色彩体系 / Color System | `docs/COLOR_SYSTEM.md` | 二十四节气阴阳消长色谱：四正色与连续色彩区间；不定义现行关卡拓扑（中文） |
