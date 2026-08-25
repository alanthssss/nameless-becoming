# 04 · 阶段目标 / Stage Goals

> 当前目标不是继续扩写系统，而是把 `0.9.5-rc.2` 的实现事实、人工验收与外部玩家证据闭环。
> The current goal is not to add systems, but to close the loop between implementation, manual acceptance, and independent player evidence for `0.9.5-rc.2`.

当前源码基线 / Current source baseline：`a58358c3ac90d6edac8a654777beb378d978b688`（含 PR #90／#91）；最近固定桌面 artifact / Last fixed desktop artifact：`57aefc4933db88968777b11ea1d1679c6374842a`（只作历史 Main 局部反馈来源，不可用于下一轮 B01）。

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
| PR #69 | 首次采蜜距离、持续按住、`蜜囊 +1` 成功证据与老师傅演示 | 形成历史 artifact `4b57d856`；自动回归通过，但旧 A 包不能替代后续候选复测 |
| PR #70（不合并） | D 秋 Boss 与 G 秋探索的定向减层／缩滑音 A/B 候选 | Alan 两组均选 `tie`、“都不好”和 `neither`；创作者门禁失败，秋季双轨转入结构性新方向 |
| Draft PR #74（不合并） | 四条 15–20 秒秋季结构方向草图与匿名选择工具 | Alan 选择探索 K，并认为 Boss T/Z 两条都可继续；只允许制作全长候选，不是正式音频替换通过 |
| PR #76 | 16 小节秋季探索／Boss 正式候选、确定性生成与最终等响度 A/B | Alan 在探索、Boss 两组均盲选正式候选；合并提交 `de78f2c` 的双端 artifact 现为历史包，实机混音仍待后续 |
| PR #79 | Boss 失败／暂停 HUD 上下文、循环终点机制清理与脚本错误门禁 | 合并提交 `21a44bd` 曾重建双端 artifact，后因误带测试资源降为历史包；修复事实仍成立，不是玩家通过 |
| PR #81 | 成长／分配弹层键盘焦点、单次确认和切出／恢复暂停语义 | 自动 GUI 与通知回归通过，真实窗口和玩家操作仍待人工验证 |
| PR #82 | 三 preset 排除内部测试／工具资源，并检查最终 macOS ZIP 与 Windows EXE | 合并提交 `29e719f` 曾重建并复验双端 artifact；PR #87 合并后已降为历史候选 |
| PR #85 | 固定切片 strict ticket／bootstrap、artifact manifest／catalog 身份链与存档 namespace 隔离基础 | 解除 B 包身份依赖；未单独宣布玩法切片已就绪 |
| PR #87 | B01 独立 typed scene、主流程／切片共享急转运行时、编译期 registry、产品 `ready` catalog 与证据门禁 | 合并提交 `57aefc4` 形成历史固定 artifact；旧会话无有效 B01 结果 |
| PR #90／#91 | 错放 ticket fail-closed、启动器自动分隔、精确 ready receipt；修订六字段短表 | 已进入当前源码 `a58358c` 并通过自动验证；待新 artifact、全新 session 与真人结果 |

## 2. 当前阶段结论 / Current Stage Conclusion

| 证据层 / Evidence layer | 状态 / Status | 结论 / Conclusion |
| --- | --- | --- |
| 实现 / Implementation | 已完成当前批次 | PR #87 形成历史 B01 artifact；PR #90／#91 已把启动防护、ready receipt 与短表修订加入当前源码 |
| 开发者自测 / Developer verification | 自动验证通过；新构建与 B01 人工执行未完成 | 旧 `57aefc4` 双端 artifact 曾复验；PR #90／#91 的 Godot／Node 回归通过。下一步仍需最新 main 新 artifact、全新 session 与真实 ready receipt |
| Alan 方向门禁 / Direction gate | 玩法整改与旧 HUD 方向曾通过；当前美术重开 | 2026-08-26 直接反馈否决当前实机美术达到宣传／发售水准，并要求从写实转手绘改为角色化、游戏化的统一造型语言 |
| Alan 完整人工流程 / Full manual pass | 部分记录、未通过 | 旧 `f57ea02c` 首份 A 包在首分钟采蜜反馈处卡住且后半问卷疲劳；`57aefc4` 经证据链判定进入 Main 的局部自测已归档，参与者自报 `time_limit`、实际时长不可得，且未到首个 Boss。B01 第一次交接失败、第二次进入 Main，尚无有效 B01 运行结果，不得宣称人工完成或已学会。秋季双轨全长最终 A/B 已在两组均选择正式候选；总体配对、长期耐循环、实机混音与完整玩法流程仍缺失 |
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

