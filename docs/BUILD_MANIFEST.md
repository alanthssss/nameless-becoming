# 《一会儿巢里见》2026-08-28 系统合同候选与历史构建校验清单

本文先记录 2026-08-28 的 24 关 Campaign 系统合同候选快照，再按时间保留 rc.1、rc.2、Web 修复与玩家反馈候选的历史构建证据。最近固定桌面 artifact 仍是 `0.9.5-rc.2` / `57aefc4933db88968777b11ea1d1679c6374842a`，见“2026-08-25 · B01 固定桌面 artifact 与 Alan 自测包”；它早于当前产品、只作历史记录，不得继续作为 24 关 Campaign、下一轮 B01 或当前交付入口。

该候选快照来自 `codex/systemic-campaign-regression`，以 `main` 合并提交 `6f7e3719` 为基点；下述验证在合并前针对同一文件差异完成，尚未生成绑定本批变更的桌面 artifact 或发行哈希。它只能证明开发工作树中的实现和 Web 内容闭包，不构成 Alan 对本轮切片的验收、独立玩家、商业美术终稿、真实设备或发行证据；合并后的准确来源以对应 Git 提交与 PR 记录为准。

## 2026-08-28 · P0、首批 30 事件与跨章节系统合同工作树

### 当前实现清单

- `godot/data/journey_levels.json` 与节气纪事组成 24 关正式目录：四季各 6 关、20 个常规关、4 个三阶段高潮关，高潮固定在第 6／12／18／24 关。
- 普通商业标题进入 `campaign.tscn`；独立 `JourneyCampaignState` 使用严格完成前缀、目录奖励、尝试令牌和 exact-once 结算。已完成关可以重飞并更新最好结果，不会重复奖励、纪事、世界痕迹或解锁。
- schema v3 保存记录关卡前缀、奖励账本、结果、最好成绩、世界痕迹与节气；雨水／谷雨两个 15 事件章节还会在第 5、10 项完成后写入整候边界检查点，继续时分别从第 6、11 项恢复。候档持久化已完成主线、已完成自选与跳过自选事件履历、路线选择、支援点、`world_state`、体力、累计时间与动作数，不保存玩家位置或事件半步瞬态；其余 22 关仍只使用主蜂巢关级检查点。
- 合法 schema v2 Campaign 升级到 v3 时最多只保留一个合法的立春完成前缀，其余旧进度进入只读 `legacy_campaign_progress`，不参与新内容的解锁、奖励或完成判定。合法旧短 Journey 仍只迁移设置、标题状态与 `legacy_journey_completed` 纪念标记；旧 `Main` 进度不导入。
- 花田运行边界为 3600 × 2000，相对 1280 × 720 参考视口横纵各约三屏；每季按 `map_variant 0—5` 使用六种任务点、风险带、遮蔽与歇脚拓扑。运行时覆盖授粉、采集、观察、震翼请路、搬运、修补、送种、转壳、续暖、固定与三阶段高潮组合 11 类多步工作；采蜜在抵达主巢接货线前不计入目标。
- `campaign_hive.tscn` 提供 24 关关卡板和接货线，`campaign_field.tscn` 提供可卸载花田；路由切换时只保留一个活动区域。蚊庄主、油葫芦、普通完整身体的画眉邻居和大熊四张现有商业状态图已分别进入四个高潮关。
- `godot/assets/art/commercial/` 当前精确闭包为 21 张运行候选 PNG；谷雨／大暑／霜降／大寒四张结果图只在对应高潮首通后展示。四张图均为 `AUTH-PENDING`／`ALAN-PENDING`／`PLAYER-PENDING`／`MKT-NO`，不表示四场正式大型事件玩法、“哇塞”体验或可售门禁通过。当前只完成雨水／谷雨 30 事件生产切片，其余 330 事件与储存／育幼／清扫／保温等蜂巢生活链仍未制作；Alan 尚未试玩本轮，独立外部玩家有效样本为 0。
- Campaign 体力、负载、恢复、主线急转保底、观察输入锁、自选事务、目标／导航／动作和候档恢复已收进跨章节合同。普通飞行不扣体力；离散扣费／奖励状态跨真实帧可见；不足一整囊的最后一批也会引导并真实交回主巢。体力教学使用持久化版本，旧设置补教一次，且只有生产 HUD 确认双行提示完整可见后才记为已学。第 5／10 项还比较现场与恢复后的全部事件标记、路线支援落点和休息点。该合同解决系统一致性，不增加其余 330 条内容。

### 当前自动验证

| 检查 | 当前结果 | 证据边界 |
| --- | --- | --- |
| Node 测试 | **本轮候选工作树 66／66 通过** | 覆盖站点、构建来源、证据工具、商业文案／脚本闭包与 24 关目录静态合同；不是 Godot 全轮试玩或玩家证据 |
| ESLint | **本轮候选工作树通过** | 只证明本轮 JS／TS lint 门禁 |
| Web 商业 pack 内容验证 | **本轮候选工作树通过** | 精确证明本轮 Campaign 入口、运行脚本／场景、21 张纹理与 16 条音频进入 Web preset，并排除 prototype、playtest、tests、tools 与被否决美术；macOS／Windows 三端闭包证据属于前序扩产工作树，本批尚未重跑桌面 preset |
| `journey_level_catalog_test.gd` | **本轮候选工作树 `TEST PASSED`** | 覆盖 24／20+4、四季各 6、高潮位置、节气对齐、场景键、目标、雨水／谷雨各 15 项及来源／批准状态合同 |
| `journey_event_matrix_runtime_test.gd`／`journey_campaign_hud_test.gd` | **本轮候选工作树 `TEST PASSED`** | 覆盖 30 事件顺序／主线自选推进、短提示／结果记录，以及 100%／115%／130% Campaign HUD 安全布局 |
| `journey_campaign_state_test.gd` | **本轮候选工作树 `TEST PASSED`** | 覆盖严格前缀、exact-once、重飞无重复奖励、伪造结果拒绝、schema v3 候档、v2→v3 收束迁移与旧 Journey 迁移 |
| `campaign_systemic_contract_test.gd` | **本轮候选工作树 `TEST PASSED`** | 逐帧覆盖 24 关普通移动／恢复、30 事件按钮与结算、负载成本、触控／鼠标首次落点、0／0.001／0.01 候档、观察锁、部分蜜囊交货、教学版本交付，以及事件 5／10 的现场／恢复地标与休息点同构 |
| 完整 Godot 回归 | **本轮候选工作树 24／24 组通过** | 每组均在独立日志报告 `TEST PASSED`；不能外推为 clean 候选、真实设备或玩家验收 |

