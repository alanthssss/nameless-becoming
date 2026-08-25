# 04 · 阶段目标 / Stage Goals

> 当前目标不是继续扩写系统，而是把 `0.9.5-rc.2` 的实现事实、人工验收与外部玩家证据闭环。
> The current goal is not to add systems, but to close the loop between implementation, manual acceptance, and independent player evidence for `0.9.5-rc.2`.

当前可玩实现基线 / Current playable baseline：`f57ea02c`（PR #65）；玩法与资产来自 PR #63，盲听工具来自 PR #64；PR #67 只增加试玩证据工具与文档。
固定验收候选 / Fixed acceptance candidate：`f57ea02c`。

---

## 1. 历史里程碑 / Historical Milestones

本节只记录版本演化；“四关”“首个 Boss”“旧四季机制”和早期时长均是当时事实，不是当前规格。
This section records history only; the old four stages, first-boss prototype, old seasonal mechanics, and early duration targets are not current specifications.

| 版本 / Version | 当时交付 / Historical delivery | 当前意义 / Current interpretation |
| --- | --- | --- |
| 0.1–0.3 | 规则原型、直接控制与 Godot 垂直切片 | 证明技术和空间操作方向，不代表当前内容范围 |
| 0.4 | 飞行、惯性、体力与玩家控制拆分 | 当前移动骨架来源 |
| 0.5–0.7 | 普通敌害、蜂巢成长、首个失律之蚊 | 已被四位独立 Boss 和 24 节点结构扩展 |
| 0.8 | 标题、暂停、设置、结算与本地存档 | 当前产品外壳基础 |
| 0.9.4–rc.1 | 数据、CI、三端导出、字体与桌面候选 | 当前构建链基础 |
| 0.9.5-rc.2 / PR #63 | 24 节点可感知整改、老师傅教学、四组季节行为、四位 Boss、8 轨音乐、产品 HUD、构建来源 | 当前候选实现基线 |
| PR #64 | 8 轨 A–H 匿名盲听包、独立答案和自动校验 | 解除主观盲听的工具依赖，不代表 Alan 已完成听感验收 |
| PR #65 | 1280×720 参考画布的等比安全框、按条件显示的饮蜜指针／触摸入口与第九组 Godot 回归 | 当前 HUD 与输入实现基线；不代表真实原生触屏或任意宽高比重排已验收 |

## 2. 当前阶段结论 / Current Stage Conclusion

| 证据层 / Evidence layer | 状态 / Status | 结论 / Conclusion |
| --- | --- | --- |
| 实现 / Implementation | 已完成当前批次 | PR #63 的玩法／资产、PR #64 的盲听工具和 PR #65 的 HUD 响应式／饮蜜指针输入形成固定可玩实现 `f57ea02c`；PR #67 不改游戏二进制 |
| 开发者自测 / Developer verification | 通过 | 9 组 Godot 回归、Web 门禁、artifact 与 SHA-256 复验、盲听工具自动校验通过 |
| Alan 方向门禁 / Direction gate | 通过 | PR #63 整体方向与 PR #65 HUD 视觉／按钮方向均获准合并；不代表逐项、原生触屏或发行通过 |
| Alan 完整人工流程 / Full manual pass | 部分记录、未通过 | `f57ea02c` 首份 A 包在首分钟采蜜反馈处卡住且后半问卷疲劳；八轨逐轨评论已完成，D/G 触发 A/B，但总体配对与实机混音缺失；四季、Boss、节奏仍需记录 |
| Windows 真机 / Windows hardware | 未完成 | artifact 格式与哈希已验证，设备流程未验证 |
| 外部玩家 / Independent players | **0** | 不能声明教学、趣味、时长、审美或音乐已获玩家认可 |

## 3. 当前 P0 / Current P0

### 3.1 文档事实源一致性 / Documentation Consistency

- 当前规格统一为 24 节气节点推进，不写早期“四个压缩关卡”或废止的 `4 × 3`；
- 四位 Boss 均已接入，分别使用吸取、落地、寻迹真声、急转撞暖花作为暴露条件；
- 音乐为 4 首探索 + 4 首 Boss 变奏；
- 春季为开放花药 → 蜂身散粉 → 同型开放柱头 → 结籽，授粉不产蜜；
- 夏、秋、冬当前主行为分别为实体袭扰、野外留种、三暖点路线；
- 总时长只记录，不设 15～25 或 32～42 分钟通过门槛。

### 3.2 Alan 固定候选人工流程 / Alan Fixed-Build Pass

1. 先在新候选复测“贴近花心并持续按住”的首分钟采蜜反馈，再不经口头提示完成首节点；
2. 急转真实完成 `1/2 → 2/2`；
3. 用自己的话说明寻迹、惊退与急转的事实、操作和成功证据；如需验证约 3 分钟后的保持，先提供固定复测切片；
4. 不看说明分辨花药、柱头、蜂身散粉和结籽，并复述授粉因果；
5. 体验夏季袭扰、秋季留种、冬季暖点并描述实际改过的路线或选择；
6. 分别复述四位 Boss 的暴露规则；
7. 记录各节点／Boss 用时、失败点和无决策重复时长；
8. 对 D 秋 Boss 与 G 秋探索完成修改前后 A/B，再补同季配对、总体区分度和实机混音；其余六轨不因本次证据重写。

