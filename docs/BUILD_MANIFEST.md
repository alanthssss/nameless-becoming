# 0.9.3 候选 MVP 构建清单

构建日期：2026-08-15（Asia/Shanghai）
引擎：Godot 4.6.2 stable
构建类型：Debug

| 平台 | 文件 | 大小 | SHA-256 | 验证 |
| --- | --- | ---: | --- | --- |
| macOS universal | `builds/HiveboundSeasons-macOS.zip` | 65,866,516 bytes | `a859c0b849578e364a4c68e877908854bec9b58e63acb195e1409ecc6af347c0` | 解压后的原生程序已启动，并人工检查标题、关卡与触角寻迹画面 |
| Windows x86_64 | `builds/HiveboundSeasons-Windows.exe` | 100,693,744 bytes | `3eef94506a148ac71c76d21d623a7a3e38b6a4110d480d22295dbd6388693a34` | Godot 导出成功；PE32+ 格式确认，PCK 已嵌入 |

构建产物不提交 Git；它们保留在本机 `builds/`，可按 [`godot/README.md`](../godot/README.md) 中的命令重建。

两个构建将上传至私有 GitHub 仓库的 `v0.9.3` 预发布版本；发布后核对远端资产大小。
