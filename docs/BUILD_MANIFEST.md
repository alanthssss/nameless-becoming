# 0.9.2 候选 MVP 构建清单

构建日期：2026-08-14（Asia/Shanghai）  
引擎：Godot 4.6.2 stable  
构建类型：Debug

| 平台 | 文件 | 大小 | SHA-256 | 验证 |
| --- | --- | ---: | --- | --- |
| macOS universal | `builds/HiveboundSeasons-macOS.zip` | 65,862,450 bytes | `522335e44a39f3732e53f595fed470946b36a78241a3bd65f34a7c25ee0b22da` | 解压后的原生程序已在本机无窗口启动 |
| Windows x86_64 | `builds/HiveboundSeasons-Windows.exe` | 100,688,224 bytes | `7f6dfcc3ff23445c336a66cc4a195ccb31fe0305aa88736b996ca072de542f3d` | Godot 导出成功；PE32+ 格式确认，PCK 已嵌入 |

构建产物不提交 Git；它们保留在本机 `builds/`，可按 [`godot/README.md`](../godot/README.md) 中的命令重建。

两个构建已上传至私有 GitHub 仓库的 [`v0.9.2` 预发布版本](https://github.com/alanthssss/hivebound-seasons/releases/tag/v0.9.2)，远端资产大小与本表一致。
