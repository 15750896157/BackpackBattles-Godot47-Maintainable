"""物品数值单一视图生成器（正式工具）。

用法：
    py -3 tools/build_item_stats_view.py          # 检查模式，视图过期则报错退出 1
    py -3 tools/build_item_stats_view.py --write  # 重新生成视图

为什么要有它：
    物品数值分散在 items.csv（静态数值）与 item_effects.csv（效果数值）两处。
    本工具把它们合成一份只读索引，让「一件物品的全部数值」在一个文件里看得全。
    源表永远是唯一真源；本视图只可重新生成，不可手改。

与其他工具的配合：
    import_content.py 编译 content.json 时不会碰本视图；
    validate_content.py 校验源表合法性；
    本工具校验「视图是否与源表同步」。
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "project"
TABLES = PROJECT / "PvE/Rules/content/tables"
VIEW = ROOT.parent / "报告/04_重构与优化/物品数值统一视图_20261118.json"
FORMAT = "backpack-pve-item-stats-view"


def load(name: str) -> list:
    with (TABLES / name).open(encoding="utf-8-sig") as stream:
        return list(csv.DictReader(stream))


def num(value):
    if value is None:
        return None
    text = str(value).strip()
    if text == "":
        return ""
    try:
        return int(text) if text.lstrip("-").isdigit() else float(text)
    except ValueError:
        return text


def build() -> dict:
    items = load("items.csv")
    effects = load("item_effects.csv")
    shapes = {row["id"]: row for row in load("item_shapes.csv")}
    by_item: dict = {}
    for effect in effects:
        by_item.setdefault(effect["item_id"], []).append(effect)
    for rows in by_item.values():
        rows.sort(key=lambda row: int(row["sequence"]))

    view = {
        "format": FORMAT,
        "version": 1,
        "note": "只读视图，由 items.csv + item_effects.csv 生成；源表是唯一真源，禁止手改本文件。",
        "sources": ["items.csv", "item_effects.csv", "item_shapes.csv"],
        "item_count": len(items),
        "items": [],
    }
    orphans = []
    for item in items:
        item_id = item["id"]
        rows = by_item.get(item_id, [])
        if not rows:
            orphans.append(item_id)
        shape = shapes.get(item["shape_id"], {})
        view["items"].append({
            "id": item_id,
            "name_key": item["name_key"],
            "rarity": item["rarity"],
            "base_price": num(item["base_price"]),
            "cooldown": num(item["cooldown"]),
            "stamina_cost": num(item["stamina_cost"]),
            "shape_id": item["shape_id"],
            "shape_cells": shape.get("cells") or shape.get("shape") or None,
            "tags": item["tags"],
            "owner_pool": item["owner_pool"],
            "shop_enabled": item["shop_enabled"],
            "crafted_only": item["crafted_only"],
            "power_score": num(item["power_score"]),
            "icon_ref": item["icon_ref"],
            "vfx_ref": item["vfx_ref"],
            "effects": [{
                "sequence": int(row["sequence"]),
                "trigger_id": row["trigger_id"],
                "effect_type": row["effect_type"],
                "effect_params": row["effect_params"],
                "condition_id": row["condition_id"],
                "condition_params": row["condition_params"],
                "target_selector": row["target_selector"],
                "spatial_template_id": row["spatial_template_id"],
                "internal_cooldown": num(row["internal_cooldown"]),
                "chain_depth_cost": num(row["chain_depth_cost"]),
            } for row in rows],
        })
    unknown = sorted({row["item_id"] for row in effects} - {item["id"] for item in items})
    for item in view["items"]:
        assert item["id"], "物品缺 id"
    return {"view": view, "orphans": orphans, "unknown_effect_items": unknown}


def digest_of(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="重新生成视图文件")
    args = parser.parse_args()

    result = build()
    view = result["view"]
    problems = []
    if result["orphans"]:
        problems.append("以下物品没有任何效果行：" + ", ".join(result["orphans"]))
    if result["unknown_effect_items"]:
        problems.append("以下效果行指向不存在的物品：" + ", ".join(result["unknown_effect_items"]))

    expected = json.dumps(view, ensure_ascii=False, indent=2, sort_keys=False)
    if args.write:
        VIEW.parent.mkdir(parents=True, exist_ok=True)
        VIEW.write_text(expected + chr(10), encoding="utf-8")
        print("已生成：", VIEW.name)
    else:
        if not VIEW.is_file():
            problems.append("视图文件不存在，先跑 --write")
        else:
            actual = json.loads(VIEW.read_text(encoding="utf-8"))
            if actual != json.loads(expected):
                problems.append("视图与源表不同步，跑 --write 重新生成")
                changed = [a["id"] for a, b in zip(actual.get("items", []), view["items"]) if a != b][:8]
                if changed:
                    problems.append("不一致的物品：" + ", ".join(changed))

    if problems:
        print("检查未通过：", file=sys.stderr)
        for line in problems:
            print("  - " + line, file=sys.stderr)
        return 1
    print("检查通过：%d 件物品，%d 条效果，视图与源表一致" % (
        view["item_count"], sum(len(row["effects"]) for row in view["items"])))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
