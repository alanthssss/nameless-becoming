# 02 · 技术架构 / Technical Architecture

> Godot 4.6.2 单机核心 + React/Vite Web 承载外壳 + JSON 数据驱动 + 三端同源导出
> Godot 4.6.2 standalone core + React/Vite web shell + JSON-driven data + one source for three targets

当前源码基线 / Current source baseline：`a58358c3ac90d6edac8a654777beb378d978b688`（含 PR #90／#91）；最近固定桌面 artifact / Last fixed desktop artifact：`57aefc4933db88968777b11ea1d1679c6374842a`（只作历史 Main 局部反馈来源，不含新的启动回执门禁）。

---

## 1. 总体架构 / Overall Architecture

```text
Godot 4.6.2 游戏核心
├─ bootstrap.gd：普通启动进 Main；固定 session 先过 strict ticket／artifact identity gate
├─ main.gd：24 节点推进、输入、敌害、UI 与系统集成
├─ evade_rules.gd + evade_input_controller.gd：主流程与 B01 共享急转因果／键鼠触输入规则
├─ mentor_tutorial.gd：示范 → 模仿 → 无提示实践
├─ playtest/：B01 typed scene、encounter、编译期 registry 与 ticket validator
├─ season_mechanics.gd
│  ├─ pollination_mechanic.gd：开放花器官与结籽
│  ├─ conscription_mechanic.gd：实体袭扰与花蜜追回
│  ├─ reserve_mechanic.gd：野外留种与跨季分配
│  └─ huddle_mechanic.gd：寒冷、暖点与路线开放
├─ boss_encounter_director.gd：四位 Boss 独立暴露状态机
├─ music_director.gd：4 探索 + 4 Boss 音乐路由
├─ relay_hive_mechanic.gd：立夏中继巢切片
└─ production_hud.gd：当前状态、完成条件、动作卡、等比安全框与饮蜜指针入口
        │
        ├─ godot/data/*.json：节气、Boss、花、成长与平衡数据
        └─ godot/assets/：8 轨音乐、季节花、背景与 UI 资源

Godot Web 导出
        ↓
React 19 / Vite / RSC 承载外壳
        ↓
Web · macOS universal · Windows x86_64
```

## 2. 核心文件 / Core Files

| 文件 / File | 当前职责 / Current responsibility |
| --- | --- |
| `godot/scripts/bootstrap.gd` | 普通启动不带 ticket 时进入原 `main.tscn`；固定 session 只在产品、平台、clean commit、artifact／manifest／catalog 哈希与 registry 全部一致时实例化 typed scene |
| `godot/scripts/main.gd` | 24 节点状态流、归巢结算、普通敌害、四位 Boss 的场景集成、输入与主 UI |
| `godot/scripts/player/bee_player.gd` | 飞行、自动振翅、体力、急转位移与环境速度倍率 |
| `godot/scripts/mechanics/evade_rules.gd` / `godot/scripts/player/evade_input_controller.gd` | 集中定义锁线、侧移、通道判定以及键盘／鼠标／触摸急转输入；主流程与 B01 不再维护两套规则 |
| `godot/scripts/tutorial/mentor_tutorial.gd` | 首节点及季节首次机制的示范／模仿／实践状态机 |
| `godot/scripts/playtest/b01_evade_slice.gd` / `b01_evade_encounter.gd` | 独立 B01 固定切片：2.8 秒示范、有界引导／实践、条件性 180 秒 active 花间路线、一次无字复测与三个互斥结果；不读写存档 |
| `godot/scripts/playtest/playtest_ticket_validator.gd` / `playtest_slice_registry.gd` | 校验 strict ticket／schema v1 artifact manifest／包内 provenance／精确 commit／catalog，并只从编译注册表解析 `ready` typed scene |
| `godot/scripts/mechanics/season_mechanics.gd` | 按节点 `mechanics` 列表启停子系统并转发采蜜、归巢、动作与完成钩子 |
| `godot/scripts/mechanics/pollination_mechanic.gd` | 开放花药取粉、同可见花型兼容、蜂身散粉、柱头结籽；不修改花蜜 |
| `godot/scripts/mechanics/conscription_mechanic.gd` | 首次真实卸蜜后生成实体袭扰者；移动、偷蜜、持赃、惊退与返蜜 |
| `godot/scripts/mechanics/reserve_mechanic.gd` | 最后一滴前暂停、松手确认、留种成熟／采尽后果，以及段末跨季分配 |
| `godot/scripts/mechanics/huddle_mechanic.gd` | 体温、环境减速、3 个顺序暖点与远花路线开放 |
| `godot/scripts/mechanics/relay_hive_mechanic.gd` | 立夏单个中继巢：消耗携蜜激活，只恢复至 65%，不交付或结算 |
| `godot/scripts/boss_encounter_director.gd` | 蚊／油葫芦／画眉／熊的暴露条件、3 阶段参数与窗口收束 |
| `godot/scripts/music_director.gd` | 探索、归巢柔化、Boss 变奏与调律进度映射 |
| `godot/scripts/sound_feedback.gd` | 高频动作提示音；旧单一程序化背景循环已移除 |
| `godot/scripts/ui/production_hud.gd` | 1280×720 参考画布、等比安全框、常驻完成条件、情境动作、教学文案与按条件显示的饮蜜指针入口 |
| `godot/scripts/save_manager.gd` | 本地 `ConfigFile` 保存声音开关、全屏状态、最远节点、开始／完成次数和上次运行秒数；不保存教程或局中状态，也没有连续音量值 |
| `app/page.tsx` | Godot Web 导出的 React 承载入口 |
| `scripts/prepare_audio_blind_review.mjs` | 从 8 个固定 WAV 生成 A–H 匿名听众包和隔离的开发者答案 |

