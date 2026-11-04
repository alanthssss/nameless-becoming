# 采蜜与蜂舞 Demo：macOS / Steam 发行准备

2026-11-03；GDD §13.9 / M3 / [SD08 #295](https://github.com/alanthssss/nameless-becoming/issues/295)。本文件承接[SD-v1 制作规格](../design/nectar-steam-demo.md)，不是第二份执行队列。用户已确认**首批只做 macOS，目前没有 AppID**。状态：本地发行准备；尚未上传、未获 Valve 审核、没有 Steam 发布就绪声明。

## 已完成和仍未完成

已准备中文页面草稿、AI 内容调查草稿、macOS 签名公证步骤、SteamPipe 参数化生成器与本地完整性检查。游戏 0.22 候选的完整运行证据由本轮构建回执承接，不能用本文件的脚本测试替代。未登录任何发行账户，没有申请账号、付费、上传或发布。

| 外部事项 | 当前状态 | 解除条件 |
|---|---|---|
| Steamworks 合作伙伴账户及协议/税务 | 未取得可用发行配置 | 账户持有人完成，保留平台回执，不将身份/税务材料放仓库 |
| 本体 AppID、关联 Demo AppID、DepotID | 用户确认暂无 | 从真实 Steamworks 后台取得三者；生成器使用 **Demo** AppID |
| SteamPipe / 安装项 / Packages | 未配置、未测试 | Depot 包含在可测试 Package 中，启动路径正确，配置已发布 |
| Developer ID / Apple 公证 | 未验证拥有；本轮未执行 | 有效签名身份，公证 Accepted，stapler 与 Gatekeeper 检查通过 |
| 最低系统与 Intel 实机 | 未测最低配置与 Intel | 指定支持矩阵，在真实机器测启动、全流程、存档、音频和显示 |
| Demo 页面素材及内容调查 | 草稿 | 最终包对应的实际截图、预告与资产审核，后台完整填写 |
| Steam 安装与更新验收 | 未做 | 私有测试分支实际下载、启动、更新与旧档恢复 |
| Valve 商店和构建审核 | 未提交 | 相应审核回执；上线动作另按用户授权执行 |

Demo 是关联本体的独立 AppID，拥有自己的构建与检查清单；在本体发行前开放 Demo，需要本体的 Coming Soon 页面。独立 Demo 商店页是可选项，若采用，文案与素材只展示 Demo 实有内容；官方要求该页提供预告和至少五张 Demo 截图。[Steam Demo 文档](https://partner.steamgames.com/doc/store/application/demos)

## 商店草稿：冻结包验收后再提交

**工作名称**：雨来之前：采蜜与蜂舞 Demo。最终中英文名与商标/商店唯一性尚未锁定。

**短述草稿**：化身一只小蜜蜂，在花丛间飞行、采集与归巢。把花蜜带回庭院，改善采蜜本领、探索远方花地，再和同伴在灯球下跳一支蜂舞，为雨来之前的生活备好储藏。

**详细介绍草稿**：

在一段轻量的采蜜冒险中，决定这一趟要飞多远、带回多少花蜜。开阔的池岸适合熟悉采集，远方的紫花地带来更高价值的花蜜与新的威胁。观察蚊子的预警，选择绕行或蓄力冲刺，留出回家的余力。

回到庭院，把收获交给蜜铺，查看花路情报，在成长图中挑选下一项改善。更快采集、更大的蜜囊、更远的触角、双簇采蜜和近道，会改变下一趟的路线与停留方式。蜂舞广场连接生活与外出：灯球亮起，蜜蜂以摆尾回环或轻快侧步启程。

本 Demo 包含一处生活庭院、两片采蜜区域、两种花蜜、9 个付费成长节点（共 12 级）和备好花蜜的阶段目标。完成目标后仍可继续探索。提供自动保存、暂停、静音及简化动画选项。

**提交前核对**：上段为 0.22 设计与代码草稿对应的文案，须在最终导出包逐条确认。不要写“三个完整关卡”、固定通关时长、完整生态系统、无限地图、多人、手柄完整支持、Steam Cloud/成就或完整正式版剧情。15–25 分钟目前是内部体验目标，不能当已测卖点。不把参考游戏名、艺人姓名或未进入 Demo 的扩展舞蹈当商店功能宣传。

| 控制 | 行为 |
|---|---|
| WASD / 方向键 | 飞行 |
| E | 靠近生活功能点交互；花丛中按住采蜜 |
| 鼠标 | 采蜜与界面操作 |
| 空格蓄力后松开 | 冲刺；蜂舞转场中按空格跳过表演 |
| F | 使用已点亮的近道 |
| Esc / M | 暂停 / 静音 |
| 成长图的方向键、Tab、Enter | 选择节点、逐级确认购买 |

内容语言目前按简体中文键鼠版准备；其他语言、完整手柄支持与 Steam 平台功能均待独立实现验收。页面素材建议拍：庭院功能全景、首次蓝蜜采集、清楚的蚊子预警、紫花地路线、成长详情与已购能力、蜂舞出发和储备完成。只有最终候选实际运行画面才能作为截图，生成概念图单独标注。

## AI 内容调查与署名草稿

Steam 当前内容调查关注随游戏交付、由玩家消费的生成式 AI 内容，包括美术、声音、叙事和本地化；区分开发期预生成与运行时生成。应按最终包填写，而不是只按所用工具名称勾选。[Steam Content Survey](https://partner.steamgames.com/doc/gettingstarted/contentsurvey)

**预生成披露草稿**：本游戏部分角色、环境与界面美术使用生成式 AI 辅助制作，并经开发过程中的筛选、调整与整合；部分界面和叙事文字使用 AI 辅助起草及修订。内容作为固定资源随游戏发布。

**实时生成披露草稿**：当前候选运行时不调用生成式 AI 服务，不根据玩家输入在线生成图像、文字或声音。提交前检查最终构建和网络行为；若后续增加此类服务，重新填写相应内容及防护说明。

逐项与[资产清单](../../prototypes/swarm-flight/asset-manifest.json)、[美术来源登记](../design/art-source-register.md)核对，并补充模型/生成批次、加工记录、字体、音乐音效及第三方许可。尚未逐项完成最终包音频审查，不能预填“全部音频原创/无 AI 音频”。披露不等于平台批准，也不替代素材权利检查。现阶段署名草稿为“制作：Alan × Codex；Godot Engine（MIT）”，完整 Godot 和随包第三方许可应按实际运行时保留，不只写一句引擎名称。

## macOS 支持范围和证据

本次只读机器信息为 macOS 26.6.2、Apple M1 Pro、arm64、32 GiB 内存。这是测试环境记录，不是最低配置。已有 0.21 内部 macOS 候选的[构建回执](../../prototypes/swarm-flight/review-evidence/2026-11-03/nectar-regions-mvp/build-receipt.json)不能代替 0.22 运行验收；本文件没有新增游戏实机性能测试。

| 商店字段 | 目前可填程度 |
|---|---|
| OS 最低版本 | 待最低版本实机测试，不能沿用 Steam 文档中的历史客户端最低值 |
| 处理器 / 内存 / 图形 | 当前仅有上方开发机器信息，最低与推荐值待测 |
| Intel / Apple Silicon | 导出预设为 Universal；必须用 `lipo` 核对最终二进制，并分别实机验证；Universal 不等于 Intel 已测 |
| 存储空间 | 最终签名、公证后按实际安装体积测量并留更新空间，暂不编造 MB 数 |
| 输入 / 网络 | 键盘鼠标；游戏本地玩法；Steam 获取安装包需要平台网络条件 |
| 显示 / 性能 | 既有 960×600 与 1280×800 内部 UI 检查属前版证据；0.22 重验，未承诺最低帧率 |

Steam 官方 macOS 发布说明要求新应用具有 64 位二进制和 Apple 公证，且 Steam 发行不采用 Mac App Store 的 App Sandbox 配置。Steam overlay/SDK 的加载权限须随实际接入另行配置并验证，不因为模板写了权限就宣称 overlay 已支持。[Steam Platforms](https://partner.steamgames.com/doc/store/application/platforms)

Godot 官方模板导出 Universal 2 `.app`，支持 x86_64 与 arm64；仍须有效 Bundle ID、可执行权限和签名公证。当前源预设里关闭的签名、公证选项只适合内部候选，不能沿用为公开发行证明。[Godot macOS 导出](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_macos.html)

### 签名、公证与验证命令（供持证发行者执行，本轮未执行）

在构建副本上操作；`NECTAR_APP_PATH`、`NECTAR_EXECUTABLE`、`NECTAR_SIGNING_IDENTITY`、`NECTAR_NOTARY_PROFILE`、`NECTAR_NOTARY_ZIP` 必须由发行者设为实际值。凭据留在钥匙串，脚本/仓库不保存密码。优先通过 Godot 的 Xcode codesign / notarytool 导出设置完成；以下手动签名示例适用于没有额外嵌套 framework/helper/dylib 的当前 Godot bundle，增加组件后必须由内向外逐个签名并检查权限。

```sh
lipo -archs "$NECTAR_APP_PATH/Contents/MacOS/$NECTAR_EXECUTABLE"
codesign --force --options runtime --timestamp --sign "$NECTAR_SIGNING_IDENTITY" "$NECTAR_APP_PATH"
codesign --verify --deep --strict --verbose=2 "$NECTAR_APP_PATH"
codesign --display --verbose=4 "$NECTAR_APP_PATH"
ditto -c -k --keepParent "$NECTAR_APP_PATH" "$NECTAR_NOTARY_ZIP"
xcrun notarytool submit "$NECTAR_NOTARY_ZIP" --keychain-profile "$NECTAR_NOTARY_PROFILE" --wait
```

仅在返回 `Accepted` 后继续；超时不能当拒绝或成功，使用返回的真实 submission ID 查询 `notarytool info` / `log`。对 `.app` 装订，再生成发行快照；不要对 ZIP 使用 stapler，不要把签名之后又改动过的资源当原公证包。

```sh
xcrun stapler staple "$NECTAR_APP_PATH"
xcrun stapler validate "$NECTAR_APP_PATH"
codesign --verify --deep --strict --verbose=2 "$NECTAR_APP_PATH"
spctl --assess --type execute --verbose=2 "$NECTAR_APP_PATH"
du -sk "$NECTAR_APP_PATH"
```

保留命令退出状态、公证 ID/状态和最终包 SHA-256；在干净 Mac 上以下载后正常启动流程验证，不把关闭 Gatekeeper 或移除隔离标记当发行测试。[Apple 公证工作流](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)、[Apple notarytool 迁移说明](https://developer.apple.com/documentation/technotes/tn3147-migrating-to-the-latest-notarization-tool)

## 本地 SteamPipe 准备工具

[生成器](../../tools/prepare_nectar_steam_demo.py)与[测试](../../tools/test_prepare_nectar_steam_demo.py)独立于既有 packager。它不调用网络、SteamCMD、签名、公证或发布 API。

无 ID 时可以生成明确不可上传的计划，只有 `NOT_UPLOADABLE.txt` 与 `manifest.json`，不含假数字或可执行 VDF：

```sh
python3 tools/prepare_nectar_steam_demo.py --output /tmp/nectar-steam-plan
python3 tools/prepare_nectar_steam_demo.py --verify /tmp/nectar-steam-plan
```

有经过最终包验收和签名公证的构建后，先创建专用目录，**仅放一个 `.app`**。不能把 `outputs/`、ZIP、证据、旧版本、启动维护脚本或整个工作树当构建目录。签名和 stapling 必须在生成快照前完成。`NECTAR_DEMO_APP_ID` 与 `NECTAR_MACOS_DEPOT_ID` 必须来自真实后台；工具只验证正整数与操作者确认，无法联网认证其归属。

```sh
python3 tools/prepare_nectar_steam_demo.py \
  --build-dir "$NECTAR_CLEAN_BUILD_DIR" --expected-version "$NECTAR_EXPORT_VERSION" \
  --app-id "$NECTAR_DEMO_APP_ID" --depot-id "$NECTAR_MACOS_DEPOT_ID" --ids-confirmed \
  --output "$NECTAR_PREPARED_DIR"
python3 tools/prepare_nectar_steam_demo.py --verify "$NECTAR_PREPARED_DIR"
```

产物为独立 `content/` 副本、SHA-256/大小/权限清单、显式逐文件 depot 映射与 `Preview=1` 的 `app_preview.vdf`。新加文件不会被通配符悄悄包含，检查也会发现内容增加、丢失、变更和权限变更。拒绝多 `.app`、版本不符、缺失执行文件/PCK、符号链接、内部证据目录、日志/凭据/归档和 VDF 注入字符；输出目录不得覆盖现存目录或与输入重叠。该工具不展开不透明 PCK，PCK 的源资源范围必须继续通过现有导出/打包门禁与构建证据验证。

默认只生成 Steam 预览脚本。必须另外传 `--emit-upload-vdf` 才会同时生成 `app_upload.vdf`；仍不会执行上传，脚本不含账户、密码或 `SetLive`。准备目录使用绝对路径，移动后应重新生成。先由真实 SteamCMD 运行预览并核对它的实际清单，再决定上传；本轮没有 SDK/账户验证，不能把 Python 测试当 SteamPipe 已接受 VDF。[SteamPipe 配置与 Preview](https://partner.steamgames.com/doc/sdk/uploading)

后台后续应检查：App 类型为 Demo，关联正确本体；Depot 与 Package 权限对应；启动项取 manifest 的相对 `launch_executable`，平台选择 macOS；私有测试分支从 Steam 安装后能启动；实际下载安装只包含最终 `.app`；更新和存档兼容。只有 macOS 内容时 Depot OS 筛选遵循后台当前配置与官方文档，不机械复制其他多平台项目。所有后台 ID、BuildID、分支、日期及审核结果取得真实回执后再补。

本轮工具验证：`python3 -m unittest tools.test_prepare_nectar_steam_demo -v`；合成假包/假 ID 只存在临时测试目录并自动清理，明确不作为实际游戏或平台身份。覆盖缺 ID、不确认 ID、非法 ID、预览默认、显式上传模板、旧版本、多包、内部文件、符号链接、权限、快照变更、VDF 修改与路径注入。实际 Steam 预览、签名公证与下载安装仍为上方外部事项。
