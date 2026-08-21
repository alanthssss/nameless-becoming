#!/usr/bin/env python3
"""推演《无名：成蜂》24 节令富余度（当前 vs 批次1提案）。

按真实公式 nectar = max(2, roundi(base_nectar * nectar_scale)) 计算每关
期望总蜜量，输出富余倍数（期望总蜜/目标）、可跳过花数，并校验两条测试约束：
  1. flow_test 最坏情形: flowers * 2 >= goal   （所有花都roll到下限2滴）
  2. smoke_test 下限:     flowers * maxi(2, roundi(3*scale)) >= goal

用法:
  python3 scripts/difficulty_table.py table    # 当前 vs 提案对照表
  python3 scripts/difficulty_table.py validate <seasons.json>  # 校验已编辑文件
"""
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "godot" / "data"

# 批次1提案（只改 flowers 数量与雨水/惊蛰的蚊子数，其余字段不动）
PROPOSAL = {
    "冬至": {"flowers": 6},
    "小寒": {"flowers": 6},
    "大寒": {"flowers": 7},
    "立春": {"flowers": 7},
    "雨水": {"flowers": 7, "mosquitoes": 2},
    "惊蛰": {"flowers": 7, "mosquitoes": 2},
    "清明": {"flowers": 7},
    "谷雨": {"flowers": 7},
    "立夏": {"flowers": 7},
    "小满": {"flowers": 6},
    "芒种": {"flowers": 6},
    "小暑": {"flowers": 6},
    # 大暑/立秋/处暑/白露/寒露~大雪 不动：处暑/白露受 flow_test 下限钳制
    # （6花×2滴=12 = goal 12，已是边界），寒露以后本就 1.05–1.4x。
}


def load_json(name: str):
    with open(DATA / name, encoding="utf-8") as f:
        return json.load(f)


def per_flower_avg(flower_set: dict, scale: float) -> float:
    """加权平均单花蜜量（含 min-2 下限与 roundi 取整）。"""
    total_w = 0.0
    acc = 0.0
    for t in flower_set["types"]:
        base = float(t["nectar_base"])
        w = float(t["weight"])
        nectar = max(2, math.floor(base * scale + 0.5))  # roundi 即四舍五入（半值远离零）
        acc += w * nectar
        total_w += w
    return acc / total_w if total_w else 0.0


def stage_rows(seasons, flower_sets, overlay: dict) -> list:
    rows = []
    for idx, st in enumerate(seasons):
        if "boss" in st:
            rows.append({"index": idx, "name": st["name"], "boss": True})
            continue
        name = st["name"]
        fset_id = st.get("flower_set", "")
        fset = flower_sets.get(fset_id) if fset_id else flower_sets.get(
            {"冬": "winter", "春": "spring", "夏": "summer", "秋": "autumn"}[st["season"]])
        avg = per_flower_avg(fset, float(st["nectar_scale"])) if fset else 0.0
        goal = int(st["goal"])
        flowers = int(st["flowers"])
        mosquitoes = int(st.get("mosquitoes", 0))
        if overlay and name in overlay:
            flowers = int(overlay[name].get("flowers", flowers))
            mosquitoes = int(overlay[name].get("mosquitoes", mosquitoes))
        field = avg * flowers
        ratio = field / goal if goal else 0.0
        skip = flowers - math.ceil(goal / avg) if avg > 0 else flowers
        rows.append({
            "index": idx, "name": name, "season": st["season"],
            "goal": goal, "flowers": flowers, "avg": avg,
            "mosquitoes": mosquitoes, "ants": int(st.get("ants", 0)),
            "crickets": int(st.get("crickets", 0)),
            "bears": int(st.get("bears", 0)),
            "field": field, "ratio": ratio, "skip": skip,
            "flow_min_ok": flowers * 2 >= goal,
            "smoke_min_ok": flowers * max(2, round(3.0 * float(st["nectar_scale"]))) >= goal,
        })
    return rows


def print_rows(rows, title: str, only_delta: bool = False):
    print(f"\n=== {title} ===")
    print(f"{'节令':<4}{'段':<3}{'目标':>4}{'花数':>4}{'单花':>5}{'总蜜':>6}{'倍数':>6}{'可跳':>4}{'蚊':>3}{'蚁':>3}{'蟋':>3}{'熊':>3}  约束")
    for r in rows:
        if r.get("boss"):
            print(f"{r['name']:<4} BOSS")
            continue
        cons = []
        if not r["flow_min_ok"]:
            cons.append("flow下限✗")
        if not r["smoke_min_ok"]:
            cons.append("smoke下限✗")
        if not cons:
            cons.append("OK")
        print(f"{r['name']:<4}{r['season']:<3}{r['goal']:>4}{r['flowers']:>4}"
              f"{r['avg']:>5.2f}{r['field']:>6.1f}{r['ratio']:>6.2f}{r['skip']:>4}"
              f"{r['mosquitoes']:>3}{r['ants']:>3}{r['crickets']:>3}{r['bears']:>3}  {'/'.join(cons)}")


def main() -> int:
    seasons = load_json("seasons.json")
    flower_sets = load_json("flowers.json")
    mode = sys.argv[1] if len(sys.argv) > 1 else "table"

    if mode == "table":
        cur = stage_rows(seasons, flower_sets, None)
        prop = stage_rows(seasons, flower_sets, PROPOSAL)
        print_rows(cur, "当前（main）")
        print_rows(prop, "批次1提案", only_delta=True)
        print("\n=== 变化明细（当前 → 提案）===")
        for c, p in zip(cur, prop):
            if c.get("boss"):
                continue
            changes = []
            if p["flowers"] != c["flowers"]:
                changes.append(f"花 {c['flowers']}→{p['flowers']}")
            if p["mosquitoes"] != c["mosquitoes"]:
                changes.append(f"蚊 {c['mosquitoes']}→{p['mosquitoes']}")
            if changes:
                print(f"{c['name']:<4} 倍数 {c['ratio']:.2f}→{p['ratio']:.2f}  可跳花 {c['skip']}→{p['skip']}  {'；'.join(changes)}")
        return 0

    if mode == "validate":
        path = Path(sys.argv[2])
        with open(path, encoding="utf-8") as f:
            seasons = json.load(f)
        rows = stage_rows(seasons, flower_sets, None)
        bad = [r for r in rows if not r.get("boss") and not (r["flow_min_ok"] and r["smoke_min_ok"])]
        print_rows(rows, f"已编辑文件 {path.name}")
        if bad:
            print(f"\n✗ {len(bad)} 个节令违反约束: {[r['name'] for r in bad]}")
            return 1
        print("\n✓ 全部采蜜关通过两条下限约束")
        return 0

    print("用法: table | validate <seasons.json>")
    return 2


if __name__ == "__main__":
    sys.exit(main())