1. 从最新 clean main 重建新 artifact，创建独立 Main/A 与 B01 全新会话后，复测首分钟采蜜并不经口头提示完成首节点；
2. 急转真实完成 `1/2 → 2/2`；
3. 用自己的话说明寻迹、惊退与急转的事实、操作和成功证据；B01 通过精确 ready receipt 后再完整运行无提示实践、180 秒 active 路线和单次无字复测，并保存 participant／observer；
4. 不看说明分辨花药、柱头、蜂身散粉和结籽，并复述授粉因果；
5. 体验夏季袭扰、秋季留种、冬季暖点并描述实际改过的路线或选择；
6. 分别复述四位 Boss 的暴露规则；
7. 记录各节点／Boss 用时、失败点和无决策重复时长；
8. D/G 修改前后 A/B 已失败；Draft PR #74 已选择方向，PR #76 全长最终 A/B 又在探索与 Boss 两组均选择正式候选。下一步只补同季配对、总体区分度、长期耐循环和实机混音；其余六轨不因本次证据重写。

### 3.3 发布人工流程 / Release Manual Pass

- Windows x86_64 真机完成启动、DPI／全屏、中文字体、声音、设置持久化与退出；
- macOS 固定候选完成一整轮和设置重启；
- 验证标题／暂停层显示新 artifact manifest 对应的实际提交短号，版本一致且不含 `+dirty`；
- 1280×720 是 HUD 参考画布；1920×1080、1440×900 与 1024×768 的等比安全框已自动验证，但任意宽高比世界重排和手机正式适配未承诺；
- 饮蜜已有按条件显示的鼠标／显式触摸入口；仍须在真实原生触屏设备上验证手感、取消和系统缩放。

### 3.4 外部玩家 / Independent Playtests

当前样本为 0。会话 `NB-20260825-D9EFAA79` 虽自报外部玩家，但填写者与开发关系尚未由协调者确认，确认前不计样本。首轮记录：

- 首次移动、采蜜、交蜜时间与所有口头求助；
- 急转两次及玩家对因果的自由复述；再用 B01 记录无提示实践和延迟复测结果；self-test 启动不能代替 Alan 或外部玩家结果；
- 授粉因果与四组季节行为的玩家原话；
- 各节点／Boss 用时、失败原因、退出点、主动撤离和重开；
- 8 轨配对、情绪、不舒服音色与循环疲劳；
- 不把开发者解释改写成玩家证据。

## 4. 当前验收标准 / Current Acceptance Criteria

### 自动与构建 / Automated and Build

- Godot 4.6.2 的 14 组测试均显式报告 `TEST PASSED`；
- Web build/test/lint 通过；
- 24 节点数据、资源预算、完成条件、四组机制、四位 Boss、8 轨路由和构建来源受门禁覆盖；
- run `32867365895` 的 macOS universal／Windows x86_64 artifact 已对 sidecar SHA-256 与最终 pack verifier 复验通过，包内同时存在 bootstrap、Main、精确 `ready` B01 catalog 和编译注册 scene，且不含 `res://tests/` 或 `res://tools/`。

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
| 需要验证约 3 分钟后的急转保持（切片已实现） | 先用 B01 采集 Alan 和外部玩家结果；再由结果决定是否让普通敌害复用锁线语法 | 无提示实践首次成功后，恰好 180 秒 active 路线再进行一次无字同配置复测；保存 result JSON |
| 四组仍被概括为“都是采蜜” | 四季路线深化 | 每组至少观察到一次不同路线、顺序、撤离或资源选择 |
| 节点仍短或只是机械重复 | 节奏与 Boss 调律 | 依据用时、失败原因和重复劳动改内容，不只抬目标 |
| 视觉仍不协调 | 单代表场景画风切片 | 先通过一张实机场景，再批量生产 |
| PR #70 与主线基线均被否决，Draft PR #74 已选出 K 与 T/Z（已完成） | PR #76 秋季两轨全长候选 | 不续接被否决候选；最终组内响度精确一致，探索与 Boss 均选正式 candidate；该条件任务关闭，实机混音另测 |
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
