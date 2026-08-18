# 无名：成蜂 · Nameless: Becoming

一款以蜜蜂生态、四季循环与东方节气为核心的轻量“搜、打、撤”肉鸽游戏原型。

> 再采一朵，还是现在归巢？

## 在线试玩

[https://hivebound-seasons-game.pages.dev](https://hivebound-seasons-game.pages.dev)

## 当前版本：Godot 候选 MVP 0.9.4

当前维护三个发行端：Web、macOS universal、Windows x86_64。三端均由同一个 `godot/` 工程导出，不再分别维护网页玩法代码。

正式单机方向已转入 Godot 4。玩家直接控制蜜蜂在花田中飞行：

- **搜**：寻找仍有花蜜的花朵，越远通常收益越高；
- **驱**：用震翼让近身敌虫实际惊退；蜂针不是普通攻击；
- **撤**：在体力耗尽前亲自飞回左侧蜂巢，携带的蜜才会转化为储备；
- **循环**：四季大关 × 6 小关（24 个节气节点），四正色（春分/夏至/秋分/冬至）为守关 Boss 节点。

### 操作

| 操作 | 键盘 | 触摸设备 |
| --- | --- | --- |
| 移动 | WASD / 方向键 | 点击花田移动 |
| 采蜜 | I / 按住空格 | 点击界面按钮 |
| 冲刺 | O / Shift | 点击界面按钮 |
| 震翼惊退 | J | 点击界面按钮 |
| 触角寻迹 | U / E | 点击界面按钮 |
| 急转闪避 | K | 点击界面按钮 |
| 投蜜诱饵 | L | 点击界面按钮 |

## 设计方向

游戏不是单纯的昆虫战斗，也不是传统经营模拟。核心张力来自：

```text
发现稀有花
→ 停留采集
→ 危险靠近、体力下降
→ 决定继续贪、战斗或撤退
→ 带着资源亲自飞回蜂巢
```

视觉以二十四节气阴阳消长色系组织（四正色：玄/青/朱/白），四季大关 × 6 小关逐阶渐变色调，两至两分（春分/夏至/秋分/冬至）为守关 Boss 节点。完整色谱见 [`docs/COLOR_SYSTEM.md`](docs/COLOR_SYSTEM.md)。

## 开发

正式单机版需要 Godot 4.6 或更高版本：

```bash
godot --path godot --editor
godot --path godot --headless --script res://tests/smoke_test.gd
```

Web 端由 Godot 导出后，通过 Node.js 站点外壳承载：

```bash
npm install
npm run dev
npm run build
```

主要实现位于：

- `godot/`：正式单机版工程；
- `godot/scripts/main.gd`：Godot 核心游戏循环；
- `godot/data/seasons.json`：节令数据（含四季机制槽位 mechanics）；
- `godot/scripts/mechanics/`：四季招牌机制（授粉/征召/储备/抱团）与调度层；
- `app/page.tsx`：Godot Web 版启动外壳；
- `public/game/`：与桌面端同源的 Godot Web 导出；
- `app/globals.css`：网页承载界面与响应式布局；
- `docs/COLOR_SYSTEM.md`：二十四节气色彩体系（四正色 + 四季六阶色谱）；
- `docs/PROJECT_LOG.md`：策划与版本决策记录。
- `docs/MVP_SPEC.md`：完整 MVP 范围、验收标准与里程碑。

## 当前验证问题

1. 飞行与采蜜是否让玩家感觉自己在控制一只蜜蜂？
2. 蚊虫靠近时，是否会产生“再采一点还是立即撤退”的犹豫？
3. 四个压缩节令的压力变化是否清晰？
4. 失败后是否愿意马上再进行一次循环？

项目仍处于早期原型阶段。当前代码与美术不代表最终品质，所有系统都服务于验证核心互动。