### 当前中文字体清单

| 项目 | 值 |
| --- | --- |
| 官方源 | Noto Sans CJK SC Regular |
| 上游 Git blob | `dc15562470b4f842321894787a0d066879ccff8b` |
| 上游源文件 SHA-256 | `2c76254f6fc379fddfce0a7e84fb5385bb135d3e399294f6eeb6680d0365b74b` |
| 本次运行时扫描 | 78 个来源／1302 个字符 |
| 子集文件 | `godot/fonts/NotoSansCJKsc-ProjectSubset.otf` |
| 子集大小 | 579368 bytes |
| 子集 SHA-256 | `909581fa4cbf5d9be2173e81e6b6e151a242bd45d7f72673208055effd345754` |

该子集及当前 Web 资源 pack 仍来自 dirty 共享工作树；前序工作树的三 preset 闭包不能替本批桌面重建。只有从同一 clean commit 重生成并构建真实平台 artifact、通过完整字体覆盖与最终包检查后，才能进入候选 artifact 清单。

## 2026-08-25 · B01 固定桌面 artifact 与 Alan 自测包

实现事实：Godot 导出入口改为 `bootstrap.tscn`，无 ticket 时直接进入既有 `main.tscn`；固定 session 只接受一个绝对路径 ticket，并严格交叉核对 schema v1 ticket、同目录 `artifact-manifest.json`、包内 `build_provenance.json`、产品／平台／完整 clean commit、artifact 文件名／大小／SHA-256、manifest 原始字节 SHA-256、`playtest_slices.json` 原始字节 SHA-256、catalog 状态和编译期 registry。ticket 或 catalog 不能提供 scene、handler、stage、seed、save 或 patch 路径。任一失败只显示中性错误码，不实例化 Main，也不触碰存档。

固定 session 的通用存档名只由 ticket 原始字节 SHA-256 派生；普通启动继续使用 `user://nameless.cfg`。B01 本身完全不走存档流程：它不实例化 Main、MentorTutorial 或 SaveManager，不读也不写任何存档。固定前段是 2.8 秒老师傅因果示范、有界引导模仿和无提示实践；只有无提示实践首次成功，才进入恰好 180 秒 active 花间路线、一次无字同配置复测和中性结束，否则在有界实践后直接中性结束。内部只保留 `completed_independent`、`attempted_incomplete`、`not_attempted` 三个互斥结果。

Godot 共 14 组回归：其中 validator、bootstrap 和 namespace 隔离覆盖身份基础，共享急转运行时与 B01 两组覆盖主流程／切片规则一致、有界阶段、180 秒 active 边界、单次复测和互斥结果；Node 测试覆盖 B 的实际 artifact／manifest／catalog 身份推导、严格 CLI 和 participant 递归泄漏扫描。这些都属于开发者自动验证，不是最终分发包或真人学习证据。

