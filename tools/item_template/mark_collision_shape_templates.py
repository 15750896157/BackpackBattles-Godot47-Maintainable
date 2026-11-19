# -*- coding: utf-8 -*-
"""碰撞形状刀：给 10 件物品的 23 个绑定 id 加 template 标记。

  BagofStones(sling,supply_stone) CustomerCard(merchant_token,supply_discount_card,supply_token)
  Cog(gear_link,supply_jade_gloves) HealingHerbs(bandage_roll,healing_herb,supply_elven_wreath,
  supply_gem_green,supply_potted_plant,supply_vine_ring) Piggybank(salvage_pouch,supply_salvage_pouch)
  Whetstone(sharpening_stone,supply_gem_yellow,supply_whetstone)
  ClawsofAttack(arsenal_bracer) DragonscaleArmor(layered_plates,supply_squire_armor)
  SpikedShield(spiked_guard) WoodenBuckler(buckler)
铁规：scene_sha256 现值必须原样保留。用法：py -3 tools/item_template/mark_collision_shape_templates.py [--check]
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / 'project'
BINDINGS = ROOT / 'PvE' / 'asset_bindings.json'

MARKS = {
    "sling": "ItemBase", "supply_stone": "ItemBase",
    "merchant_token": "ItemBase", "supply_discount_card": "ItemBase", "supply_token": "ItemBase",
    "gear_link": "ItemBase", "supply_jade_gloves": "ItemBase",
    "bandage_roll": "ItemBase", "healing_herb": "ItemBase", "supply_elven_wreath": "ItemBase",
    "supply_gem_green": "ItemBase", "supply_potted_plant": "ItemBase", "supply_vine_ring": "ItemBase",
    "salvage_pouch": "ItemBase", "supply_salvage_pouch": "ItemBase",
    "sharpening_stone": "ItemBase", "supply_gem_yellow": "ItemBase", "supply_whetstone": "ItemBase",
    "arsenal_bracer": "ItemBase",
    "layered_plates": "ItemBase", "supply_squire_armor": "ItemBase",
    "spiked_guard": "ItemBase",
    "buckler": "ItemBase",
}
TOTAL_EXPECTED = 92  # 试点5 + 第二刀11 + 粒子2 + 粒子收尾14 + 宝石孔37 + 本刀23


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
