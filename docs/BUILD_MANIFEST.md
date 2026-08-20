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
