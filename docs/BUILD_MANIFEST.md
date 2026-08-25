# 0.9.5 候选构建历史与校验清单

本文按时间保留 rc.1、rc.2、Web 修复与玩家反馈候选的构建证据。当前固定人工验收候选是 `0.9.5-rc.2` / `dd4d4f08`，其 artifact 与 SHA-256 见“2026-08-25 玩家反馈验收候选”；开头表格只是 2026-08-20 的 rc.1 历史记录，不是当前候选。

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
