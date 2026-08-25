# 无名：成蜂 · Nameless: Becoming

一款以蜜蜂生态、二十四节气循环与归巢风险为核心的轻量动作撤离原型。

> 再采一朵，还是现在归巢？

## 在线试玩

[https://hivebound-seasons.alanthssss.chatgpt.site](https://hivebound-seasons.alanthssss.chatgpt.site)

当前 Web 地址是需要获授权 ChatGPT 账号访问的所有者私有入口；旧 Cloudflare Pages 地址不再作为当前基线。下文 `4b57d856` 固定人工验收候选只指已校验的 macOS／Windows 桌面 artifact；现有 Web 部署尚未证明来自该精确提交，在重新部署并核对来源前不得用它采集 `4b57d856` 候选证据。

## 当前版本：Godot 候选 MVP 0.9.5-rc.2

当前可玩实现与固定人工验收候选来自完整提交 `4b57d85607c9811efcfd5fcc83f7c976bdebdb4d`。它包含 PR #63 的玩法／资产、PR #64 的 8 轨盲听工具、PR #65 的 HUD 等比安全框／饮蜜指针入口，以及 PR #69 对首次采蜜距离、按住操作和成功反馈的修复；PR #67 的证据工具与 PR #68 的证据归档不改变游戏二进制。标题／暂停层应显示：

```text
v0.9.5-rc.2 · 4b57d856
```

不应出现 `+dirty`。Alan 已分别允许 PR #63 的玩法整改方向和 PR #65 的 HUD／饮蜜按钮方向进入主线；两者都不是完整玩法、原生触摸、音乐、设备或发行验收。未参与开发的外部玩家证据仍为 **0**。

当前维护 Web、macOS universal、Windows x86_64 三个发行端，均由同一个 `godot/` 工程导出。玩家直接控制蜜蜂在花田中飞行：

- **搜**：寻找花蜜、隐藏花和当组机制目标；
- **驱**：用震翼惊退可惊退敌害；蜂针不是普通攻击；
- **撤**：在体力耗尽前回到左侧唯一主蜂巢，站稳卸蜜后才计入“归巢蜜”；
- **循环**：沿 24 个节气数据节点推进，普通目标 10～15、基础携带上限 8，需要多次归巢；
- **四组行为**：开放花授粉、实体袭扰、野外留种、三暖点路线；
- **失律者**：蚊、油葫芦、画眉、熊分别通过吸取、落地、寻迹真声和闪避撞暖花暴露，再完成 3 次调律；
- **音乐**：春夏秋冬各 1 首探索和 1 首 Boss 变奏，共 8 个独立 WAV。

当前结构不是早期“四个压缩关卡”，也不是已废止的 `4 × 3` 大关方案。首局总时长只记录，不使用 15～25 或 32～42 分钟作为通过条件。

### 操作

| 操作 | 键盘 | 触摸／指针 |
| --- | --- | --- |
| 移动 | WASD / 方向键（持续飞行自动振翅加速） | 点击花田移动 |
| 情境动作 | 空格 / 回车（采蜜、惊退、寻迹或机制交互） | 情境按钮 |
| 投蜜诱饵 | 松开情境键后长按（需携蜜） | 情境按钮 |
| 急转闪避 | 锁线后同方向快速连按两次 | 双击要急转的一侧花田 |
| 饮蜜续力 | E（需携蜜，每节点最多 2 次） | 条件式 HUD 按钮；只在游玩中、携蜜大于 0、体力未满、次数未用尽且当前教学允许时出现；Boss 阶段不提供 |
| 归巢 | Q（自动飞回主巢） | 归巢按钮 |
| 暂停 | Esc | 顶部暂停入口 |

## 当前设计事实

### 完成条件

普通节点从开局常驻显示所有会阻止结算的条件：归巢蜜、当前机制，以及首节点的老师傅要求。最后一项已列条件完成后必须立即结算；未显示的隐藏门禁不得阻止推进。

### 四组季节行为

| 组 | 玩家实际做什么 |
| --- | --- |
| 春／授粉 | 从已开放花药取粉，蜂身出现松散散粉，再送到同一可见花型的开放柱头；柱头结籽，花蜜不变 |
| 夏／袭扰 | 第一次真实卸蜜触发有翅劫掠者；它们移动、偷蜜、持赃，玩家逐只惊退并让花蜜落回花田 |
| 秋／留种 | 最后一滴前自动停采；松手后决定采尽或留种，真实归巢使种核成熟 |
| 冬／暖点 | 寒区降低体温和速度；用携蜜依次点亮 3 个蜂蜡暖点，逐段开放远花路线 |

### 老师傅教学

首节点和三组首次机制采用“示范 → 模仿 → 无提示实践”。示范不改变真实世界；模仿和实践只由真实结果推进。急转必须在锁线后从旧位置附近侧移出真实危险通道，敌害穿过旧位置且蜂在线外才算成功。

## 8 轨音乐盲听

PR #64（`b03811c4`）已实现固定 A–H 匿名顺序、本地填写／JSON 导出页和与听众端分离的开发者答案。在最新 `origin/main` 上执行：

```bash
npm run audio:review
```

默认输出位于 `outputs/music-blind-review/`。给听者的唯一入口是 `listener/index.html`；`reviewer/` 含季节、探索／Boss 角色和正确配对，必须在听者导出结果前与其隔离。工具、WAV 哈希与匿名映射已自动校验；新导出附带候选／工具清单身份，并在整体区和配对全部空白时阻止导出。Alan 已完成固定八轨的逐轨评论：其余六轨当时总体正向；D 秋 Boss 的过满／突兀和 G 秋探索的“猫叫”式滑音触发修改前后 A/B。该 A/B 已完成，但两组均选择 `tie`、“都不好”和 `replacement_readiness: neither`，所以 PR #70 关闭且不合并，当前主线基线也未获认可，秋季两轨需要结构性新方向。该结论不能外推到其余六轨；总体偏好、四组配对、长期耐循环和实机混音仍未完成，因此整套音乐不得标记为通过。完整证据与哈希见 [`docs/PLAYTEST.md`](docs/PLAYTEST.md)。

## 首轮试玩证据包

给陌生玩家的首节点 A 包由本地生成器固定版本、提交号和安装包哈希，并将参与者页面与内部分析模板隔离：

```bash
npm run playtest:prepare -- \
  --task A \
  --tester-relation external_player \
  --candidate-commit <游戏内显示的提交号> \
  --candidate-clean \
  --artifact-sha256 <安装包 SHA-256>
```

默认输出位于 `outputs/playtest-evidence/<随机会话号>/`，每位参与者单独生成一包。只把 `participant/` 文件夹交给玩家；新版 A 表由 29 个控件降为 6 个，只收 4 个短原话和 2 个结束选择。`coordinator/observer.html` 留给测试协调者，隔离记录环境、试玩前游戏外解释、时间线、机制接触，以及急转延迟复测的机会和结果；关系类型由生成命令固定，参与者不能自报。两页均完全离线、不收个人信息。A 包最多 15 分钟；B 单切片包因游戏尚无固定切片入口而明确阻塞，不能用跑前置节点替代；音乐继续独立使用 `npm run audio:review`。生成器会记录传入的 SHA-256，但不会读取安装包，交付者仍须用 sidecar 或哈希工具复验。旧 schema v1 记录不自动升级为新版机制证据。首份 A 包属于旧候选 `f57ea02c`：它暴露首分钟采蜜反馈和问卷过长两个 P0，但不能迁移为当前 `4b57d856` 的通过证据；填写者身份仍待协调者确认，外部玩家样本仍为 0。当前候选必须重新采集首分钟和完整流程证据。完整记录与边界见 [`docs/PLAYTEST.md`](docs/PLAYTEST.md)。

## 视觉方向

视觉以布艺贴花作为清楚、可动画的主体表现，以毛毡微缩控制温暖体积，以蜂蜡、浅色植鞣革和刺绣分别表达生命能量、蜂群设施与信息轨迹；不转为像素风，剪纸仅为已停用的历史候选。

低噪地表、独立蜂巢、8 种季节花和四组机制实体已进入构建。它们是实现事实和开发者快照证据，不等于 Alan 已逐项通过画风，也不等于外部玩家已读懂。完整生产规则见 [`docs/design/ART_IMPLEMENTATION_STANDARD.md`](docs/design/ART_IMPLEMENTATION_STANDARD.md)，当前美术门禁见 [`docs/design/LAUNCH_ART_PRODUCTION_PLAN.md`](docs/design/LAUNCH_ART_PRODUCTION_PLAN.md)。

## 开发

正式单机版需要 Godot 4.6.2 或更高版本：

```bash
godot --path godot --editor
npm run test:godot
```

`npm run test:godot` 会生成构建来源、准备导入缓存并执行 9 组 Godot 回归；第 9 组覆盖 HUD 等比安全框、饮蜜按钮状态与指针／触摸触发边界，每组都必须在独立日志中报告 `TEST PASSED`。

Web 端由 Godot 导出后，通过 Node.js 站点外壳承载：

```bash
npm install
npm run dev
npm run build
npm run test
```

桌面候选包可在 GitHub 的 **Actions → Desktop client builds → Run workflow** 手动生成。`release_tag` 必须与 `package.json` 版本一致；流水线校验 Godot 编辑器与模板、运行测试、导出 macOS／Windows 并附带 SHA-256。默认只生成保留期有限的 artifacts，只有明确选择 `publish_prerelease` 才创建预发布版本。

主要实现位于：

- `godot/scripts/main.gd`：24 节点状态流、敌害、归巢结算和主集成；
- `godot/data/seasons.json`：24 个节气节点、玩法组、敌害、色彩和目标；
- `godot/data/bosses.json`：四位失律者数据；
- `godot/scripts/mechanics/`：授粉、袭扰、留种、暖点与中继巢；
- `godot/scripts/tutorial/mentor_tutorial.gd`：老师傅因果教学；
- `godot/scripts/boss_encounter_director.gd`：四位 Boss 独立暴露状态机；
- `godot/scripts/music_director.gd`：8 轨音乐路由；
- `scripts/prepare_audio_blind_review.mjs`：生成 A–H 匿名盲听包和独立答案；
- `scripts/prepare_playtest_evidence.mjs`：生成首节点匿名试玩证据包和隔离分析模板；单切片入口未实现时会主动拒绝 B 包；
- `godot/scripts/ui/production_hud.gd`：当前状态、完成条件和动作卡；
- `app/page.tsx`：Godot Web 版启动外壳。

## 文档事实源与边界

按用途读取，避免把历史方案误当当前决定：

1. [`docs/PLAYER_FEEDBACK_ACTION_PLAN_2026-08-24.md`](docs/PLAYER_FEEDBACK_ACTION_PLAN_2026-08-24.md)：**当前整改、实现事实、证据等级、执行矩阵和外测标准的主记录**；
2. [`docs/MVP_SPEC.md`](docs/MVP_SPEC.md)：**当前候选范围与验收口径**；
3. [`docs/DESIGN_CONSENSUS.md`](docs/DESIGN_CONSENSUS.md)：**当前稳定设计共识、差距和证据触发任务**；
4. [`docs/RELEASE_CHECKLIST.md`](docs/RELEASE_CHECKLIST.md) 与 [`docs/BUILD_MANIFEST.md`](docs/BUILD_MANIFEST.md)：当前发布门禁与构建事实；
5. [`docs/PLAYTEST.md`](docs/PLAYTEST.md)：人工与外部玩家记录模板／记录；
6. [`docs/PROJECT_LOG.md`](docs/PROJECT_LOG.md)：**历史记录**，有意保留当时成立、后来被推翻的四关、旧 Boss、旧四季和旧时长描述；
7. [`docs/DEMO_TO_PLAYTEST_PLAN.md`](docs/DEMO_TO_PLAYTEST_PLAN.md)：**已废止的历史结构方案**，仅用于追溯，不得执行；
8. [`docs/COLOR_SYSTEM.md`](docs/COLOR_SYSTEM.md)：二十四节气色彩语言；
9. [`docs/COLLABORATION_PROTOCOL.md`](docs/COLLABORATION_PROTOCOL.md)：Alan 与 Codex 的职责边界；
10. [`docs/STEAM_NEXT_FEST_2026_PLAN.md`](docs/STEAM_NEXT_FEST_2026_PLAN.md)：Steam 新品节报名与运营事项；
11. [`docs/GAME_MATURITY_AND_PRODUCTION_ASSESSMENT.md`](docs/GAME_MATURITY_AND_PRODUCTION_ASSESSMENT.md)：成熟度与市场评估，其中历史结构判断须服从上述当前事实源；
12. [`docs/design/ART_IMPLEMENTATION_STANDARD.md`](docs/design/ART_IMPLEMENTATION_STANDARD.md)：美术生产规范；
13. [`docs/design/LAUNCH_ART_PRODUCTION_PLAN.md`](docs/design/LAUNCH_ART_PRODUCTION_PLAN.md)：当前上线美术证据与生产门禁。

## 当前验证问题

1. 陌生玩家能否不经口头提示完成首趟，并分别独立完成寻迹、惊退和急转？当前正常路线在老师傅连续两次急转练习后没有稳定的约 3 分钟同语法复测机会；未遇到不能记成失败，如需判断迁移应先提供固定复测切片。
2. 玩家能否从开放花器官和蜂身散粉读懂授粉，而不是理解为“碰花开花／产蜜”？
3. 四组行为是否真实改变路线、顺序、撤离或资源选择？
4. 四位 Boss 的失败原因能否分别复述？
5. 8 轨能否盲听配对并在循环中保持舒适？
6. 各节点／Boss 的实际时长中，有多少是有判断的行动，多少是无决策重复？

当前仍是封闭验证候选。自动化、构建哈希和 Alan 方向门禁都不能替代完整人工流程与外部玩家证据。
