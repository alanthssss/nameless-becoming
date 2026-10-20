# 雨来之前

独立的 Godot 实时飞行短篇。风把伙伴吹进了卷叶；你带蜂群穿过花桥，在暴雨到来前进入老树的树洞。包含开场、三个连续段落、失误恢复、结尾与重玩。

## 打开

优先打开交付目录中的 `雨来之前.app`。源码可用 Godot 4.6.2 打开本目录的 `project.godot`，或双击 `play.command`。这是独立工程，不读取或覆盖旧游戏存档。

- 方向键或 WASD：连续飞行，八方向等速。
- 按住空格：收拢蜂群并蓄力；出现发光箭头／提示后松开，向当前朝向冲刺。可在蓄力时调整方向。
- 冲刺打开卷叶、撞开干叶帘、击散雨滴；冲进风花会接力加速并转向下一朵。
- 方向提示指向下一组伙伴；带齐伙伴后指向出口。第二段的风花是快捷路线，普通飞行仍可走通。
- Esc：暂停；R：返回就近恢复点；M：声音开关。

救出伙伴及最后一段的叶下避雨处会记录本次游玩的恢复点。关闭应用后可从当前段落开头继续；标题会明确标注。三点体力耗尽会自动恢复，伙伴不会永久丢失。

## 验证

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://verify.gd
godot --headless --path . --script res://ui_verify.gd -- --swarm-qa
godot --headless --path . --quit-after 3 -- --swarm-qa
```

检查退出码、成功标记以及日志中不存在 `SCRIPT ERROR` / `ERROR:`。Godot 有时会在脚本异常后返回 0，因此不能只看退出码。CI 使用独立的 `swarm-flight.yml`，不加载旧年度游戏工程。`verify.gd` 检查完整路线、连续移动、碰撞、雨滴、恢复及畸形存档；`ui_verify.gd` 通过场景输入处理器传入方向键／空格按下和释放，完成三段与可见结尾，并覆盖 WASD、暂停、失焦、重玩、静音。测试只使用自己的存档文件。

图形为代码绘制，声音为原创 PCM 合成，无外部资产或下载依赖。桌面包必须 `all_resources` 导出；配置中的独立 bundle ID 应在首次导出时固定。未做 Windows／Linux 桌面包验收。自动路线和 AI 操作不代表玩家体验通过。

玩法选择与证据记录：[制作说明](../../docs/design/swarm-flight-game-20261020.md)。
