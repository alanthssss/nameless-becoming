# 0.9.4 候选 MVP 构建清单

构建日期：2026-08-15（Asia/Shanghai）
引擎：Godot 4.6.2 stable
构建类型：Debug

| 平台 | 文件 | 大小 | SHA-256 | 验证 |
| --- | --- | ---: | --- | --- |
| macOS universal | `builds/HiveboundSeasons-macOS.zip` | 65,872,332 bytes | `267c2b19ccc3567ec22e98664833e8c8ac67391b516fdebd692f5b42c2b001f5` | 原生程序已启动，并人工检查细体力条、六键按钮与花朵间距 |
| Windows x86_64 | `builds/HiveboundSeasons-Windows.exe` | 100,703,552 bytes | `2a8b0e0f6dca8b902ea07c65f786749f36d3679309c6093645f4ec0c030e0e14` | Godot 导出成功；PE32+ 格式确认，PCK 已嵌入 |

构建产物不提交 Git；它们保留在本机 `builds/`，可按 [`godot/README.md`](../godot/README.md) 中的命令重建。

两个构建已上传至私有 GitHub 仓库的 [`v0.9.4` 预发布版本](https://github.com/alanthssss/hivebound-seasons/releases/tag/v0.9.4)，远端资产大小与本表一致。