## 3. 数据层 / Data Layer

| 文件 / File | 当前内容 / Current contents |
| --- | --- |
| `godot/data/seasons.json` | 24 个节点；目标、花量、普通敌害、色彩、`flower_set`、`mechanics`、显式 Boss 与立夏中继巢配置 |
| `godot/data/bosses.json` | 四位失律者的身份、节点、移动模式、伤害、调律半径与演出文案 |
| `godot/data/balance.json` | 玩家、普通敌害、Boss 公共参数和四组机制参数 |
| `godot/data/flowers.json` | 花蜜基础量、权重与花型行为数据 |
| `godot/data/upgrades.json` | 长翼、采蜜、守卫三类成长 |
| `godot/data/playtest_slices.json` | schema v1 固定切片 catalog；当前只有 `B01 / 10 / ready`，scene 与 handler 仍只由编译期 registry 绑定 |

数据优先支持可调参数；部分状态机与表现常量仍位于脚本中，因此不能再写成“所有数值零硬编码”。代码与文档冲突时，以当前代码／数据为实现事实，并在同一任务修正文档。

## 4. 当前状态流 / Current State Flow

```text
intro
→ playing（普通节点；所有完成条件常驻）
→ between（交付、留种成熟、跨季分配、成长）
→ boss（显式正色节点或循环终点熊）
→ boss_victory
→ 下一节点 / won
```

- `seasons.json` 有 24 个条目；春分、夏至、秋分条目含 `boss`，大雪后由 `advance_stage()` 进入默认熊遭遇；
- 普通节点只有“归巢蜜 + 当前机制 + 当前教学”全部完成才可结算，且条件必须从开局可见；
- 四组机制由 `flower_set` 和 `mechanics` 路由，不应只用 `season` 文本字段推断当前玩法或资产。

## 5. 自动测试 / Automated Tests

`npm run test:godot` 生成构建来源、准备导入缓存，然后顺序执行 14 组测试；每组除了进程退出码，还必须在独立日志中输出 `TEST PASSED`。