构建门禁要求三个 preset 的导出包包含 `bootstrap.tscn`、原 `main.tscn`、生产 `ready` 的 `data/playtest_slices.json` 与编译注册的 B01 typed scene，并继续排除 `res://tests/` 和 `res://tools/`。GitHub [`Desktop client builds` run 32867365895](https://github.com/alanthssss/nameless-becoming/actions/runs/32867365895) 已从上述精确 clean commit 生成 provenance、macOS／Windows artifact、sidecar 和 schema v1 artifact manifest。两份 manifest 均绑定完整提交 `57aefc4933db88968777b11ea1d1679c6374842a`、`source_ref: refs/heads/main`、run `32867365895` 和 `dirty: false`：

| 平台 | GitHub artifact | 本机持久副本 | 到期时间 | payload 文件大小 | payload SHA-256 | 已完成验证 |
| --- | --- | --- | --- | ---: | --- | --- |
| macOS universal | `9570704713` / `NamelessBecoming-macOS-v0.9.5-rc.2` | `nameless-becoming-candidates/57aefc4-run-32867365895/NamelessBecoming-macOS-v0.9.5-rc.2/NamelessBecoming-macOS.zip` | `2026-09-24T15:43:34Z` | 70,368,894 bytes | `625a8cb9b379fccf92156f4a1573b062c7bb94a301a2cbe7fc54de669486395e` | universal 架构检查通过；严格签名校验通过；最终包检查通过；内嵌 PCK SHA-256 为 `20f580894489ce078fdae9acb892f19b9825ff7bd3f09ea7befcec5cb952aa57`；标准无 ticket 无界面 smoke 退出码 0 |
| Windows x86_64 | `9570695538` / `NamelessBecoming-Windows-v0.9.5-rc.2` | `nameless-becoming-candidates/57aefc4-run-32867365895/NamelessBecoming-Windows-v0.9.5-rc.2/NamelessBecoming-Windows.exe` | `2026-09-24T15:43:19Z` | 116,888,848 bytes | `ccf7101a1c7d254ab8af12908ddcdeddec794ca59dc9de28c7e37c795e70eead` | PE32+ GUI x86-64 格式检查通过；最终包检查通过；Windows 真机尚未验证 |

仓库外历史候选副本位于 `nameless-becoming-candidates/57aefc4-run-32867365895/`；该目录不是 Git 资产或公开发行渠道，也不是下一轮验收入口。上述验证只证明该历史 payload 的来源、签名／格式和资源闭包。

在干净临时目录解包后，该历史 macOS 包还以标准无 ticket 入口完成无界面 smoke。启动前后真实 `nameless.cfg` 的 SHA-256 均为 `eaafa078fb10522376ab1e05af3c183f597a8a2a5d4de1135d4aac4e92c26bbc`、mtime 均为 `1787640643`、大小均为 143 bytes，本次标准入口检查没有改写既有存档。

已从该 macOS artifact 和 manifest 生成历史 Alan B01 包会话 `NB-20260825-6412D7BA`；第一次进入 B01 后因交接失败退出，第二次命令遗漏 Godot user-argument 分隔符。在 `57aefc4` 旧构建中，空 user arguments 会进入 `Main`；该进程命令、旧构建代码和玩家“过了几关、未到 Boss”的原话共同支持 Main 判定。随后 participant JSON SHA-256 为 `d7ac2c4b7f754bc910a2e86c2d9feb2230a392d565c926b3305dd31ed32046f8`，只归档为 Alan 历史 Main 局部自测。PR #90 后当前主线已对 raw args 中错放 ticket 以 `PT-ARG-SEPARATOR` fail closed，并要求精确 ready receipt；旧会话已关闭且不得复用。有效 B01 必须从最新 clean main 重建 artifact、创建全新 session／ticket，再通过 `npm run playtest:launch` 启动。Windows B01 真机与独立外部玩家证据仍待采集。

## 2026-08-20 · 0.9.5-rc.1 首个三目标候选

构建日期：2026-08-20（Asia/Shanghai）

引擎：Godot 4.6.2 stable（官方模板 SHA-512 校验通过）

构建类型：Debug candidate

| 平台 | 文件 | 大小 | SHA-256 | 验证 |
| --- | --- | ---: | --- | --- |
| Web | `public/game/`（生成产物，不提交 Git） | WASM 分片 20,971,520 + 14,777,661 bytes；PCK 253,252 bytes | 原始 WASM `52e3c0045f333c05c85b03bc034b87225bc064d1d4eb673bf844ffaea6beadb4`；PCK `ee5a2b3fbcaa435e77cd6e704f14358877ed163fcba676054e93dc4c59489aeb` | 空目录重新导出；分片重组 SHA-256 一致；Web 构建与测试通过；Sites version 5 私有部署成功 |
| macOS universal | `builds/NamelessBecoming-macOS.zip` | 65,481,952 bytes | `3d8745ffab1706ef1012280cba755a0cbc99176c8c1b95de76dc3d9199f18945` | arm64 + x86_64；短版本 0.9.5、构建版本 0.9.5-rc.1；重新临时签名并通过严格校验；无界面启动退出码 0 |
| Windows x86_64 | `builds/NamelessBecoming-Windows.exe` | 100,888,400 bytes | `0101c63ef4064bcbcd17a00abe67a579dd238517bb3c01b71f80af1b34536a52` | PE32+ GUI x86-64；Godot 导出成功，PCK 已嵌入；待 Windows 实机启动验证 |

构建产物不提交 Git；它们保留在本机 `builds/` 与 `public/game/`，可按 [`godot/README.md`](../godot/README.md) 中的命令重建。

本候选首次包含已经合入主线的四季机制、二十四节气数据、四正色失律者节点、情境动作输入和力竭反馈。它替代旧 0.9.4 构建作为当前验证基线，但在完成三端发布与人工全流程前不标记为正式版本。

桌面候选已发布至 GitHub [`v0.9.5-rc.1`](https://github.com/alanthssss/nameless-becoming/releases/tag/v0.9.5-rc.1) 预发布版本，远端资产大小与 SHA-256 均和本表一致。

Web 候选已作为 Sites version 5 私有部署至 [hivebound-seasons.alanthssss.chatgpt.site](https://hivebound-seasons.alanthssss.chatgpt.site)，站点访问策略保持所有者单人可见；这不是公开试玩发布。

## Web 中文字形修复候选

2026-08-20 针对 Sites 版本中部分新增中文显示为方框的问题，从空目录重新导出 Web 包。工程字体改为由官方完整 Noto Sans CJK SC Regular 生成的项目文案子集（427,736 bytes，SHA-256 `e09b2836d25f0a307af31c4d377746a10da9cfdd546aa7d9229cc9158ecdd308`），并随仓库保留 OFL 许可文本。上游完整字体以 Git blob SHA `dc15562470b4f842321894787a0d066879ccff8b` 核验。

字形门禁会扫描实际游戏数据和界面源码，确保子集覆盖当前全部 CJK 文案；新增文案缺字时 CI 会失败并要求重生成子集。空目录重导出的 `public/game/index.pck` 为 514,320 bytes，SHA-256 `37f2a7e9e76f8ad2e750bd6bb182ecb61122a4f4275c68fa4567552d49145fde`；WASM 分片重组、Web 构建、渲染测试与 Godot 中文字形覆盖测试均通过。该记录只更新 Web 候选；0.9.5-rc.1 桌面发布资产及其校验值不变。

修复树以 Sites 源提交 `f3d4cd59fb015fb1a80eb128dd202e629c2bd2ff` 保存为 version 6，并成功私有发布到原生产 URL；访问策略仍为所有者单人可见。当前自动化会话未提供受支持的浏览器交互接口，且部署未生成截图资产，因此生产页中文字形目视确认仍需人工完成。

## Web 文本控件完整覆盖修复

version 6 人工截图确认 Label 中文已恢复，但 Button 中文仍显示方框。根因不是继续缺字，而是运行时创建的控件没有 scene owner，`find_children("*", "Button", true)` 默认只返回有 owner 的节点，导致按钮字体覆盖循环实际匹配 0 个按钮。

修复将搜索改为 `owned=false`，并把 smoke 门禁提升为两层：递归扫描全部运行时 `.gd/.godot/.json/.tres/.tscn` 的 CJK 字形；实例化真实主场景，验证每个 Label/Button 实际解析到项目字体。字体子集生成器也已纳入仓库，按同一运行时资源范围重建 16 个来源、958 个字符的子集。

重建字体为 429,356 bytes，SHA-256 `08e8d9469aca3f65a518ebd494898b1b43dbc23cd1aec8a75c93ffeebf94c576`；空目录重导出的 `public/game/index.pck` 为 516,544 bytes，SHA-256 `a79e98342db0ba69df0ed92f15b2f8a654d97227a60590cb73e278d1c823e613`。

完整文本控件修复以 Sites 源提交 `398644a874402850ee1cea56cba99c510a494d24` 保存为 version 7，并成功私有发布到原生产 URL；访问策略仍为所有者单人可见。

## Web 装饰符号兼容修复

version 7 人工截图发现侧栏“目标 / 敌害”前的 `▸` 显示为方框。对 16 个运行时文本来源的全部非 ASCII 字符与上游完整 Noto Sans CJK SC cmap 做差集，确认唯一不受支持的字符就是 U+25B8 `▸`；普通关、Boss 与越冬状态行已统一改用文字标签，不再依赖该装饰符。

smoke 门禁同步增加当前可见 Label/Button 文本的逐字符 `has_char` 检查。重建字体为 431,556 bytes，SHA-256 `13839d372ea7f8f4208547cceb7d207c9def67a4eee0159ee1dd2db92b9502d0`；空目录重导出的 `public/game/index.pck` 为 519,472 bytes，SHA-256 `e86cb257d16dad7bc1d695f18c5d43838332d46b47a44a3a9d0ec3a7bc384bad`。

装饰符号兼容修复以 Sites 源提交 `67c77d9b578c2d63a1dd52c94f1aaec539acedf0` 保存为 version 8，并成功私有发布到原生产 URL；访问策略仍为所有者单人可见。

## 正式试玩版 P0 基础

Web 外壳增加启动、加载、20 秒超时和重试状态，并明确标记为“可玩垂直切片 · 私人试玩构建”；Godot 首次说明收敛为移动、采蜜、归巢三步。新增文案触发字形门禁后，使用可复现生成器重建字体。

重建字体为 431,976 bytes，SHA-256 `63c5925cbea147322c754abcbb650b23f79ceabd7641eaf032697fb57ed09108`；空目录重导出的 `public/game/index.pck` 为 519,888 bytes，SHA-256 `ab0dbc36a20ee7e0e09b851e66037922a03a532a1ce81cef78bf5b8c729ac349`。Godot 三组测试、Web 构建、渲染测试、ESLint 与 WASM 分片准备均通过。

## 渐进教学与 HUD 收束候选

2026-08-20 将系统级操作收进暂停层、把五张同权状态卡合并为采集/飞行/蜂巢三组，并删除永久快捷键长条。首局教学改为由实际行为推进的移动→采蜜→归巢三步，情境动作只在成立时出现；失律者关保留独立“调律”动作。对应 UX 规则、材质语法和六边形约束已同步进入设计文档。

字体子集为 428,008 bytes，SHA-256 `4247285bb7ff4deb42c7707714c0ff746b00e515a8b3b4fbbc9b2464cd278bbc`；空目录重导出的 `public/game/index.pck` 为 522,720 bytes，SHA-256 `c1d0100aafc35f0fc8fb347dc5de42cfb193a007770696726b9d023765441b29`。WASM 分片为 20,971,520 与 16,723,534 bytes；Godot 三组测试、Web 构建、渲染测试与 ESLint 全部通过。

正式试玩版 P0 基础以 Sites 源提交 `1fd3ba9cbc9962c449cce1ffa613d237dceffefa` 保存为 version 9，并成功私有发布到原生产 URL；访问策略仍为所有者单人可见。

## Web 首载与情境教学候选

2026-08-20 增加寻迹、敌害与低体力三类首次情境教学，并将 Web 核心载荷由 37,695,054 bytes 的原始 WASM 优先切换为 9,469,248 bytes 的 gzip 流式解压载荷；20,971,520 与 16,723,534 bytes 的原始分片仅作不支持 `DecompressionStream` 浏览器的兼容回退。gzip 解压结果与双分片重组结果 SHA-256 均为 `cca8bc7c462d348aaa3f318aecf3281d99bf219e182256412711b24f0d086d80`。

字体子集为 428,260 bytes，SHA-256 `c4099e124cbd1666d67b080cc3ed4ff4c0da152e0b82f93880dad3df1383e5e8`；空目录重导出的 `public/game/index.pck` 为 524,480 bytes，SHA-256 `204fb3aef4fb892b64f799d9101417fc48f94368be134ede00246806cc2c95d2`；gzip 载荷 SHA-256 为 `28105b24784987bf32eed7bb2d3388ad6c57e14fb603bdebc268c1e559403b87`。外层页面等待 Godot 真实 ready/error 消息而非 iframe onLoad；Godot 三组测试、Web 构建、渲染测试、ESLint、压缩包解压与分片重组一致性均已通过。

## 0.9.5-rc.2 桌面候选

2026-08-20 从包含渐进 UX、三类首次情境教学与字体补全的同一 Godot 工程重新导出桌面候选；本地构建用于先验证导出与打包逻辑，合入后由 GitHub `Desktop client builds` 使用官方 SHA-512 校验过的编辑器和模板独立重建。

| 平台 | 文件 | 大小 | SHA-256 | 本地验证 |
| --- | --- | ---: | --- | --- |
| macOS universal | `builds/NamelessBecoming-macOS.zip` | 61,590,267 bytes | `568d3a6567b75a6e26132dbd34700cbf979f85b9828ef0f3e37023e582ccf064` | arm64 + x86_64；0.9.5 / 0.9.5-rc.2；ad-hoc 签名严格校验通过；无界面启动退出码 0 |
| Windows x86_64 | `builds/NamelessBecoming-Windows.exe` | 105,037,008 bytes | `57353aa7638e127ed5e9d8c58b8649802a673a39652e7704aa8a8105140736d0` | PE32+ GUI x86-64；PCK 内嵌；仍需 Windows 真机试玩 |

GitHub runner 重建值可能因官方 runner 的 ZIP 元数据不同而与本机 macOS ZIP 哈希不同；流水线产出的 `.sha256` 才是对应下载 artifact 的权威校验值。首次 run `32383642710` 暴露并修复 sidecar 路径前缀；修复后的权威 run [`32384928730`](https://github.com/alanthssss/nameless-becoming/actions/runs/32384928730) 生成 macOS（62,093,143 bytes，SHA-256 `c10c20393b337ca175c8f6aaedd940baffef5d6a3ab5b385a29b6d39e54d172b`）与 Windows（105,037,008 bytes，SHA-256 `a530ada249f2d40d7c58dec7cc1eefe2efdbde7916a81d1aa4ec034d3f933bfb`）。两个 artifact 下载解包后均以随包 sidecar 直接校验通过；保留 30 天，尚未创建 GitHub prerelease。

## 2026-08-25 玩家反馈验收候选

本候选固定于 PR #63 提交 `dd4d4f08d33d743c8d4a67e50dedbcac2a70fdb1`，包含本轮关卡、四季、8 轨音乐、老师傅教学、授粉生态、条件卡与急转因果整改，以及游戏内构建来源显示。标题与暂停覆盖层显示 `v0.9.5-rc.2 · dd4d4f08`；未提交工作区会额外显示 `+dirty`，桌面包内嵌的 provenance 为 `dirty: false`。PR #63 随后已合并为 `main` 提交 `4537151`；`dd4d4f08` 是固定 artifact 来源，`4537151` 是合并后的仓库事实，两者不得混作同一哈希。

GitHub [`Desktop client builds` run 32769425753](https://github.com/alanthssss/nameless-becoming/actions/runs/32769425753) 使用官方 SHA-512 清单校验 Godot 4.6.2 编辑器与导出模板，在 macOS/Ubuntu runner 分别重跑 8 组 Godot 测试后导出：

| 平台 | Artifact | 大小 | SHA-256 | 自动验证 |
| --- | --- | ---: | --- | --- |
| macOS universal | `NamelessBecoming-macOS-v0.9.5-rc.2/NamelessBecoming-macOS.zip` | 70,583,701 bytes | `005d00ee08217c07639d8861b437de9932e24a05844450d9b5150917e92ab39e` | universal 包导出、ad-hoc 签名严格校验、artifact 上传；下载后 sidecar 再校验通过，本机解包后 `codesign --verify --deep --strict` 通过 |
| Windows x86_64 | `NamelessBecoming-Windows-v0.9.5-rc.2/NamelessBecoming-Windows.exe` | 116,575,264 bytes | `f6e0d8019525d480af404424a854a9b2ede944bfd612dde16903e0d268431b26` | PE32+ GUI x86-64 格式检查、artifact 上传；下载后 sidecar 再校验通过 |

两个 artifact 保留 30 天，本轮没有创建 prerelease。上述证明产物与提交一致且可被工具解析；Windows 真机启动、macOS 实际手感、声音、全屏/DPI、完整流程和玩家理解仍是人工门禁。

## 2026-08-25 HUD 与指针输入历史候选

该候选来自构建时的 `origin/main` 完整提交 `f57ea02c8defea82bcc7f1b8849146350e76d578`。该提交包含已合并的 PR #63（玩法与资产）、PR #64（音乐盲听工具）、PR #66（当前事实源同步）和 PR #65（HUD 等比安全框、饮蜜指针／单指触摸入口与第 9 组 HUD 自动化）。后续 PR #67 只增加试玩证据工具与文档，不改变这份已固定的游戏二进制。PR #65 在合并前取得 Alan 对视觉与饮蜜按钮方向的明确允许；这不等于真实触摸屏、完整流程或外部玩家验收已经通过。

GitHub [`Desktop client builds` run 32809311832](https://github.com/alanthssss/nameless-becoming/actions/runs/32809311832) 从上述精确 `main` 提交构建，使用官方 SHA-512 清单校验 Godot 4.6.2 编辑器与导出模板，并在 macOS／Ubuntu runner 重跑 9 组 Godot 测试。`release_tag` 为 `v0.9.5-rc.2`，`publish_prerelease=false`，因此没有创建或覆盖 GitHub prerelease。

| 平台 | Artifact | 大小 | SHA-256 | 已完成验证 |
| --- | --- | ---: | --- | --- |
| macOS universal | `NamelessBecoming-macOS-v0.9.5-rc.2/NamelessBecoming-macOS.zip` | 70,598,030 bytes | `d2b94648e5637c1e62ec9db38dc950caf1bf9756c8fba14381d3c48e52dcbaf3` | sidecar 复验通过；arm64 + x86_64；0.9.5 / 0.9.5-rc.2；ad-hoc 签名通过严格校验；内嵌完整提交号且 `dirty: false`；本机无界面启动退出码 0 |
| Windows x86_64 | `NamelessBecoming-Windows-v0.9.5-rc.2/NamelessBecoming-Windows.exe` | 116,589,584 bytes | `8a45db5f23fca1d4d1de11b5ce9622d4fee530a5a4223e1bd109a872e772b34c` | sidecar 复验通过；PE32+ GUI x86-64；内嵌完整提交号且 `dirty: false`；仍需 Windows 真机启动与输入／显示／声音验证 |

本机历史副本位于仓库外的 `nameless-becoming-candidates/f57ea02/`，macOS 与 Windows 子目录各保留 artifact 和 sidecar。该目录用于追溯旧 A 包来源，但不是当前验收入口、Git 资产或公开发行渠道。该 macOS 包只是 ad-hoc 签名且未公证，Windows 包未做 Authenticode 签名；两者均不得表述为公开发行签名通过。

## 2026-08-25 首次采蜜修复候选

该历史人工验收候选来自完整 `main` 提交 `4b57d85607c9811efcfd5fcc83f7c976bdebdb4d`。PR #69 根据旧 `f57ea02c` A 包的首分钟反馈，补齐首次采蜜的有效距离事实、持续按住操作、`蜜囊 +1` 成功证据和老师傅可见演示；它没有把旧包的结果改写成新候选的通过证据。

GitHub [`Desktop client builds` run 32817220563](https://github.com/alanthssss/nameless-becoming/actions/runs/32817220563) 从上述精确提交生成桌面 artifact。两个下载文件均以随包 sidecar 复验 SHA-256：

| 平台 | 本机持久副本 | 大小 | SHA-256 | 已完成验证 |
| --- | --- | ---: | --- | --- |
| macOS universal | `nameless-becoming-candidates/4b57d85/macOS/NamelessBecoming-macOS.zip` | 70,599,922 bytes | `30613b93e6a23b218c49070ac4afdd444cf41b128f7c995415713a69ade508ab` | sidecar 复验通过；在 `/private/tmp` 解包后确认为 x86_64 + arm64 universal，并通过 `codesign --verify --deep --strict`；内嵌 PCK SHA-256 为 `b84d7611548dacf667a9333b5e1f83485383aca13030502cd9eed2cd59c8bd90` |
| Windows x86_64 | `nameless-becoming-candidates/4b57d85/Windows/NamelessBecoming-Windows.exe` | 116,591,840 bytes | `a364c48c05e7c14629db2590d80fc6e429e57c31de0ee3f0ff9ccb7259aa2727` | sidecar 复验通过；仍需 Windows 真机启动与输入／显示／声音验证 |

旧 `f57ea02c` 的 A 包、人工操作记录与哈希核对继续作为旧候选证据保留，不能迁移成 `4b57d856` 的首关、教学或完整流程通过。该候选当时仍需重新完成首分钟采蜜、急转、授粉器官、四季路线、Boss 与设备流程；其缺失证据也不能迁移成后续候选的通过。

## 2026-08-25 秋季双轨集成历史候选

该历史 artifact 来自完整 `main` 提交 `de78f2c8965ee06c5a6431c71eeb47a9a1be9abd`。该提交是 PR #76 的合并提交，在 `4b57d856` 玩法基线上包含已经通过 Alan 最终等响度 A/B 的秋季探索／Boss 双轨；它当时取代 `4b57d856`，但不会把旧候选的玩法证据迁移为新候选通过。

GitHub [`Desktop client builds` run 32840904829](https://github.com/alanthssss/nameless-becoming/actions/runs/32840904829) 以 `workflow_dispatch` 从上述精确 `main` 提交运行，版本校验、官方 Godot 4.6.2 编辑器／模板 SHA-512 校验、9 组 Godot 测试和双端导出均成功。`publish_prerelease=false`，所以 Publish GitHub prerelease job 按预期跳过，没有创建或覆盖 prerelease。两个远端 artifact 到期日均为 2026-09-24：

| 平台 | GitHub artifact | 本机持久副本 | 大小 | SHA-256 | 已完成验证 |
| --- | --- | --- | ---: | --- | --- |
| macOS universal | `9560488439` / `NamelessBecoming-macOS-v0.9.5-rc.2` | `nameless-becoming-candidates/de78f2c-run-32840904829/macOS/NamelessBecoming-macOS.zip` | 70,413,511 bytes | `f7e82a1eb875495e27fea38784aa15c51e36b2dc26c26a15152a39f55e4ee776` | 随包 sidecar 本机复验通过；干净临时目录解包后严格验签通过，Mach-O 为 x86_64 + arm64，bundle id `com.alanthssss.namelessbecoming`，short version `0.9.5`，bundle version `0.9.5-rc.2`，无界面 smoke 退出码 0 |
| Windows x86_64 | `9560473513` / `NamelessBecoming-Windows-v0.9.5-rc.2` | `nameless-becoming-candidates/de78f2c-run-32840904829/Windows/NamelessBecoming-Windows.exe` | 116,932,160 bytes | `d5d2155653dafe224846a10edc109702480525abd1f657d972ba2003ae2a5117` | 随包 sidecar 本机复验通过；本机确认为 PE32+ GUI x86-64；Windows 真机尚未验证 |

PCK provenance 为产品版本 `0.9.5-rc.2`、完整提交 `de78f2c8965ee06c5a6431c71eeb47a9a1be9abd`、`dirty: false`；标题／暂停层应显示 `v0.9.5-rc.2 · de78f2c8`，不含 `+dirty`。Documents 中的解压副本曾被文件提供器附加 FinderInfo，导致该副本严格验签误报；同一 ZIP 在干净临时目录解包后显示 `valid on disk` 且 `satisfies its Designated Requirement`，因此这是本机文件元数据现象，不是 ZIP 内签名失败。

这是标准完整流程包，没有秋季直达入口或固定秋季存档；因此它证明新版秋季 WAV 已进入可追溯桌面构建，不证明听者能跳过前置节点直接复核秋季，也不关闭游戏内音效遮蔽、循环疲劳与混音门禁。Windows 真实设备启动、DPI／全屏、输入、声音、设置持久化和退出仍须人工验证；macOS 包仍只是 ad-hoc 签名且未公证，Windows 包仍未做 Authenticode 签名。

该构建随后在开发者内部试听时暴露 Boss 失败／暂停 HUD 的逐帧 `SCRIPT ERROR`，以及终点熊战可能读取上一普通节点暖点状态的问题。其来源、文件哈希和签名复验仍是真实历史证据，但它已知包含该 P1，已由下述 `21a44bd` 候选替代，不得继续用于完整流程或 Boss 失败／暂停验收。

## 2026-08-25 Boss 失败／暂停修复候选

该历史固定 artifact 来自完整 `main` 提交 `21a44bd64e100231548fa2663a7b4d6f472a88dd`。该提交是 PR #79 的合并提交，在 `de78f2c` 的玩法、HUD、首次采蜜修复和正式秋季双轨基础上，修复 Boss 可重试失败、Boss 中暂停、最后一命失败与循环终点熊战的 HUD 上下文，并在进入 Boss 前结束上一普通节点的季节机制。它曾取代 `de78f2c` 作为固定桌面候选，但不会把旧候选的试玩或人工验收结论迁移为通过。

GitHub [`Desktop client builds` run 32844593593](https://github.com/alanthssss/nameless-becoming/actions/runs/32844593593) 以 `workflow_dispatch` 从上述精确 `main` 提交运行，版本校验、官方 Godot 4.6.2 编辑器／模板 SHA-512 校验、9 组 Godot 测试和双端导出均成功。`publish_prerelease=false`，所以没有创建或覆盖 GitHub prerelease：

| 平台 | GitHub artifact | 本机持久副本 | 到期时间 | 大小 | SHA-256 | 已完成验证 |
| --- | --- | --- | --- | ---: | --- | --- |
| macOS universal | `9561860219` / `NamelessBecoming-macOS-v0.9.5-rc.2` | `nameless-becoming-candidates/21a44bd-run-32844593593/macOS/NamelessBecoming-macOS.zip` | `2026-09-24T11:54:52Z` | 70,416,218 bytes | `430567fd9e2edfe1c8f83be2eea1b89f7dd37826c4f7bbd070ce65ead2a5cd4d` | 随包 sidecar 本机复验通过；干净临时目录解包后严格验签通过；Mach-O 为 x86_64 + arm64，bundle id `com.alanthssss.namelessbecoming`，short version `0.9.5`，bundle version `0.9.5-rc.2`；内嵌 PCK SHA-256 为 `d6537686e016473db6b67710a29189e8cf91be078478b9929436ebbc0f0a06de`；无界面 smoke 退出码 0 |
| Windows x86_64 | `9561841115` / `NamelessBecoming-Windows-v0.9.5-rc.2` | `nameless-becoming-candidates/21a44bd-run-32844593593/Windows/NamelessBecoming-Windows.exe` | `2026-09-24T11:54:16Z` | 116,934,816 bytes | `65704d9d04430643c6c61678e922041bf45dacd48be7328aa9b070d8791cdcd7` | 随包 sidecar 本机复验通过；本机确认为 PE32+ GUI x86-64；Windows 真机尚未验证 |

macOS PCK 与 Windows EXE 均内嵌产品版本 `0.9.5-rc.2`、完整提交 `21a44bd64e100231548fa2663a7b4d6f472a88dd` 和 `dirty: false`；标题／暂停层应显示 `v0.9.5-rc.2 · 21a44bd6`，不含 `+dirty`。macOS 无界面 smoke 前后，真实存档 SHA-256 均为 `eaafa078fb10522376ab1e05af3c183f597a8a2a5d4de1135d4aac4e92c26bbc`、mtime 均为 `1787640643`、大小均为 143 bytes，证明本次启动检查未改写已有存档。

以上是构建、来源、签名、格式和开发者 smoke 事实，不是 Alan 完整人工流程、秋季实机混音、Windows 真机或外部玩家验收。标准包仍没有秋季直达入口或固定秋季存档；macOS 包仍只是 ad-hoc 签名且未公证，Windows 包仍未做 Authenticode 签名。

### 内部资源边界复核与候选降级

2026-08-25 使用 Godot 4.6.2 的 `ProjectSettings.load_resource_pack()` 分别挂载上述本机持久副本中的 macOS PCK 与 Windows 内嵌 PCK，两个真实交付包都检出 10 个 `res://tests/*.gdc` 和对应 10 个 `.gd.remap`。当时的来源树没有 `res://tools/`，因此这两个固定包未检出 tools 资源；这不改变交付包不应包含测试资源的边界。

该发现证明的是导出范围与包体卫生缺陷。仅凭测试字节码被打包，不能得出存在可利用安全漏洞或已造成安全事件的结论；安全定性需要独立威胁分析。但 `21a44bd` 双端 artifact 已不满足预期交付边界，必须停止继续验收，并由修复后的新完整提交重建替代。旧文件和哈希继续保留为历史证据，不得改写为已通过过滤的候选。

修复把 macOS、Windows Desktop、Web 三个 Godot 4.6.2 preset 的排除 glob 统一为 `tests/**,tools/**`。自动门禁不是 grep 配置：质量流水线会对三个 preset 逐一执行真实 `--export-pack` 并由 Godot 挂载检查；桌面构建流水线还会在 `package_macos.sh` 完成签名与重新打包后，从最终 macOS ZIP 解包并直接挂载其中的 PCK，同时检查最终 Windows EXE 的内嵌 PCK。任一包出现 `res://tests/` 或 `res://tools/`、缺少主场景 remap，或检查脚本没有显式成功标记都会失败。下述 `29e719f` 双端 artifact 曾在修复合入后的完整提交上重建，并由该新检查器直接确认最终交付包边界；它现已被包含 B01 运行时的 `57aefc4` 候选替代。

## 2026-08-25 历史内部资源导出门禁候选 `29e719f`

该历史固定 artifact 来自完整 `main` 提交 `29e719fff1621df35f88972f3bdeed98e37d8af9`。该提交是 PR #82 的合并提交：在 `21a44bd` 已有玩法、首次采蜜、秋季双轨和 Boss 失败／暂停修复之上，包含 PR #81 的外围弹层键盘焦点／切出暂停修复，以及 PR #82 的三 preset 内部资源排除与最终包检查门禁。它早于 PR #85／#87 的固定切片身份与 B01 运行时，已被 `57aefc4` 替代，不再是当前验收入口。`21a44bd` 继续作为包含更早历史缺陷的可追溯记录。

GitHub [`Desktop client builds` run 32851917691](https://github.com/alanthssss/nameless-becoming/actions/runs/32851917691) 从上述精确提交生成双端 artifact。两个下载文件均已用随包 sidecar 在本机复验 SHA-256；下表大小与哈希指 artifact 解包后的 macOS ZIP／Windows EXE payload，不是 GitHub Actions 外层下载归档：

| 平台 | GitHub artifact | 本机持久副本 | 到期时间 | payload 文件大小 | payload SHA-256 | 已完成验证 |
| --- | --- | --- | --- | ---: | --- | --- |
| macOS universal | `9564658342` / `NamelessBecoming-macOS-v0.9.5-rc.2` | `nameless-becoming-candidates/29e719f-run-32851917691/macOS/NamelessBecoming-macOS.zip` | `2026-09-24T13:13:49Z` | 70,315,673 bytes | `be1e269c529e651de71c9658f9d16bad3822b27eba4b6841df2d080208114e4e` | sidecar 复验通过；干净解包后 `codesign --verify --deep --strict` 通过；Mach-O 为 x86_64 + arm64，bundle id `com.alanthssss.namelessbecoming`，short version `0.9.5`，bundle version `0.9.5-rc.2`；内嵌 PCK SHA-256 为 `8af383ff36607d3a6200c6d789f6ecc0cc39603684ac43c20550cef51598b1f7`；无界面 smoke 通过 |
| Windows x86_64 | `9564653395` / `NamelessBecoming-Windows-v0.9.5-rc.2` | `nameless-becoming-candidates/29e719f-run-32851917691/Windows/NamelessBecoming-Windows.exe` | `2026-09-24T13:13:40Z` | 116,831,112 bytes | `48195830e70ca78f68316dc9c6a8a9193ed85c894ca2601f33f951f0252ff074` | sidecar 复验通过；本机确认为 PE32+ GUI x86-64；Windows 真机尚未验证 |

新的最终包检查器直接复核了 macOS ZIP 内的实际 PCK 和 Windows EXE 的内嵌 PCK：两者均不含 `res://tests/` 或 `res://tools/`，且 provenance 均为产品版本 `0.9.5-rc.2`、完整提交 `29e719fff1621df35f88972f3bdeed98e37d8af9`和 `dirty: false`。标题／暂停层应显示 `v0.9.5-rc.2 · 29e719ff`，不含 `+dirty`。

macOS 无界面 smoke 前后，真实存档 `nameless.cfg` 的 SHA-256 均为 `eaafa078fb10522376ab1e05af3c183f597a8a2a5d4de1135d4aac4e92c26bbc`、mtime 均为 `1787640643`、大小均为 143 bytes，本次启动检查未改写已有存档。仓库外本机副本根目录为 `nameless-becoming-candidates/29e719f-run-32851917691/`；该目录不是 Git 资产或公开发行渠道。

以上关闭了 `21a44bd` 的内部资源边界构建阻断，并证明 PR #81 与 PR #82 已进入可追溯的双端交付包。它仍不等于 Alan 真人完整流程、Windows 真机、外部玩家、八轨总体／长期耐循环或游戏内完整混音通过。标准包仍没有秋季直达入口；macOS 包仍只是 ad-hoc 签名且未公证，Windows 包仍未做 Authenticode 签名。
