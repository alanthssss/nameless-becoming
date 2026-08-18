# 02 · 技术架构 / Technical Architecture

> Godot 4.6 单机核心 + Vite/React Web 承载外壳 + 外部 JSON 数据驱动 · 三端同源导出
> Godot 4.6 standalone core + Vite/React web shell + external JSON data-driven · single-source export to three platforms

---

## 1. 总体架构 / Overall Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                 Godot 4.6 游戏核心 / Game Core               │
│  main.gd · bee_player.gd · sound_feedback.gd · save_manager │
└──────────────┬──────────────────────────┬───────────────────┘
               │ 读取 / reads              │ 导出嵌入 / embeds
┌──────────────▼──────────┐   ┌────────────▼──────────────────┐
│ 数据驱动层 / Data Layer  │   │ Web 承载外壳 / Web Shell       │
│ seasons.json            │   │ app/page.tsx (React 19)       │
│ balance.json            │   │ Vite + RSC + Cloudflare       │
│ upgrades.json           │   └───────────────────────────────┘
└─────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────────────┐
│ 三端同源导出 / Single-source export                          │
│ Web (WASM) · macOS universal · Windows x86_64               │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. 核心代码文件 / Core Files

| 文件 / File | 职责 / Responsibility | 规模 / Scale |
|-------------|----------------------|--------------|
| `godot/scripts/main.gd` | 游戏主循环：关卡、敌人、Boss、UI、结算 | ~41 KB |
| `godot/scripts/player/bee_player.gd` | 玩家飞行控制（加速/惯性/制动模型） | ~4 KB |
| `godot/scripts/sound_feedback.gd` | 程序化音效反馈（采蜜/受击/归巢/四季 BGM） | ~4.6 KB |
| `godot/scripts/save_manager.gd` | 本地 ConfigFile 存档 | ~1.6 KB |
| `app/page.tsx` | Godot Web 版启动外壳（iframe 承载） | 1 组件 |
| `app/globals.css` | 网页承载界面与响应式布局 | — |

---

## 3. 数据驱动层 / Data-Driven Layer

**中文 / CN**：所有游戏数值均外部化到 JSON 文件，调整平衡不需要修改代码。这是 0.9 版本的核心工程决策。

**English / EN**: All game values are externalized to JSON files, so balance tuning requires no code changes. This is the core engineering decision of v0.9.

| 文件 / File | 内容 / Contents | 示例字段 / Example Fields |
|-------------|-----------------|---------------------------|
| `seasons.json` | 四季节令参数 | 阴阳比例 yin/yang、目标蜜量 goal、花量 flowers、敌人 enemies、体力消耗 energy_drain、配色 colors |
| `balance.json` | 数值平衡 | 玩家采蜜/惊退成本、蚊虫感知/速度、掠蜜蚁偷蜜、Boss 调律半径 |
| `upgrades.json` | 蜂巢成长选项 | 长翼蜂 long_wing、采蜜蜂 forager、守卫蜂 guard |

---

## 4. Web 承载外壳 / Web Shell

**中文 / CN**：Web 端不是第二套玩法代码，而是 Godot Web 导出的承载外壳。启动页嵌入 `<iframe src="/game/index.html">`，由 React 19 + Vite + RSC 构建，部署于 Cloudflare Workers。

**English / EN**: The web build is not a second set of gameplay code — it is a shell that hosts the Godot Web export. The launch page embeds `<iframe src="/game/index.html">`, built with React 19 + Vite + RSC and deployed on Cloudflare Workers.

- **启动流程 / Launch flow**：点击"启动 Web 版" → 浏览器允许自动播放音乐 → iframe 加载 Godot WASM
- **传输分片 / Transfer sharding**：WASM 超过 Sites 单文件限制，发布时拆为两个分片，浏览器加载时重新组装；只改变传输方式，不产生第四套游戏代码

---

## 5. 自动测试 / Automated Tests

| 测试 / Test | 覆盖范围 / Coverage |
|-------------|---------------------|
| `godot/tests/smoke_test.gd` | 数据结构、场景加载、核心公式（含节令数据自动检查） |
| `godot/tests/flow_test.gd` | 无存档副作用的全流程状态测试（结算、标题、游玩时长） |
| `tests/rendered-html.test.mjs` | Web 外壳渲染的 HTML 检查（`npm run test`） |

**运行方式 / How to Run**：

```bash
# Godot 单机测试 / Standalone tests
godot --path godot --headless --script res://tests/smoke_test.gd
godot --path godot --headless --script res://tests/flow_test.gd

# Web 外壳 / Web shell
npm install
npm run dev     # 本地开发 / local dev
npm run build   # 构建 / build
npm run test    # 渲染测试 / render test
```

---

## 6. 三端导出 / Three-Platform Export

**中文 / CN**：Web、macOS universal、Windows x86_64 三端均由同一个 Godot 工程导出，不再分别维护网页玩法代码。macOS 包在导出后重新临时签名，正式公开发行仍需 Apple Developer ID 签名与公证。

**English / EN**: Web, macOS universal, and Windows x86_64 are all exported from the same Godot project; web gameplay code is no longer maintained separately. The macOS package is re-signed ad hoc after export; public release still requires Apple Developer ID signing and notarization.

| 平台 / Platform | 产物 / Artifact | 说明 / Note |
|-----------------|-----------------|-------------|
| Web | `public/game/` | WASM 双分片传输 |
| macOS | `builds/*.zip` (universal) | 临时签名验证通过 |
| Windows | `builds/*.exe` | x86_64 调试包 |

---

## 7. 工程与依赖 / Tooling & Dependencies

| 层 / Layer | 技术 / Tech | 版本 / Version |
|-----------|-------------|----------------|
| 游戏引擎 / Game engine | Godot | 4.6.2+ |
| Web 框架 / Web framework | React + Vite + RSC | React 19.2 |
| 构建 / Build | vinext + wrangler | vinext 1.0.0-beta.2 |
| 数据库 ORM / DB ORM | Drizzle | 0.45.2 (SQLite, 预留) |
| 部署 / Deploy | Cloudflare Workers + Sites | — |
