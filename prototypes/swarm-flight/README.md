# 雨来之前 · 全关卡统一美术包 0.9.0

Alan认可05「花篱另一边」的风格方向，并要求补齐尚未统一的元素，再应用到每一个关卡。0.9.0沿用这套独立绘制资产，将角色、植物、实体地形、天气、拾取物、出口、标志与四区背景接入16关。地图、模型、音乐及普通存档格式保持；本轮是表现整合，不增加关卡或机制。

本轮技术检查与构建状态统一见`outputs/swarm-flight/2026-10-23-art-rollout/build-receipt.json`。本文不预填未完成的检查数字；旧版自检不计作0.9.0通过。05方向认可与新版整包实玩验收分开，也不宣称已达到PVZ或商业成品完成度。[授权与边界 SF-R28](../../docs/design/swarm-flight-game-20261020.md#art-rollout-20261023)。

## 打开这一版

交付目录为`outputs/swarm-flight/2026-10-23-art-rollout/`，主包为「雨来之前·统一美术.app」。完整试玩入口为「开始完整试玩.command」，使用独立的`before_the_rain_art_full_20261023.json`进度。目录另提供05快速入口；具体文件、启动与验证结果以最终回执为准。两个入口均已生成；05快速入口为「开始05试玩.command」，另用独立quick进度。

完整入口从标题进入；Enter从春天开始，Tab循环选择春／夏／秋／冬后Enter出发。选章会重开该入口使用的当前旅程；要保留进度，应选择继续。Godot 4.6.2可直接打开本目录`project.godot`，或运行`play.command`；默认开发入口仍使用常规v2旅程，不等同独立评审入口。

这是独立飞行工程，不启动旧年度工程。0.8.1的05样板包、0.8.0完整包及更早构建保留为历史对照。

## 四季与素材安排

| 区域 | 关卡 | 主要判断与表现 |
|---|---|---|
| 春 · 归家 | 01–04 | 飞行、解救、连续借风、追雨与第一次归家；春季菜圃背景、同族茎干与救援荚 |
| 夏 · 花篱外 | 05–08 | 花篱两路、喷泉时机与绕行；复用已认可的夏季庭院，补齐喷嚏花和喷口 |
| 秋 · 旧果园 | 09–12 | 箱角转向、穿帘与绕箱；秋季果园背景、木箱材质与干叶帘 |
| 冬 · 暖廊与老树 | 13–16 | 持续气流、台下避风、熟悉元素组合与尾声；冬季暖廊背景、台面与风源 |

新增素材为terrain、flora、landmarks、weather四家族和保持自然比例的独立树屋，新增春／秋／冬背景并复用夏景；已有蜂体、风花、叶冠和花篱继续共用。完整提示与生成来源见`art/rollout-provenance.json`，05原资产见`art/provenance.json`；适用关卡、共有／区域／专属分类、状态映射和最终哈希见`asset-manifest.json`。方向箭头、文字、危险范围、护雨计时和粒子由引擎按模型绘制。

普通终点演出2.4秒，章节边界4.5秒。穿过花铃叶拱／树洞立即完成并保存，演出不耗体力或计时；Enter可提前继续，Esc或失焦暂停。04归家后进入夏天，16才是整作结尾。小满和画眉在安全落脚点回应，同伴不跟飞、不新增碰撞或损耗。05来向对白读取真实路线记录，无证据旧档使用中性回应。

## 操作与规则

- 方向键／WASD飞行；空格按住约0.4秒，光环亮起后松开冲刺。长按不会额外增加距离。
- 冲刺可救伙伴、借风、冲开干叶帘、击散雨滴和安抚喷嚏花；实心茎干、花篱、果箱和台面需要绕行。
- 宽叶亭依次保存并以每秒24体力恢复；不强制等满，两条分路共用落脚点。
- 飞行每秒耗2体力，冲刺耗20；晨露最多恢复12，救援最多恢复40，风花最多恢复8。界面报告实际恢复值。
- 固定的晨露是补给；向下移动的雨滴和喷嚏水珠会伤体力。雨关有后方雨幕与独立露天预算，叶下暂停；普通关显示旅程计时。
- 喷泉有停喷、提前0.8秒预告、喷发三个状态；喷发时普通接触损失12体力，可等空档、冲刺穿过或从另一侧绕行。
- 局部气流持续推动普通飞行、松键和蓄力；方向键可逆风修正，冲刺保持方向。离开风区即停止受风，叶亭和起飞／恢复后等待输入时保持安稳。实心地形挡落雨，但不提供叶亭的回血、存档或追雨暂停。
- 护雨叶保护5秒，可挡雨、喷泉与喷嚏，仍耗飞行／冲刺体力和露天时间，不能穿实心墙。
- R回到最近落脚点；Esc暂停；M开关声音。暂停同时冻结游戏与演出。

## 进度与兼容边界

完整美术试玩入口使用独立的`before_the_rain_art_full_20261023.json`，与常规`before_the_rain_journey_v2.json`分离。默认开发入口仍沿用0.7.x／0.8.x的v2格式（version 6 / content_revision 8）；本轮没有改模型、关卡对象数量／顺序或存档格式。不读取、迁移或覆盖0.6.0的v1及旧四关chapter v4文件。最终入口的实际隔离与继续结果应查本批回执，格式未改不能代替恢复验证。

关中继续回到已存宽叶亭，已穿过终点则进入下一关；16关完成后可重看结尾。选章会重开当前入口的旅程，收集不锁出口，结束统计只反映这趟旅程。春天救援分布仍为4／2／1／1，后续角色只是邻居，伙伴总数仍8只。

历史0.8.0曾使用实际0.7.1打包PCK生成05起点／叶亭／抵达的10份档案，逐份恢复后以模型普通输入继续到下一叶或终点，未读写个人存档；这不是0.9.0已重复验证的声明。

## 开发验证与证据

```sh
godot --headless --path prototypes/swarm-flight --editor --import --quit
godot --headless --path prototypes/swarm-flight --script res://verify.gd
godot --path prototypes/swarm-flight --script res://ui_verify.gd -- --swarm-qa
godot --headless --path prototypes/swarm-flight --script res://audio_verify.gd
```

模型检查覆盖16关路线、安全存档点、资源与终点边界；UI检查通过Viewport分发实际方向键和空格，检查连续旅程、衔接、结尾、暂停及继续。`route_driver.gd`知道路线答案，既不是独立玩家证据，也不能用其时间推算真人首通。`--swarm-qa`隔离真实进度；截图路径由`SWARM_FLOW_CAPTURE_DIR`指定。

本批已通过1577项模型检查、538项原生界面检查和24项明确状态夹具检查；两趟16关普通输入路线贯通、保存继续通过。导出PCK挂载到同版本编辑器运行同一原生输入套件，也通过538项；独立release应用完成启动截图。140项气流基线、2类旧缺陷反证、8项反证工具测试、11项交付检查器测试及音频PCM检查通过。导出PCK的QA结束有ObjectDB实例泄漏警告，独立release启动没有该警告。四区画面、缩放、状态提示与碰撞可读性已作开发者复核，不能代替玩家评价。1280×800逻辑画面保比例缩放，Compatibility渲染；素材与状态绘制由`world_view.gd`、`art_sprites.gd`、`art_props.gd`和`sample_landscape.gd`协作。音乐仍由`sound.gd`原创合成。

历史0.8.1有1577项模型检查、538项完整原生UI检查、最终05定向89项；这些仅说明当时版本的开发者自检，不证明0.9.0通过或整作美术获验收。Windows／手柄／Steam／独立玩家验证、自然首通2～3小时目标与可靠整作预测仍待完成。

### 回归与交付边界

```sh
python3 -B -m unittest discover -s tests -p 'test_*regressions.py'
python3 -B -m unittest discover -s tests -p test_delivery_gate.py
python3 scripts/check_swarm_regressions.py --godot /absolute/path/to/godot
python3 tools/check_delivery.py --contract prototypes/swarm-flight/delivery-contract.json \
  --receipt /absolute/path/delivery-receipt.json --evidence-root /absolute/path/evidence \
  --revision FULL_FROZEN_COMMIT --expect candidate
```

旧缺陷反证在隔离副本运行；交付工具核对同包证据，不因测试数量或文件存在就代签产品验收。当前制作沿用SF-R23、SF-R25与唯一Now：200＋40小时控制量、一次集中修订和既定日期不重置；本次明确授权解除的是仅05样板的推广限制。
