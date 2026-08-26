# 无名：成蜂 · Nameless: Becoming

一款以蜜蜂生态、二十四节气循环与归巢风险为核心的轻量动作撤离原型。

> 再采一朵，还是现在归巢？

## 在线试玩

[https://hivebound-seasons.alanthssss.chatgpt.site](https://hivebound-seasons.alanthssss.chatgpt.site)

当前 Web 地址是需要获授权 ChatGPT 账号访问的所有者私有入口；旧 Cloudflare Pages 地址不再作为当前基线。当前源码基线为 `fc5e3d590ef32bf86b4a083860874198568a5c6a`（已含 PR #90／#91／#92／#94／#95）。下文 `57aefc4` 只指最近一次已校验的 macOS／Windows 桌面 artifact；它现在是历史 Main 局部反馈来源，不含新的启动回执门禁或 PR #94 可恢复载粉实现，现有 Web 部署也未证明与任何当前候选精确同源。

## 当前版本：Godot 候选 MVP 0.9.5-rc.2

最近已校验的桌面 artifact 来自 PR #87 的完整 `main` 提交 `57aefc4933db88968777b11ea1d1679c6374842a`。macOS／Windows 包由 GitHub run [`32867365895`](https://github.com/alanthssss/nameless-becoming/actions/runs/32867365895) 构建并通过最终包检查；但该包早于 PR #90 的启动 fail-closed／ready receipt 与 PR #91 的短表修订，不能继续作为下一轮 B01 入口。它只保留历史证据价值，标题／暂停层显示：

```text
v0.9.5-rc.2 · 57aefc49
```

不应出现 `+dirty`。标准包没有秋季直达入口，秋季双轨仍须在完整流程中验证音效遮蔽、循环疲劳和实机混音；Windows 真机也尚未完成。Alan 已分别允许 PR #63 的玩法整改方向、PR #65 的 HUD／饮蜜按钮方向和 PR #76 的秋季双轨替换进入主线，但这些都不是完整玩法、原生触摸、整套音乐、设备或发行验收。未参与开发的外部玩家证据仍为 **0**。

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

默认输出位于 `outputs/music-blind-review/`。给听者的唯一入口是 `listener/index.html`；`reviewer/` 含季节、探索／Boss 角色和正确配对，必须在听者导出结果前与其隔离。工具、WAV 哈希与匿名映射已自动校验。Alan 的逐轨评论曾触发 PR #70 D/G 定向 A/B；两组均为 `tie`、“都不好”和 `neither`，因此该 PR 已关闭且不合并。Draft PR #74 随后选出探索 K 与 Boss T/Z 方向；PR #76 将其发展为全长候选，并以组内相同响度再次匿名比较。Alan 在探索组选择 Y、Boss 组选择 M，揭盲后两者均为正式候选，因此秋季双轨创作者替换门禁通过。其余六轨不因本轮重写；四组配对、长期耐循环和实机混音仍未完成，不能把整套音乐标记为全面通过。完整证据与哈希见 [`docs/PLAYTEST.md`](docs/PLAYTEST.md)。

如需重建这次答案隔离、组内等响度的秋季最终 A/B，使用仓库外绝对输出路径；命令需要完整 Git 历史和 FFmpeg：

```bash
npm run audio:autumn-final-ab -- --output /absolute/path/outside/repository
```

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

默认输出位于 `outputs/playtest-evidence/<随机会话号>/`，每位参与者单独生成一包。只把 `participant/` 文件夹交给玩家；A／B 使用同一版 6 字段短表，只收 4 个短原话和 2 个结束选择。`coordinator/observer.html` 留给测试协调者，隔离记录环境、试玩前游戏外解释、时间线、机制接触，以及急转延迟复测的机会和结果。B01 仍执行“2.8 秒老师傅因果示范 → 有界引导模仿 → 无提示实践 → 180 秒 active 花间路线 → 一次无字同配置复测”。旧会话 `NB-20260825-6412D7BA` 已关闭：第一次为交接失败；第二次在 `57aefc4` 旧构建中因启动命令遗漏 user-argument 分隔符而进入 `Main`，同会话 JSON 只归档为 Alan Main 局部自测。PR #90 已在当前主线加入错放 ticket fail-closed、启动器自动分隔与精确 ready receipt；PR #91 已修订歧义问题。下一轮必须从最新 clean `main` 重建 artifact、创建全新 session／ticket，并由 `npm run playtest:launch` 取得精确回执后才交给玩家。音乐继续独立使用 `npm run audio:review`；外部玩家样本仍为 0。完整记录、JSON SHA-256 与边界见 [`docs/PLAYTEST.md`](docs/PLAYTEST.md)。

## 视觉方向

截至 2026-08-26，**没有通过的当前画风候选**。“布艺贴花主体 + 毛毡微缩体积”、v3“矿物色套色版绘 × 局部蜂蜡”、v4 明亮生态动画和 v5 世界总览／主海报都只保留为历史实验或否决证据。Alan 对最新地图与海报的直接结论是：两者画风不统一，一个过亮、一个过暗，颜色脏，像“照片转手绘转了一半”，没有感情色彩；无效细节过多、重点和艺术抽象不足，尚不像游戏艺术成品。海报蜂尾滴蜜还造成排泄联想；该表达与花蜜经口器进入蜜囊、再经口器交接的生态关系不符，列为一票否决错误。

旧“地主蚊子”“油葫芦容器怪”“三弦鸟精”等拟人设定曾被开发侧／AI 过滤成通用生态动作，这不是 Alan 批准的删改。现在先恢复并确认各角色的“必须继承／可以转译／明确废止”，再做黑白剪影、三档明度和统一有限色主样帧；主样帧在真实游戏尺寸与运动中通过前，不继续制作群像海报。角色事实与缺源项见 [`docs/design/character-visual-canon.md`](docs/design/character-visual-canon.md)，表现门禁见 [`docs/design/ART_IMPLEMENTATION_STANDARD.md`](docs/design/ART_IMPLEMENTATION_STANDARD.md)。

低噪地表、独立蜂巢、8 种季节花和四组机制实体已进入构建。它们是实现事实和开发者快照证据，不等于 Alan 已逐项通过画风，也不等于外部玩家已读懂。完整生产规则见 [`docs/design/ART_IMPLEMENTATION_STANDARD.md`](docs/design/ART_IMPLEMENTATION_STANDARD.md)，当前美术门禁见 [`docs/design/LAUNCH_ART_PRODUCTION_PLAN.md`](docs/design/LAUNCH_ART_PRODUCTION_PLAN.md)。

未来产品方向已决定扩大地图与游玩时间，并让蜂巢承担类似篝火的安全、休整、方向与情绪锚点；“篝火”不自动包含存档、复活、传送、刷怪或商店。`1` 个连续家园、`5` 张可加载地图、`13` 个主场景、`1 主 + 4 次`蜂巢节点和 `18` 种花卉身份，均是开发侧为讨论与灰盒提出的**规模建议，待 Alan 确认**；不是已经定案的产品数量。当前代码仍是固定单屏、唯一主巢交付与有限中继巢；四季与 24 节气数据层则是现有推进骨架。地图／蜂巢结构见 [`docs/design/map-evolution.md`](docs/design/map-evolution.md)，生态与规模提案见 [`docs/design/world-season-ecology-framework.md`](docs/design/world-season-ecology-framework.md)，一页式审阅入口见 [`docs/design/visual-atlas.md`](docs/design/visual-atlas.md)。

## 开发

正式单机版需要 Godot 4.6.2 或更高版本：

```bash
godot --path godot --editor
npm run test:godot
```

`npm run test:godot` 会生成构建来源、准备导入缓存并执行 14 组 Godot 回归；其中 strict ticket validator、bootstrap 与 ticket-derived save namespace 覆盖固定切片身份基础，新增的共享急转运行时与 B01 组覆盖生产／切片同一因果规则、有界阶段、180 秒 active 时钟、单次复测和互斥结果；HUD 组继续覆盖等比安全框、饮蜜按钮状态与指针／触摸触发边界。每组都必须在独立日志中报告 `TEST PASSED`。自动回归只证明实现时序与判定成立，不证明玩家已学会急转。

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
- `godot/bootstrap.tscn`、`godot/scripts/playtest/` 与 `godot/data/playtest_slices.json`：普通启动兼容的导出入口、固定切片 strict identity gate、编译期 registry、生产 `ready` catalog 与 B01 独立 typed scene；
- `scripts/prepare_audio_blind_review.mjs`：生成 A–H 匿名盲听包和独立答案；
- `scripts/prepare_playtest_evidence.mjs`：生成首节点匿名试玩证据包和隔离分析模板；B 流程只能从 actual artifact、manifest 和精确提交 catalog 推导 ticket，每次有效运行必须使用全新 session；
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
13. [`docs/design/LAUNCH_ART_PRODUCTION_PLAN.md`](docs/design/LAUNCH_ART_PRODUCTION_PLAN.md)：当前上线美术证据与生产门禁；
14. [`docs/design/map-evolution.md`](docs/design/map-evolution.md)：未来长地图、蜂巢承担类似篝火作用的方向、未决机制和结构门禁；
15. [`docs/design/world-season-ecology-framework.md`](docs/design/world-season-ecology-framework.md)：地图／场景规模建议、四季、节气、花期、机制泛化与角色 IP 框架；
16. [`docs/design/visual-atlas.md`](docs/design/visual-atlas.md)：实机、历史概念与已否决世界地图／海报的一页式审阅入口；
17. [`docs/design/character-visual-canon.md`](docs/design/character-visual-canon.md)：主角、蜂群与四位失律者的既有设定、缺源项、生态禁错和出图前继承门禁。

## 当前验证问题

1. 陌生玩家能否不经口头提示完成首趟，并分别独立完成寻迹、惊退和急转？B01 已在源码中构造 180 秒 active 花间路线后的一次同配置无字机会，但下一轮仍待从最新 clean main 重建 artifact、创建全新 session 并取得真实 ready receipt；未遇到不能记成失败，自动测试也不能记成学会。
2. 玩家能否从开放花器官和蜂身散粉读懂授粉，而不是理解为“碰花开花／产蜜”？
3. 四组行为是否真实改变路线、顺序、撤离或资源选择？
4. 四位 Boss 的失败原因能否分别复述？
5. 8 轨能否盲听配对并在循环中保持舒适？
6. 各节点／Boss 的实际时长中，有多少是有判断的行动，多少是无决策重复？

当前仍是封闭验证候选。自动化、构建哈希和 Alan 方向门禁都不能替代完整人工流程与外部玩家证据。
