# 雨来之前 · 05美术修订候选 0.8.1

05「花篱另一边」试用独立绘制的蜂体、风花、叶冠、花篱与庭院背景，搭配状态驱动动画与紧凑HUD。此版回应Alan对0.8.0美术的否定；仅05换用新资产，其他15关仍保留0.8.0表现，不能称作全篇美术完成或已达到PVZ品质。

本批入口：`outputs/swarm-flight/2026-10-23-art-revision/开始05美术试玩.command`。直接进入05，使用独立美术评审存档，不覆盖常规v2旅程；方向键／WASD飞行，空格蓄力后松开冲刺，Esc暂停。完整16关代码仍在，模型、地图、音频和普通存档格式没有改动。新资产来源、完整提示与技术尺寸见`art/provenance.json`及`asset-manifest.json`。本轮产品判断见主设计文档[SF-R27](../../docs/design/swarm-flight-game-20261020.md#art-quality-revision-20261023)。

以下为0.8.0完整包的操作与历史验证记录，不能视为0.8.1的新验证；本批实际结果以同目录`build-receipt.json`为准。

## 0.8.0完整包基线

四区16关现已连接为从标题到结尾的完整开发版。保留春天四关的飞行、救援、蓄力冲刺、连续借风、追雨与三首音乐；夏、秋、冬十二关已按真实地形、喷泉择时和局部气流重排，共60个手工遭遇。它是全篇Alpha，商业美术、真人首通时长和发行验收尚未完成。

01「晨光菜圃」与05「花篱另一边」加入原生绘制的画面样板，保留已选植物卡通方向。05开头现在能看见共同叶亭；末段收成短抵达，减少同关重复分叉。小满按实际走过的上下路回应，旧档无来向证据时使用中性对白。全篇16关、60遭遇仍可从标题玩到结尾；其余14关世界美术仍为Alpha。这次是实机样板，尚未通过成品审美验收。

## 打开这一版

macOS 包：`outputs/swarm-flight/2026-10-23-visual-sample/雨来之前·四季旅程.app`。双击同目录「开始试玩.command」，标题应为「雨来之前 · 四季旅程 Alpha 0.8.0」。Enter从春天开始；标题页Tab循环选择春／夏／秋／冬，随后Enter出发。选择后续章节会开始一趟新旅程；要保留当前旅程，选择继续存档。

Godot 4.6.2可直接打开本目录`project.godot`，或运行`play.command`。这是独立飞行工程，不启动旧年度工程。旧0.6.0、0.5.2及更早包保留。

## 四季的安排

| 区域 | 关卡 | 主要判断 |
|---|---|---|
| 春 · 归家 | 01–04 | 学会飞行、解救伙伴、连续借风、甩开追雨，回到老树 |
| 夏 · 花篱外 | 05–08 | 花篱真正分隔上下路；喷泉短路要看时机，安全绕路需要换高度 |
| 秋 · 旧果园 | 09–12 | 实体果箱改变转向与接力落点；穿帘短道花一次冲刺，箱外绕路多飞一段 |
| 冬 · 暖廊与老树 | 13–16 | 上升、迎面和下压气流实际影响飞行；台下避风；15组合已学元素，16短尾声 |

章节边界有4.5秒季节衔接，普通终点2.4秒。穿过花铃叶拱／树洞就立即完成并保存；落脚演出不再耗体力或计时。Enter可提前继续，Esc或失焦暂停。04是春天归家，16才是整作结尾。

小满和画眉在安全落脚点作简短回应；同伴不跟飞、不新增碰撞或雨滴损耗。枯花、果园牌和带灯罩的灯仅作场景标识；实心花篱、果箱、台面会挡路，箭头风区会影响普通飞行，风花仍需冲刺触发。

## 操作与规则

- 方向键／WASD飞行；空格按住约0.4秒，光环亮起后松开冲刺。长按不会额外增加距离。
- 冲刺可救伙伴、借风、冲开干叶帘、击散雨滴和安抚喷嚏花；实心茎干、花篱、果箱和台面需要绕行。
- 宽叶亭依次保存并以每秒24体力恢复；可以直接继续，不强制等满。两条分路共用落脚点。
- 飞行每秒耗2体力，冲刺耗20；晨露最多恢复12，救援最多恢复40，风花最多恢复8。界面报告实际恢复值。
- 灰雨滴、喷嚏水珠伤体力，棱面晨露是补给。雨关有后方雨幕与独立露天预算，叶下暂停；普通关显示旅程计时。
- 喷泉有停喷、提前0.8秒预告、喷发三个状态；喷发时普通接触损失12体力，可等空档、冲刺穿过或从另一侧绕行。
- 进入局部气流后，普通飞行、松键和蓄力都会持续受风推动；方向键可逆风修正，冲刺保持方向，离开风区即停止受风。叶亭与尚未起飞／恢复后等待输入时保持安稳。提示区分接近与实际受风，蜂身风线只在真实风区内绘制。实心地形能挡落雨，但不提供叶亭的回血、存档或追雨暂停。
- 护雨叶保护5秒，可挡雨、喷泉与喷嚏，仍耗飞行／冲刺体力和露天时间；不能穿实心墙。
- R回到最近落脚点；Esc暂停；M开关声音。暂停会冻结游戏与演出。

## 进度

0.8.0继续使用0.7.0／0.7.1的文件`before_the_rain_journey_v2.json`（version 6 / content_revision 8）。不读取、迁移或覆盖0.6.0的`before_the_rain_journey_v1.json`与旧四关`before_the_rain_chapter_v4.json`；旧包仍能继续各自进度。历史0.7.0验证为54份样本；本次从实际0.7.1打包PCK生成05起点／叶亭／抵达的10份档案，逐份恢复到新布局并继续到下一叶或终点，原个人存档未改。春天救援仍为4／2／1／1，后续角色只是邻居，伙伴总数仍8只。

关中继续回到已存宽叶亭；已穿过终点则进入下一关；16关完成后可重看结尾。收集不锁出口。标题选章会重开当前Alpha旅程（与0.7.0／0.7.1共用v2进度）；旧v1和四关存档保留；结束页统计只反映这趟旅程。

## 开发验证

```sh
godot --headless --path prototypes/swarm-flight --editor --import --quit
godot --headless --path prototypes/swarm-flight --script res://verify.gd
godot --headless --path prototypes/swarm-flight --script res://ui_verify.gd -- --swarm-qa
godot --headless --path prototypes/swarm-flight --script res://audio_verify.gd
```

模型检查覆盖全16关直达／全露路线、所有安全存档点、分路互斥、资源守恒、终点和存档边界；首章另跑无护雨、穿亭不停满、救援后回退三条回归路线。`--new-levels`可单独验证后12关的24条路线，并检查没有撞实体或硬吃喷泉伤害。`--season-elements-only`检查新增规则边界，`--content-only`检查风花落点、拾取与实体／叶亭的布局关系。UI检查用Viewport分发真实方向键和空格，连续完成16关，检查15次衔接、完整结尾、暂停、选章、跨季保存继续和写盘失败提示。

`route_driver.gd`知道所有答案，仅提供普通按键，不修改模型、地图、资源或位置；它不代表玩家乐趣或真人首通时长。原生截图用`SWARM_FLOW_CAPTURE_DIR`；`--swarm-qa`隔离真实进度，存档验证只写独立临时路径。每次交付事实见主设计文档SF-R21和输出目录`build-receipt.json`。

美术由`world_view.gd`及两关的`sample_landscape.gd`程序绘制，音乐由`sound.gd`原创合成，来源与哈希见`asset-manifest.json`。1280×800逻辑画面保比例缩放；macOS universal包排除测试脚本。四季背景与角色仍是Alpha美术，未通过商业成品审美验收。Windows／手柄／Steam／独立玩家验证待后续完成；首通2～3小时仍是未验证的商业制作目标。

0.7.1修复绕过风花普通入风后松键不受风的问题；13／14两处上升风边界移出台面，13-2风花冲刺穿逆风保留。验证包含1533项模型检查、449项原生完整UI检查、24条后续关卡路线及真实按键入风复现。记录见主设计文档SF-R22；截图中的明确UI状态样本与连续输入路线分别标注。

### 防止同类回归与交付偏离

```sh
python3 -B -m unittest discover -s tests -p 'test_*regressions.py'
python3 -B -m unittest discover -s tests -p test_delivery_gate.py
python3 scripts/check_swarm_regressions.py --godot /absolute/path/to/godot
python3 tools/check_delivery.py --contract prototypes/swarm-flight/delivery-contract.json \
  --receipt /absolute/path/delivery-receipt.json --evidence-root /absolute/path/evidence \
  --revision FULL_FROZEN_COMMIT --expect candidate
```

前两项测试工具；第三项在临时隔离副本恢复两个已知风区缺陷，必须被指定行为断言抓住，不修改实际工程／进度。最后一项检查SF-R23整包证据，缺少内容、美术、制作实耗时必须失败；维护通过不等于候选或用户验收。receipt字段及边界见已安装的`godot-production-workflow/references/quality-gates.md`，代码为该自有技能的同步副本。CI会运行工具回归，不自动把当前游戏记为候选。根因与机制见SF-R24；SF-R24维护时没有新包；0.8.0样板与全篇复核另见主设计文档SF-R26。

样板定向检查：`godot --path prototypes/swarm-flight --script res://ui_verify.gd -- --swarm-qa --sample-visuals-only`；实际模型来向检查：`godot --headless --path prototypes/swarm-flight --script res://verify.gd -- --sample-approach-only`。原生截图来自真实按键驱动，另有960×600窗口采样；已知答案路线不代表真人首通、偏好或商品时长。
