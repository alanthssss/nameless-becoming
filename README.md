# 一会儿巢里见 · See You at the Hive

一款以蜜蜂生态、四季邻里劳动、二十四节气与真实归巢交接为核心的单机 2D 动作冒险，目前处于**商业游戏制作中**，不是可售卖成品。

> 花田有事，搭把翅膀。飞一圈，巢里见。

## 当前产品：四季 Journey

- `[实现事实]` 普通启动进入独立商业标题。新旅程以简短梦卡说明玩家是第一次独立出门的新蜂，随后依次游玩春季首趟、蚊庄主花牌事故、夏季油葫芦修巢、秋季逐花收／留与画眉邻居的听声种壳、冬季大熊搬木与续暖，最后给下一只新蜂做真实示范并回到主巢。
- `[实现事实]` 春、夏、秋、冬都有大于 1280 × 720 视口的独立大地图与 Camera2D；巢门、花牌、四季区域和结局是独立 `PackedScene`。返巢后的花牌、小蜂房、种头和挡风墙进入跨章世界痕迹与主巢检查点。
- `[实现事实]` 当前可玩行为不只采蜜，还包括同形授粉、观察提示、真实急转、路线避风、有限休息、拾取、修理、逐花留种、听声并转正种壳、续暖、搬木、协作、接货和归巢。主巢提供 24 节气纪事回看，标题／暂停提供版本化单存档、继续／重开、音量／静音、全屏、UI 缩放、减少动态／震动、操作提示、制作人员与许可入口；键盘、指针、触屏与基础手柄输入已接入当前 Journey。
- `[实现事实]` 当前 Godot 项目、Web 的 title／description、npm 包、macOS Bundle ID／signature、桌面导出配置和 CI artifact 命名规则已统一为《一会儿巢里见》／`SeeYouAtTheHive`；当前工作树尚无可称为 clean 候选的桌面 artifact。旧仓库名、旧存档和退役 B01 协议中的 `nameless` 只作为内部兼容标识保留，不进入正常玩家界面或商业资源实体。
- `[开发者自测]` 2026-08-27 最新共享工作树通过 `npm run test:godot` 的 19 组回归，覆盖普通启动、四季到结局、场景路由、资源守恒、节气、存档／设置、暂停／失焦、基础手柄映射、8 轨音乐、14 条动作音效与 2 条环境循环。它不是 clean 候选包、真人试玩或发行 QA。
- `[开发者自测]` macOS、Windows 与 Web 三个临时资源包已通过精确内容闭包；本地 Web release 已从隔离商业缓存重建并再次核验，PR 质量门禁会从 clean 提交重导 Web 游戏、构建站点并保存同源 artifact。6 张 Journey 开发者截图和 8 个商店尺寸候选也通过自动核验；这些结果仍不等于三平台真实设备 QA 或已批准发行物料。
- `[专家启发式]` 蜂巢第二层生活仍薄，部分事件依赖目标文字和程序化图形；完整角色动画、手柄重映射／断开重连、完整无障碍矩阵、音频终混、平台性能、许可总表和正式商店物料仍未过关。
- `[需 Alan 确认]` 当前名称／宣传语、四季剧情语气、17 张运行中的 ImageGen 候选美术、程序化 UI、整套音乐及商业音效／环境声候选都没有新的全流程最终批准。`[需独立玩家验证]` 有效样本仍为 **0**，不能声称玩家已理解、喜欢或愿意购买。

唯一商业成品清单见 [`docs/design/commercial-product-requirements.md`](docs/design/commercial-product-requirements.md)；17 张运行候选 PNG 的逐文件来源、用途、切片、授权缺口与审批状态见 [`docs/design/art-source-register.md`](docs/design/art-source-register.md)。被否决的旧角色图已从仓库和导出物移除，不作为“退役素材”继续保留。

## 历史私有部署（非当前产品试玩）

