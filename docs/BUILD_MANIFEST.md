# 0.9.0 候选 MVP 构建清单

构建日期：2026-08-14（Asia/Shanghai）  
引擎：Godot 4.6.2 stable  
构建类型：Debug

| 平台 | 文件 | 大小 | SHA-256 | 验证 |
| --- | --- | ---: | --- | --- |
| macOS universal | `builds/HiveboundSeasons-macOS.zip` | 65,854,045 bytes | `bca3e422501ba2c51ec0da16a25a3942b53c8e30e4dd8788230014af5640e86a` | 解压后的原生程序已在本机无窗口启动 |
| Windows x86_64 | `builds/HiveboundSeasons-Windows.exe` | 100,679,776 bytes | `9d087c016b9983aea0c1993a3739a8d5054c15d0e9a7982b7f0bea6bcb76f3b7` | Godot 导出成功；PE32+ 格式确认，PCK 已嵌入 |

构建产物不提交 Git；它们保留在本机 `builds/`，可按 [`godot/README.md`](../godot/README.md) 中的命令重建。
