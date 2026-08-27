# Journey 营销画面证据说明

本目录把“真实运行画面候选”“画面中使用的生成式美术资产”和“正式商店素材”分开记录，避免用概念图或开发者截图冒充已经通过发行验收的商店物料。

| 路径 | 当前身份 | 能否证明真实玩法 | 正式商店状态 |
| --- | --- | --- | --- |
| `screenshots/*.png` | Godot developer capture | 能，只证明所列工作树和注入状态的真实运行渲染 | 未批准，`store_ready: false` |
| `key-art/see-you-at-the-hive-key-art-base-v1.png` | 生成式美术／概念主视觉候选 | 不能，不是运行画面 | 未批准，不得标作玩法截图 |
| `brand/see-you-at-the-hive-wordmark.svg` | 中英文字标候选 | 不能，是品牌设计资产 | 未批准，需字体、可读性与商标核验 |
| `store-candidates/*` | ImageGen 概念底图 + Godot 精确排字的尺寸候选 | 不能，是品牌／胶囊排版而非玩法 | 未批准，清单明确 `store_ready: false` |

## 当前六张画面的身份

`screenshots/` 中以下 PNG 是 **developer capture（开发者实机采集）**：

| 文件 | 实际运行场景 | 代表状态 |
| --- | --- | --- |
| `01-hive-developer-capture.png` | `hive_threshold` | 四季工作痕迹已写入会话、主巢等待最终交棒 |
| `02-spring-developer-capture.png` | `spring_field` | 春野携蜜与同形散粉路线 |
| `03-summer-developer-capture.png` | `summer_field` | 散落真花蜜、油葫芦家当与待修小蜂房 |
| `04-autumn-developer-capture.png` | `autumn_field` | 逐花收蜜／留种与画眉听声种壳 |
| `05-winter-developer-capture.png` | `winter_field` | 续暖点、大熊搬重木与挡风墙 |
| `06-finale-developer-capture.png` | `finale_handoff` | 完成三步授粉示范并说出题名，冻结在自动返巢前的一帧 |

这些画面由 Godot 直接实例化 `journey.tscn`，经正式 `JourneyAreaRouter` 进入实际 PackedScene，并从 1280×720 运行时帧缓冲保存。HUD、目标、消息、按钮、场景绘制、角色和商业候选资产都是游戏当时真实渲染的内容；采集后没有叠加假 UI、概念角色、宣传特效或图像后期。

为了可重复抵达季节中段，排除在商业导出之外的 developer harness 会使用正式结算 API 建立前序返巢状态，并调用真实情境动作形成代表性进度。它会移动镜头与角色、冻结输入再截图，但不建立另一套营销专用场景。`developer-capture-manifest.json` 保存每张图片的真实场景、尺寸和 SHA-256，并明确标记 `store_ready: false`。

这些证据能证明“当前工作树实际渲染出了什么”，不能证明陌生玩家能理解、喜欢或顺利完成，也不能证明该画面来自干净的候选发行提交。

## 生成式美术与真实截图的区别

运行画面中的部分地图、蜂巢、角色和生态 PNG 来自当前商业美术候选生产流程，其中包含生成式资产及后续透明边、尺寸、导入和运行时适配。它们作为游戏资源被 Godot 实际渲染；因此六张 PNG 是**真实运行截图**，但画面中资产的美术终稿状态仍需授权／来源记录、统一清稿、Alan 验收和候选构建核验。

`key-art/see-you-at-the-hive-key-art-base-v1.png` 是生成式美术／概念主视觉候选，只能用于讨论构图、色彩和品牌方向；它不是 Godot 玩法画面，也没有被计入六张运行截图。生成概念图、单独角色图或地图原图不能放入 `screenshots/` 冒充玩法截图；保留时必须像当前 `key-art/` 一样与运行证据分目录并明确标作 concept／generated art。

`store-candidates/` 是从这张概念底图派生的首轮商店尺寸与透明 Logo 候选。Godot 使用项目 Noto 字体渲染准确中英文，不让图像模型生成文字；`candidate-manifest.json` 固定底图哈希、八个输出尺寸／哈希，并明确记录 `gameplay_screenshot: false`、`store_ready: false` 与 `owner_approved: false`。这些文件可检查品牌层级和裁切，不代表 Steam 页面、商标、美术或发行审核完成。

## 正式商店素材状态

当前六张图不是正式 Steam 商店截图，也没有获得商店发布批准。转为正式商店素材前至少还需要：

1. 从干净、可追溯、通过发行门禁的候选构建重新采集；
2. 完成商业美术终稿、许可清单、字体和平台 UI 核验；
3. 完成键鼠／手柄、不同显示比例和目标平台实机 QA；
4. 获得独立外部玩家证据及 Alan 对画面方向和截图选择的明确验收；
5. 只对真实截图做允许的裁切、调色和商店排版，不替换玩法内容。

六张开发者帧缓冲目前是 1280×720；它们满足 16:9 取景审查，但没有达到当前 Steam 最低 1920×1080 的最终上传规格。不得只靠无证据放大就把它们改标为正式商店截图；应从干净候选构建以目标分辨率重采并重新生成哈希清单。

## 重复采集

采集需要真实 GPU／显示会话，不能加 `--headless`：

```bash
GODOT_BIN="/Applications/Godot 2.app/Contents/MacOS/Godot" \
  ./scripts/capture_journey_screenshots.sh
```

也可以把输出目录作为第一个参数传入。脚本依次采集六个真实场景，再以 headless 验证器检查：文件齐全、均为 1280×720、不是近似空白、六张哈希互不相同，并重写证据清单。

采集实现位于 `godot/tools/`，而当前各平台导出规则已经排除 `tools/**`；本流程不会进入商业资源包。

商店尺寸候选可重复生成：

```bash
GODOT_BIN="/Applications/Godot 2.app/Contents/MacOS/Godot" \
  ./scripts/generate_store_capsules.sh
```

生成器位于 `godot/tools/generate_store_capsules.gd`，同样由商业导出排除；它只组合已登记底图与项目字体，不会修改真实玩法截图。
