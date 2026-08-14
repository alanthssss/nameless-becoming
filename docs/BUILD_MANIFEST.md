# 0.9.1 候选 MVP 构建清单

构建日期：2026-08-14（Asia/Shanghai）  
引擎：Godot 4.6.2 stable  
构建类型：Debug

| 平台 | 文件 | 大小 | SHA-256 | 验证 |
| --- | --- | ---: | --- | --- |
| macOS universal | `builds/HiveboundSeasons-macOS.zip` | 65,858,401 bytes | `d9456edb14857e1f95c56badd412249bc46590f0b6a52b83a71ffb0f94478c22` | 解压后的原生程序已在本机无窗口启动 |
| Windows x86_64 | `builds/HiveboundSeasons-Windows.exe` | 100,683,712 bytes | `576970baffef8ec2503164ca26dd3cec3a109c97647b67b214cda6702741af4d` | Godot 导出成功；PE32+ 格式确认，PCK 已嵌入 |

构建产物不提交 Git；它们保留在本机 `builds/`，可按 [`godot/README.md`](../godot/README.md) 中的命令重建。

两个构建已上传至私有 GitHub 仓库的 [`v0.9.1` 预发布版本](https://github.com/alanthssss/hivebound-seasons/releases/tag/v0.9.1)，远端资产大小与本表一致。
