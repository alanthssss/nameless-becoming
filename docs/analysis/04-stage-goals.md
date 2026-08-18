# 04 · 阶段目标 / Stage Goals

> 从规则原型到候选 MVP 的完整路径，以及通往 1.0 MVP 的验收标准。
> The full path from rules prototype to candidate MVP, plus the acceptance criteria on the road to a 1.0 MVP.

---

## 1. 版本历程 / Version History

| 版本 / Version | 阶段目标 / Stage Goal | 核心成果 / Key Outcome | 结论 / Conclusion |
|----------------|----------------------|------------------------|-------------------|
| 0.1 | 规则原型 / Rules prototype | 按钮式选择验证搜打撤宏观闭环 | 规则成立但缺空间感与动作感 |
| 0.2 | 核心交互原型 / Core interaction | 直接控制飞行、持续采蜜、体力与冲刺、蚊虫追击、必须归巢结算、四压缩节令 | 需要真实试玩验证"贪与撤"犹豫 |
| 0.3 | Godot 单机垂直切片 / Godot vertical slice | 技术路线确定为 Godot 4；首个单机切片 | 转向手感验证，非内容生产 |
| 0.4 | 飞行手感与玩家控制拆分 | 拆分 BeePlayer；加速/惯性/制动模型；感知技能 E；统一体力消费接口 | 为成长、敌人、设置预留扩展点 |
| 0.5 | 生态压力与失律者 | 掠蜜蚁；四节令敌人组合差异；失律之蚊非传统 Boss（三处共鸣花粉调律） | 验证生态叙事 |
| 0.6 | 蜂巢分工成长 | 节令间三选一成长；长翼/采蜜/守卫蜂；JSON 驱动 | 轻量构筑差异 |
| 0.8 | 单机产品外壳（第一轮） | 标题界面、暂停、窗口/全屏、本地存档（不存局中状态） | 产品化起步 |
| 0.9 | 候选 MVP（进行中） | 程序化音效、外部 balance.json、发布清单、双平台构建、GitHub 预发布 | 迈向 1.0 MVP |
| 0.9.x | 世界规则修订与打磨 | 移除感知→重做为触角寻迹；蜂针退出普通攻击→震翼惊退；资源守恒；六键区；四季 BGM | 每轮试玩反馈驱动 |

---

## 2. 当前阶段目标 / Current Stage Goals

**中文 / CN**：当前处于 **0.9 候选 MVP 收尾**，核心目标是让外部试玩者能下载并完成完整流程，收集真实试玩数据。

**English / EN**: Currently closing out **v0.9 Candidate MVP**, the core goal is getting external playtesters to download and complete the full flow, collecting real playtest data.

### 待完成事项 / Open Items

| 事项 / Item | 说明 / Note |
|-------------|-------------|
| 桌面构建验证 / Desktop build validation | 仅 macOS 完成原生启动验证，Windows 待验证 |
| 人工全流程测试 / Manual full-flow testing | 键盘 + 鼠标两条路线 |
| 外部试玩 / External playtesting | 至少 5 名未参与策划的人 |
| 升级 1.0 MVP 判定 / 1.0 MVP gate | 上述全部通过后才升级 |

### 版本判定条件 / Version Gate

> 只有桌面构建、人工全流程和外部试玩全部通过后，才升级为 1.0 MVP。

---

## 3. MVP 验收标准 / MVP Acceptance Criteria

### 可玩性 / Playability

- 新玩家不阅读外部说明，60 秒内完成第一次采蜜和归巢
- 从标题开始可完整经历四节令、一次蜂巢成长和 Boss 结算
- 正常一局 15～25 分钟
- 不存在无法继续、无法撤离或资源必然不足的状态
- 键盘和鼠标均可完成整个流程

### 技术 / Technical

- Godot 4.6.2 启动与主场景无脚本错误
- 关卡、敌人和成长数值来自外部数据
- 自动检查覆盖数据结构、场景加载和核心公式
- 目标机器持续达到 60 FPS
- 可导出 macOS 与 Windows 调试包
- GitHub 的 `main` 始终保持可运行

### 试玩 / Playtesting

- 至少 5 名未参与策划的人试玩
- 至少 3 人在一次出巢中主动选择放弃远花并归巢
- 至少 3 人失败后主动开始第二局
- 记录首次归巢时间、死亡原因、最紧张时刻和最困惑时刻

---

## 4. 里程碑表 / Milestone Map

| 版本 / Version | 交付物 / Deliverable | 完成条件 / Completion Criteria |
|----------------|----------------------|-------------------------------|
| 0.4 | 工程重构与手感 | 核心系统拆分，操作与反馈稳定 |
| 0.5 | 四节令内容 | 两类敌人、四关均可完成 |
| 0.6 | 蜂巢成长 | 三选一成长改变实际手感 |
| 0.7 | 失律者 | 首个非传统 Boss 可完成 |
| 0.8 | 产品外壳 | 标题、教程、暂停、设置、结算、存档 |
| 0.9 | 候选 MVP | 自动测试、平衡、音画占位、桌面构建 |
| 1.0 | MVP 试玩交付 | 全流程验收并完成首轮外部试玩 |

---

## 5. 下一阶段候选 / Next-Phase Candidates

**中文 / CN**：只有 0.2 的核心互动通过试玩后，才进入下列工作（MVP 不扩展二十四关或四个完整 Boss）：

**English / EN**: Only after the core interaction passes playtesting will the following work begin (the MVP does not expand to 24 stages or four full bosses):

1. 调整飞行惯性、采蜜时间、敌人速度和撤离距离
2. 增加一种与蚊虫行为明显不同的小怪
3. 将一个节令扩展为包含路线选择的小地图
4. 增加蜂巢中的一次资源分配决策
5. 制作第一个失律者遭遇
6. 再决定是否从四节令扩展到二十四关

---

## 6. 明确不做 / Explicitly Out of Scope

| 中文 / CN | English / EN |
|-----------|--------------|
| 二十四个完整关卡 | 24 full stages |
| 四个完整 Boss | 4 full bosses |
| 开放世界、地图传送与支线任务 | Open world, fast travel, side quests |
| 装备、背包、品质、抽卡、商店和货币体系 | Gear, inventory, rarity, gacha, shops, currency |
| 大量剧情对白与完整配音 | Extensive dialogue and full voice acting |
| 联机、排行榜、账号、付费与广告 | Multiplayer, leaderboards, accounts, monetization, ads |
| 最终商业美术 | Final commercial art |
| 手机正式适配 | Formal mobile adaptation |

---

## 7. 建议的协作节奏 / Suggested Collaboration Cadence

**中文 / CN**：基于当前阶段目标，建议以下迭代节奏：

**English / EN**: Based on the current stage goals, here is the suggested iteration cadence:

| 周期 / Cadence | 活动 / Activity | 产出 / Output |
|----------------|-----------------|---------------|
| 每次试玩后 / After each playtest | 收集反馈 → 定位根因 → 调整数据/代码 | 版本记录 + 修复 |
| 每周 / Weekly | 全流程自动测试 + 平衡审查 | 测试报告 |
| 里程碑 / Per milestone | 对照验收标准逐项核对 | 版本判定 |
