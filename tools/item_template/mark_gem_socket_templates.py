# -*- coding: utf-8 -*-
"""第四刀·宝石孔：给 14 件物品的 37 个绑定 id 加 template 标记。
铁规：scene_sha256 现值必须原样保留。用法：py -3 tools/item_template/mark_gem_socket_templates.py [--check]
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / 'project'
BINDINGS = ROOT / 'PvE' / 'asset_bindings.json'

MARKS = {
    "broad_axe": "ItemBase", "supply_double_axe": "ItemBase",
    "utility_knife": "ItemBase", "supply_dagger": "ItemBase", "supply_wooden_knife": "ItemBase",
    "heavy_cleaver": "ItemBase", "supply_battle_axe": "ItemBase",
    "stone_hammer": "ItemBase", "supply_wooden_club": "ItemBase",
    "iron_sword": "ItemBase", "supply_iron_longsword": "ItemBase",
    "leather_wrap": "ItemBase", "supply_leather_armor": "ItemBase",
    "renewal_mortar": "ItemBase", "supply_herb_pouch": "ItemBase",
    "twin_needles": "ItemBase", "supply_kite_dagger": "ItemBase",
    "tower_shield": "ItemBase", "supply_holy_bulwark": "ItemBase",
    "hunting_spear": "ItemBase", "supply_blossom_bow": "ItemBase", "supply_bow": "ItemBase",
    "supply_composite_bow": "ItemBase", "supply_elven_bow": "ItemBase", "supply_hero_bow": "ItemBase",
    "supply_magic_bow": "ItemBase", "supply_spear": "ItemBase", "supply_vine_bow": "ItemBase",
    "supply_wooden_bow": "ItemBase",
    "retaliation_spikes": "ItemBase", "supply_thorn_mail": "ItemBase",
    "clockwork_spring": "ItemBase", "supply_copper_watch": "ItemBase",
    "plated_vest": "ItemBase", "supply_plate_armor": "ItemBase",
    "repair_kit": "ItemBase", "supply_medical_case": "ItemBase",
}
TOTAL_EXPECTED = 69  # 试点 5 + 第二刀 11 + 粒子 16 + 本刀 37


def main() -> int:
    text = BINDINGS.read_text(encoding="utf-8")
    before = {bid: json.loads(text)["bindings"][bid]["scene_sha256"] for bid in MARKS}
    if "--check" in sys.argv:
        data = json.loads(text)
        marked = {bid: b.get("template", "") for bid, b in data["bindings"].items() if b.get("template", "") != ""}
        for bid, tmpl in MARKS.items():
            assert marked.get(bid) == tmpl, f"{bid}: 标记缺失或不对 {marked.get(bid)}"
            assert data["bindings"][bid]["scene_sha256"] == before[bid], f"{bid}: scene_sha256 变了！"
        assert len(marked) == TOTAL_EXPECTED, f"template 标记总数 {len(marked)} != {TOTAL_EXPECTED}"
        print("MARKS_IN_SYNC", len(marked))
        return 0
    for bid, tmpl in MARKS.items():
        i = text.index('"%s": {' % bid)
        j = text.index("\n    }", i)
        block = text[i:j]
        assert '"template"' not in block, f"{bid}: 已有 template 标记？"
        k = block.index('"png_sha256"')
        newline_pos = block.find("\n", k)
        if newline_pos == -1:
            block_new = block + ",\n      \"template\": \"%s\"" % tmpl
        else:
            line = block[k:newline_pos]
            sep = "" if line.rstrip().endswith(",") else ","
            block_new = block[:newline_pos] + sep + "\n      \"template\": \"%s\"" % tmpl + block[newline_pos:]
        text = text[:i] + block_new + text[j:]
    data = json.loads(text)
    marked = {bid: b["template"] for bid, b in data["bindings"].items() if b.get("template", "") != ""}
    for bid, tmpl in MARKS.items():
        assert marked.get(bid) == tmpl, f"{bid}: 标记没写对 {marked.get(bid)}"
        assert data["bindings"][bid]["scene_sha256"] == before[bid], f"{bid}: scene_sha256 被动了！"
    assert len(marked) == TOTAL_EXPECTED, f"template 标记总数 {len(marked)} != {TOTAL_EXPECTED}"
    BINDINGS.write_text(text, encoding="utf-8")
    print("WROTE", BINDINGS, "template marks:", len(marked))


if __name__ == "__main__":
    sys.exit(main())
