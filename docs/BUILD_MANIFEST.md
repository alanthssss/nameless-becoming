# 0.9.5-rc.1 候选 MVP 构建清单

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
