# 0.9.4 候选 MVP 构建清单

构建日期：2026-08-15（Asia/Shanghai）
引擎：Godot 4.6.2 stable
构建类型：Debug

| 平台 | 文件 | 大小 | SHA-256 | 验证 |
| --- | --- | ---: | --- | --- |
| Web | Cloudflare Pages（Godot Web release） | WASM 分片 20,971,520 + 16,723,534 bytes / PCK 129,012 bytes（含中文字体） | 单一 Godot 导出；WASM 仅在部署阶段分片传输并由加载器重组 | 已部署至 https://hivebound-seasons-game.pages.dev |
| macOS universal | `builds/HiveboundSeasons-macOS.zip` | 65,336,790 bytes | `4e738ba6a0f527cc44b0c655e941a5e568cb8331362d9d3dc9fb341bd34c0d8f` | 重新临时签名后通过严格校验；模拟下载隔离后由首次启动脚本解除并成功启动 |
| Windows x86_64 | `builds/HiveboundSeasons-Windows.exe` | 100,703,552 bytes | `2a8b0e0f6dca8b902ea07c65f786749f36d3679309c6093645f4ec0c030e0e14` | Godot 导出成功；PE32+ 格式确认，PCK 已嵌入 |

构建产物不提交 Git；它们保留在本机 `builds/`，可按 [`godot/README.md`](../godot/README.md) 中的命令重建。

桌面构建发布于私有 GitHub [`v0.9.4`](https://github.com/alanthssss/hivebound-seasons/releases/tag/v0.9.4)；Web 构建部署至 [https://hivebound-seasons-game.pages.dev](https://hivebound-seasons-game.pages.dev)。