[https://hivebound-seasons.alanthssss.chatgpt.site](https://hivebound-seasons.alanthssss.chatgpt.site)

该地址是需要获授权 ChatGPT 账号访问的旧项目私有部署，只保留历史查验用途，**不是《一会儿巢里见》的当前在线试玩**。`a58358c3ac90d6edac8a654777beb378d978b688` 只是上一轮 B01 工具记录的历史源码身份，下文 `57aefc4` 也只指最近一次已校验的 macOS／Windows 历史 artifact；不能据此声称线上内容与当前四季 Journey 或下一份候选包同源。

## 旧 24 节点候选基线：Godot MVP 0.9.5-rc.2

以下内容记录仍在源码中承担规则回归的旧 `Main` 和既有构建证据，不是《一会儿巢里见》已经采纳的对外剧情、命名或完整产品结构；当前产品事实以上方“四季 Journey”和商业成品清单为准，正式导出必须把旧入口与测试资源挡在包外。

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

## 旧基线设计事实

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

默认输出位于 `outputs/music-blind-review/`。给听者的唯一入口是 `listener/index.html`；`reviewer/` 含季节、探索／遭遇角色和正确配对，必须在听者导出结果前与其隔离。工具、WAV 哈希与匿名映射已自动校验。Alan 的逐轨评论曾触发 PR #70 D/G 定向 A/B；两组均为 `tie`、“都不好”和 `neither`，因此该 PR 已关闭且不合并。Draft PR #74 随后选出探索 K 与遭遇 T/Z 方向；PR #76 将其发展为全长候选，并以组内相同响度再次匿名比较。Alan 在探索组选择 Y、遭遇组选择 M，揭盲后两者均为正式候选，因此秋季双轨创作者替换门禁通过。当前文件、生成器、Journey 路由和听者界面统一使用 `incident`／“遭遇”；历史 A/B v1 JSON 的 `boss_choice`、`boss_note` 仅作为序列化兼容别名保留。其余六轨不因本轮重写；四组配对、长期耐循环和实机混音仍未完成，不能把整套音乐标记为全面通过。完整证据与哈希见 [`docs/PLAYTEST.md`](docs/PLAYTEST.md)。

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

`[实现事实]` 当前商业路径接入 17 张 ImageGen 候选 PNG：四季地表、主／小蜂巢、巢内门槛、玩家／老师傅／工蜂、花、四位邻居、独立听声种壳与季节工作物；旧油葫芦和旧画眉候选因风格／身体设定不符已从代码、仓库与导出物完全移除，并由新的油葫芦修理状态、普通完整身体的画眉、独立种壳状态和季节工作物图集替换。路线、部分任务物、特效和 UI 仍有程序化绘制。纸雕、毛毡／布书、贴纸拼贴、像素滤镜、照片转绘、脏灰恐怖和过曝高饱和都不是当前全局方向。

`[专家启发式]` 这批图能作为统一母版的首轮运行候选，但完整线条／透视／材质／色值规范、人工清稿、逐图生成记录、可编辑源和运行尺寸审查仍缺。`[需 Alan 确认]` 没有任何一套候选获商业终稿或营销批准；`[需独立玩家验证]` 主体、状态、蜂巢功能和路线可读性尚无样本。逐文件审计见 [`docs/design/art-source-register.md`](docs/design/art-source-register.md)，强制门槛见 [`docs/design/commercial-product-requirements.md`](docs/design/commercial-product-requirements.md)。

`[实现事实]` `marketing/` 另有一张无文字 ImageGen 概念主视觉、一个中英文字标、8 个 Steam 尺寸候选和 6 张带哈希的 1280 × 720 Godot developer capture。主视觉不是玩法画面，截图清单标记 `store_ready: false`；它们都未获 Alan 终稿／发布批准，不能写成商店素材已完成。边界见 [`marketing/README.md`](marketing/README.md)。

## 开发

正式单机版需要 Godot 4.6.2 或更高版本：

```bash
godot --path godot --editor
npm run test:godot
```

`npm run test:godot` 会生成构建来源、准备导入缓存并执行 19 组 Godot 回归。当前 Journey 覆盖商业标题普通启动、四季场景唯一实例与 Camera2D、同形授粉、小蜂房边界、花牌空载／失蜜、夏季修巢、秋季逐花混合结果、冬季续暖／搬木、交棒结局、24 节气 exact-once、单次返巢、版本化存档／设置、暂停／失焦、基础手柄映射、8 轨音乐路由、14 条动作音效与 2 条环境循环；旧 Main、B01、HUD 与机制组继续作为源码回归。每组都必须在独立日志中报告 `TEST PASSED`。自动回归只证明实现时序与判定成立，不证明玩家已经理解、喜欢或愿意购买。

Web 端由 Godot 导出后，通过 Node.js 站点外壳承载：

```bash
npm install
npm run dev
npm run build
npm run test
```

桌面候选包可在 GitHub 的 **Actions → Desktop client builds → Run workflow** 手动生成。`release_tag` 必须与 `package.json` 版本一致；流水线校验 Godot 编辑器与模板、运行测试、导出 macOS／Windows 并附带 SHA-256。默认只生成保留期有限的 artifacts，只有明确选择 `publish_prerelease` 才创建预发布版本。

主要实现位于：

- `godot/commercial_title.tscn` 与 `godot/scripts/ui/commercial_title.gd`：当前普通启动标题、梦卡、继续／新旅程、设置和许可入口；
- `godot/journey.tscn`、`godot/world/journey/` 与 `godot/scripts/world/`：当前产品四季旅程、花牌事故、结局、持久会话、大地图、巢门场景、Camera2D、区域切换、巢内纪事回看和单次返巢结算；
- `godot/scripts/system/commercial_persistence.gd` 与 `godot/scripts/ui/commercial_system_menu.gd`：版本化单存档、原子备份、安全失败、暂停、设置、制作人员和许可；
- `godot/scripts/world/journey_audio_director.gd`、`godot/scripts/sound_feedback.gd` 与 `godot/assets/audio/commercial/`：8 条现有音乐 WAV 的 Journey 路由，以及 14 条项目自有确定性合成动作音效、2 条环境循环、Music／SFX 总线、Web 播放和暂停／失焦门控；这些音频是可重建的运行候选，不是已通过 Alan 与真实设备终混的发行终稿；
- `godot/data/journey_solar_term_chronicles.json`：当前产品旅程唯一的 24 节气纪事内容源，每条对应具体物候、小事件、行为和返巢解锁落点；
- `godot/assets/art/commercial/`：17 张进入运行包的 ImageGen 源候选 PNG；被否决的旧候选不在仓库或导出物中；现有候选仍不等于授权或美术定稿；
- `godot/scripts/main.gd`：旧 `Main` 的 24 节点状态流、敌害和归巢结算，仅保留源码回归，不是普通启动或正式导出入口；
- `godot/data/seasons.json`：旧 `main.tscn` 规则回归基线的 24 节点、玩法组、敌害、色彩和目标，不再定义当前产品旅程剧情；
- `godot/data/bosses.json`、`godot/scripts/boss_encounter_director.gd`、`godot/scripts/music_director.gd`、`godot/scripts/tutorial/` 与其余旧机制：只承担旧基线回归；
- `godot/bootstrap.tscn`、`godot/scripts/playtest/` 与 `godot/data/playtest_slices.json`：历史 B01 固定切片与证据工具的源码；正式导出门禁必须排除这些资源；
- `scripts/prepare_audio_blind_review.mjs`：生成 A–H 匿名盲听包和独立答案；
- `scripts/prepare_playtest_evidence.mjs`：生成首节点匿名试玩证据包和隔离分析模板；B 流程只能从 actual artifact、manifest 和精确提交 catalog 推导 ticket，每次有效运行必须使用全新 session；
- `godot/scripts/ui/production_hud.gd`：当前状态、完成条件和动作卡；
- `app/page.tsx`：Godot Web 版启动外壳。

## 文档事实源与边界

按用途读取，避免把历史方案误当当前决定：

1. [`docs/design/commercial-product-requirements.md`](docs/design/commercial-product-requirements.md)：**当前唯一商业成品要求与最终验收清单**，覆盖命名、剧情、玩法、美术、商业化、证据和发行退出门禁；
2. [`docs/design/narrative-framework.md`](docs/design/narrative-framework.md)：**当前四季剧情、角色、词汇、语气和结尾的作者版基线及实现对照**；
3. [`docs/design/art-source-register.md`](docs/design/art-source-register.md)：**当前 17 张运行候选 PNG 与概念主视觉的来源、用途、切片、哈希、授权缺口和审批状态**；
4. [`marketing/README.md`](marketing/README.md)：开发者实机截图、生成式概念主视觉、文字标与商店尺寸候选的证据边界；全部仍未获发布批准；
5. [`docs/analysis/07-competitive-analysis.md`](docs/analysis/07-competitive-analysis.md)：7 款官方竞品快照、可验证差异、价格锚点和商业门槛；市场判断只算专家启发式；
6. [`docs/RELEASE_CHECKLIST.md`](docs/RELEASE_CHECKLIST.md) 与 [`docs/BUILD_MANIFEST.md`](docs/BUILD_MANIFEST.md)：当前发布门禁与构建事实；
7. [`docs/PLAYTEST.md`](docs/PLAYTEST.md)：人工与外部玩家记录模板／记录；
8. [`docs/PLAYER_FEEDBACK_ACTION_PLAN_2026-08-24.md`](docs/PLAYER_FEEDBACK_ACTION_PLAN_2026-08-24.md)：整改、证据等级、执行矩阵和外测标准的历史执行主记录；
9. [`docs/MVP_SPEC.md`](docs/MVP_SPEC.md)：旧 MVP 候选范围与验收口径，不等于商业成品范围；
10. [`docs/DESIGN_CONSENSUS.md`](docs/DESIGN_CONSENSUS.md)：稳定设计共识与历史差距，其中冲突内容服从商业成品清单；
11. [`docs/PROJECT_LOG.md`](docs/PROJECT_LOG.md)：**历史记录**，有意保留当时成立、后来被推翻的四关、旧 Boss、旧四季和旧时长描述；
12. [`docs/DEMO_TO_PLAYTEST_PLAN.md`](docs/DEMO_TO_PLAYTEST_PLAN.md)：**已废止的历史结构方案**，仅用于追溯，不得执行；
13. [`docs/COLOR_SYSTEM.md`](docs/COLOR_SYSTEM.md)：二十四节气色彩语言；
14. [`docs/COLLABORATION_PROTOCOL.md`](docs/COLLABORATION_PROTOCOL.md)：Alan 与 Codex 的职责边界；
15. [`docs/STEAM_NEXT_FEST_2026_PLAN.md`](docs/STEAM_NEXT_FEST_2026_PLAN.md)：Steam 新品节报名与运营事项；
16. [`docs/GAME_MATURITY_AND_PRODUCTION_ASSESSMENT.md`](docs/GAME_MATURITY_AND_PRODUCTION_ASSESSMENT.md)：成熟度与市场评估，其中历史结构判断须服从商业成品清单；
17. [`docs/design/ART_IMPLEMENTATION_STANDARD.md`](docs/design/ART_IMPLEMENTATION_STANDARD.md)：美术生产规范；其中已被否决的旧风格方向不得覆盖商业成品清单；
18. [`docs/design/LAUNCH_ART_PRODUCTION_PLAN.md`](docs/design/LAUNCH_ART_PRODUCTION_PLAN.md)：历史上线美术证据与生产门禁；
19. [`docs/design/world-traversal-foundation.md`](docs/design/world-traversal-foundation.md)：春季大地图、巢门／花田切换、小蜂房边界、产品展示名和首条往返路线的实现记录。

## 当前验证问题

1. `[需独立玩家验证]` 陌生玩家能否不经口头提示完成春季首趟，区分花粉／花蜜、主巢／小蜂房，并理解观察、急转和三次花牌风窗？
2. `[需独立玩家验证]` 夏季直风／长荫、秋季逐花收／留、冬季暖路／搬木是否真实改变路线、顺序、损失或资源选择，而不是换色任务？
3. `[需独立玩家验证]` 玩家能否从动作与物件辨认蚊庄主、油葫芦、画眉邻居和大熊的习惯与帮助关系，并理解他们是需要搭把手的普通邻居？
4. `[需独立玩家验证]` 返巢后的接货、纪事和四季痕迹是否形成“回家／共同体”，还是仍像结算页；完成后去向是否清楚？
5. `[需独立玩家验证]` 单存档、检查点重开一趟、继续／新旅程确认、触屏 UI 和减少动态等设置是否符合玩家预期？
6. `[需 Alan 确认]` 当前名称、语气、四季视觉、角色、蜂巢、UI、8 轨音乐与 16 条动作／环境音频候选是否可进入定稿；哪些候选必须重做？
7. `[开发者自测]` clean macOS／Windows／Web 候选包能否从商业标题全程走到结局，并通过存档升级、强退、性能、音频和包内容审计？
8. `[需独立玩家验证]` 完整首轮各章实际时长中，有多少是有判断的行动，多少是无决策往返或说明阅读；这份内容量是否支持 Demo 边界与未来售价？

当前仍是封闭开发构建。实现事实、自动化和资产哈希都不能替代 Alan 最终批准、真实设备 QA 与独立外部玩家证据。
