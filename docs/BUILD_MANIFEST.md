# 0.9.0 候选 MVP 构建清单

构建日期：2026-08-14（Asia/Shanghai）  
引擎：Godot 4.6.2 stable  
构建类型：Debug

| 平台 | 文件 | 大小 | SHA-256 | 验证 |
| --- | --- | ---: | --- | --- |
| macOS universal | `builds/HiveboundSeasons-macOS.zip` | 65,857,238 bytes | `4609cae9734b6f48b4f02b2c7bd0547408e2e4f70db25fa8fb2b8180b1057904` | 解压后的原生程序已在本机无窗口启动 |
| Windows x86_64 | `builds/HiveboundSeasons-Windows.exe` | 100,683,072 bytes | `5f50b0d44f16c9763760b8cb27a39c079cc7bb6458e7d14ce26dedaf879b1245` | Godot 导出成功；PE32+ 格式确认，PCK 已嵌入 |

构建产物不提交 Git；它们保留在本机 `builds/`，可按 [`godot/README.md`](../godot/README.md) 中的命令重建。