### 3.3 发布人工流程 / Release Manual Pass

- Windows x86_64 真机完成启动、DPI／全屏、中文字体、声音、设置持久化与退出；
- macOS 固定候选完成一整轮和设置重启；
- 验证标题／暂停层来源为 `v0.9.5-rc.2 · f57ea02c`，不含 `+dirty`；
- 1280×720 是 HUD 参考画布；1920×1080、1440×900 与 1024×768 的等比安全框已自动验证，但任意宽高比世界重排和手机正式适配未承诺；
- 饮蜜已有按条件显示的鼠标／显式触摸入口；仍须在真实原生触屏设备上验证手感、取消和系统缩放。

### 3.4 外部玩家 / Independent Playtests

当前样本为 0。会话 `NB-20260825-D9EFAA79` 虽自报外部玩家，但填写者与开发关系尚未由协调者确认，确认前不计样本。首轮记录：

- 首次移动、采蜜、交蜜时间与所有口头求助；
- 急转两次及玩家对因果的自由复述；当前路线未提供固定延迟复测机会，缺失记录不得算迁移失败；
- 授粉因果与四组季节行为的玩家原话；
- 各节点／Boss 用时、失败原因、退出点、主动撤离和重开；
- 8 轨配对、情绪、不舒服音色与循环疲劳；
- 不把开发者解释改写成玩家证据。

## 4. 当前验收标准 / Current Acceptance Criteria

### 自动与构建 / Automated and Build

- Godot 4.6.2 的 9 组测试均显式报告 `TEST PASSED`；
- Web build/test/lint 通过；
- 24 节点数据、资源预算、完成条件、四组机制、四位 Boss、8 轨路由和构建来源受门禁覆盖；
- macOS universal／Windows x86_64 artifact 的 sidecar SHA-256 复验通过。

### 可玩性 / Playability

- 所有阻塞结算的条件从节点开始常驻，最后一项完成后立即结算；
- 首节点真实世界结果推进教学，单纯按键不能通过；
- 不存在资源必然不足、隐藏门禁、无法撤离或不可恢复的教学软锁；
- 四组季节行为和四位 Boss 的独立规则能被真人从操作、画面或声音描述；
- 记录实际时长和重复劳动，不用固定总时长替代节奏判断。

### 发行 / Release

- Windows 真机、macOS 完整流程、设置持久化与失败／重试路径有人工记录；
- 商店声明的平台、输入、语言和功能与实际一致；
- 外部玩家证据达到发布计划要求前，只能称内部／封闭验证候选，不能称玩家验收完成。

## 5. 条件任务 / Evidence-Triggered Work

| 触发证据 / Trigger | 才允许开始的任务 / Conditional task | 成功判据 / Success criterion |
| --- | --- | --- |
| 需要验证约 3 分钟后的急转保持 | 先提供固定同语法复测切片；再由结果决定是否让普通敌害复用锁线语法 | 未遇到机会不判失败；复测时无文字再次闪过 |
| 四组仍被概括为“都是采蜜” | 四季路线深化 | 每组至少观察到一次不同路线、顺序、撤离或资源选择 |
| 节点仍短或只是机械重复 | 节奏与 Boss 调律 | 依据用时、失败原因和重复劳动改内容，不只抬目标 |
| 视觉仍不协调 | 单代表场景画风切片 | 先通过一张实机场景，再批量生产 |
| 某轨／民乐标点不舒服 | 定向音乐修订 | 只修被盲听指出的轨并提交 A/B |
| 中继巢确实带来主动改线 | 第二据点实验 | 不破坏主巢、Q 归巢与交付语义唯一性 |

未出现触发证据时，这些不是已排产功能。

## 6. 明确不做／未承诺 / Out of Scope or Uncommitted

| 中文 / CN | English / EN |
| --- | --- |
| 废止的 `4 × 3` 大关重构 | Rejected `4 × 3` stage restructure |
| 固定 15～25 或 32～42 分钟通过目标 | Fixed 15–25 or 32–42 minute pass target |
| 24 套独立美术、24 首音乐或每节点独立 Boss | 24 unique art sets, 24 tracks, or a unique boss per node |
| 多个等价主巢、开放世界和第二模式 | Multiple equivalent main hives, open world, or second mode |
| 新可玩蜂种、身份徽章和深度元进度 | New playable bee species, identity badges, or deep meta progression |
| 联机、排行榜、账号、付费、广告与手机正式适配 | Multiplayer, leaderboards, accounts, monetization, ads, or formal mobile support |

## 7. 下一版本判定 / Next Version Gate

`1.0 MVP` 或公开 Demo 的命名必须基于人工设备流程和独立玩家证据，而不是当前代码量、自动化数量、固定时长或 Alan 的方向批准。详细执行矩阵以 [`../PLAYER_FEEDBACK_ACTION_PLAN_2026-08-24.md`](../PLAYER_FEEDBACK_ACTION_PLAN_2026-08-24.md) 为准。
