# 0.9.0 候选 MVP 构建清单

构建日期：2026-08-14（Asia/Shanghai）  
引擎：Godot 4.6.2 stable  
构建类型：Debug

| 平台 | 文件 | 大小 | SHA-256 | 验证 |
| --- | --- | ---: | --- | --- |
| macOS universal | `builds/HiveboundSeasons-macOS.zip` | 65,858,227 bytes | `052e810774b1c58b94cda3f55a4669f78bc87042e734dd0a0b8847ead9458214` | 解压后的原生程序已在本机无窗口启动 |
| Windows x86_64 | `builds/HiveboundSeasons-Windows.exe` | 100,684,016 bytes | `61a121d169075887c093fc63b4e658a66cfcf5d7fe4b702cee28a4018b18a913` | Godot 导出成功；PE32+ 格式确认，PCK 已嵌入 |

构建产物不提交 Git；它们保留在本机 `builds/`，可按 [`godot/README.md`](../godot/README.md) 中的命令重建。
