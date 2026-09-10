# 谷雨：最后一张花牌

2026-09-10。Alan 要求实际展示过场插画与动画；Codex 本轮完成谷雨季末这一段，作为后续演出制作的可见参照。采用游戏已认可的简约线条、奶油底色与鼠尾草绿。先生成的密集植物底景被淘汰，最终保留两张稀疏底景，角色、花牌和字幕由 Godot 分层绘制。

## 实现与分镜

全年入口谷雨第十五日收工触发，时长 24 秒；其余 71 段仍是既有共享演出。独立查看：双击 `scripts/play_year_film.command`，不读取或写入游戏进度。空格／点击跳过，结束后空格／点击重播，C 随时重播，Esc 暂停。

| 时间 | 镜头与真实动作 |
| --- | --- |
| 0–5 秒 | 六蜂飞入，雨止，远景建立三张花牌中的空位 |
| 5–10 秒 | 切叶台近景，蚊庄主逐张数牌、转身，露出背上的末牌 |
| 10–16 秒 | 蜜蜂靠近，揭牌并沿连续弧线送至空位；蚊庄主惊讶、道谢，纸叶声与完成音对应动作 |
| 16–24 秒 | 三牌齐全，六蜂错落归巢，镜头轻退，留下“巢里见” |

这是一段拟人故事，不把蚊子管理路牌或蜜蜂编队当作真实昆虫行为。没有旁白录音；复用春季音乐及现有短音效。跳过、暂停、回看不增加进度与奖励。验收由 Alan 观看判断；自动化与截图只是开发者自测。

## 插画文件与生成记录

使用 **内置 imagegen 模式**。以下 PNG 为选中的原始生成结果，未作离线像素编辑；游戏只做缩放与镜头平移。

- [宽景](../../godot/playtest/year/guyu/guyu-wide.png)
- [叶台近景](../../godot/playtest/year/guyu/guyu-close.png)

### 宽景最终编辑提示词

```text
Use case: style-transfer. Edit this background plate ONLY to simplify its rendering substantially to the game's sparse hand-inked lineart aesthetic. Preserve the winding path, hive upper-left, puddle left, and large pale center stage. REMOVE distant human houses, paddies and mountains; replace distant background with pale cream and three simple sage silhouettes. Reduce foliage density by at least 70%, use large clean leaf shapes with one midrib and a few veins. Only a few individual flat wildflowers, no clusters of dozens of tiny flowers. Flat fills only, 6 restrained colors: cream #eee9d7, pale sage #c6ceb0, sage #a6b798, dark ink #45594b, ochre #dfc88a, dusty rose #d5a99b. Fine slightly imperfect ink contours. NO realistic water reflections, NO blur, NO lighting shading, NO painted gradients, almost no grain. Elegant and intentionally sparse like a finished minimalist children's picture book, not a rough sketch. The center lower 60% remains spacious for separately animated characters. No text, no characters, no UI. 16:9.
```

### 近景最终生成提示词

```text
Use case: illustration-story. Finished minimalist lineart storybook illustration as a cinematic close-up background plate for a bee game. Wide 16:9. A broad pale sage leaf forms a gently curved horizontal table/platform across bottom third. One single arching stem and 3 broad shelter leaves at top left, 2 leaf tips top right with a single suspended rain droplet, a few little ochre petals on the table. Upper and central two thirds are mostly warm cream blank stage for large separately animated insect characters, with an extremely faint silhouette of only two distant leaves. Refined sparse composition, delicate dark sage ink lines, flat fills, precisely drawn simple leaf veins, lots of breathing room. Restrict palette to cream #eee9d7, pale sage #c6ceb0, sage #a6b798, dark ink #45594b, ochre #dfc88a, dusty rose #d5a99b. Almost no grain. NO shading, NO realistic lighting, NO gradients, NO blur, NO dense botanical detail, NO watercolor, NO 3D. No insects or characters, no furniture or signs, no text or UI, no frame. This is an elegant final illustration plate for a quiet funny character close-up, not a concept sketch.
```

## 复议与检查点

决定者 Alan 授权制作，Codex 负责分镜、资产选择、实现与自测；本轮 PR 为交付检查点。之后由 Alan 判断笑点是否读得懂、停留节奏是否合适、是否延续喜欢的画风。若仍只感到字幕切换或动作不明，应修改镜头和表演，不能靠增加说明文字替代演出。夏秋冬专属分镜与其余节点插画未在本轮完成。