| 测试 / Test | 当前覆盖 / Current coverage |
| --- | --- |
| `smoke_test.gd` | 数据结构、场景、字体、输入、核心公式与资源引用 |
| `playtest_ticket_validator_test.gd` | ticket／artifact manifest／provenance／catalog 的精确身份交叉核对与 fail-closed 边界 |
| `playtest_bootstrap_test.gd` | 无 ticket 保持原 Main，有效 B01 才实例化 typed scene，无效身份不进游戏 |
| `playtest_save_isolation_test.gd` | 通用固定 session 命名空间与普通存档隔离；B01 本身不走存档 |
| `evade_runtime_test.gd` | 主流程／B01 共享锁线、侧移、通道和键鼠触输入规则 |
| `b01_evade_slice_test.gd` | 2.8 秒示范、有界阶段、恰好 180 秒 active 边界、单次复测、反馈和三个互斥结果 |
| `flow_test.gd` | 24 节点状态流、完成条件、资源预算、急转因果、构建来源与产品壳 |
| `fix_boss_term_test.gd` | 正色节点与循环终点 Boss 上下文 |
| `music_test.gd` | 8 轨资源格式、确定性、循环与探索／Boss／归巢路由 |
| `boss_encounter_director_test.gd` | 四位 Boss 独立暴露条件、窗口与阶段参数 |
| `season_mechanics_test.gd` | 授粉、实体袭扰、留种和暖点的成功／失败／资源分支 |
| `relay_hive_test.gd` | 中继巢激活、65% 恢复上限与非交付边界 |
| `mentor_tutorial_test.gd` | 示范／模仿／实践，真实急转 `1/2 → 2/2` 与恢复重演 |
| `hud_responsive_test.gd` | 等比安全框、饮蜜按钮指针路由，以及标题、成长、全满继续和分配弹层的真实键盘焦点／单次确认边界 |

`art_snapshot.gd` 用于生成开发者视觉快照，不属于上述 14 组发布回归，也不能替代真人动态复核。

PR #64（`b03811c4`）另增 Node 级音频盲听工具测试，覆盖 WAV 哈希、固定匿名映射、答案隔离、单轨播放和安全输出。PR #87 又增加 B 包 actual artifact／manifest／catalog 推导、strict CLI 和 participant 递归泄漏扫描。它们进入 `npm test`，但不计入上述 14 组 Godot 回归，也不能代替 Alan 的主观盲听或 B01 人工结果。

## 6. Web 与三端构建 / Web and Three-Target Builds

- Web 不是第二套玩法代码，而是同一 Godot Web 导出的承载外壳；
- Web WASM 通过传输分片部署，浏览器加载时重组；
- macOS universal 与 Windows x86_64 由手动桌面流水线在独立 runner 构建；
- 流水线校验 Godot 4.6.2 编辑器／模板，运行 14 组回归，导出后附带 SHA-256；
- 历史 `57aefc4` 双端 artifact 由 [run 32867365895](https://github.com/alanthssss/nameless-becoming/actions/runs/32867365895) 构建并复验；完整记录见 [`../BUILD_MANIFEST.md`](../BUILD_MANIFEST.md)；
- 旧 B01 会话第一次交接失败，第二次在 `57aefc4` 旧 bootstrap 中误入 `Main`，现已关闭；PR #90 后的有效运行必须使用新 artifact、全新 session／ticket 与精确 ready receipt；
- macOS 使用 ad-hoc 签名只适合内部候选，公开发行仍需 Developer ID 签名和公证；
- Windows artifact 的格式与哈希已验证，但真实 Windows 设备流程尚未完成。

## 7. 构建来源 / Build Provenance

`scripts/generate_build_provenance.mjs` 从 `package.json` 和当前 Git 状态生成不入库的 `godot/data/build_provenance.json`。标题与暂停层显示：

```text
v0.9.5-rc.2 · <8 位提交号>[+dirty]
```

历史 `57aefc4` 包显示 `v0.9.5-rc.2 · 57aefc49`，不带 `+dirty`；它与更早候选都不再表示当前源码。下一固定候选必须从最新 clean main 生成并显示其实际提交号；旧候选人工证据不能迁移为新候选通过。

## 8. 当前技术边界 / Current Technical Boundaries

- `main.gd` 仍承担大量集成，多个核心分支不得并行覆盖同一区域；
- HUD 以 1280×720 为参考画布，已对 1920×1080、1440×900 与 1024×768 使用等比安全框；这不是任意宽高比的世界重排或手机正式适配；
- 饮蜜已有按条件显示的鼠标／显式触摸入口；自动输入事件通过不等于真实原生触屏设备已经验收；
- 自动化和 artifact 验证不能证明 Windows 真机、教学理解、节奏、审美或音乐品质；
- Alan 已批准方向门禁，不是完整人工验收；外部玩家证据仍为 0。
