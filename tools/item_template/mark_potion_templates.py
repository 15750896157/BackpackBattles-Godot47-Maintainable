# -*- coding: utf-8 -*-
"""药剂刀：17 个绑定 id 加 template 标记（铁规：scene_sha256 原样保留）。"""
import json
import sys
from pathlib import Path

BINDINGS = Path(r"d:\GIt\yingx\yinxon\project\PvE\asset_bindings.json")
IDS = {
    "tonic_bottle", "supply_dusk_robe",                              # HealthPotion
    "stamina_flask", "supply_apprentice_robe", "supply_fruit", "supply_mana_gem",  # HeroicPotion
    "cleansing_salt", "supply_cross", "supply_holy_cross",          # DivinePotion
    "blood_cup", "supply_blood_crystal_necklace", "supply_blood_ring",
    "supply_lust_crest", "supply_vampire_fang",                      # VampiricPotion
    "toxin_bottle", "supply_voodoo_staff",                           # PestilenceFlask
    "venom_distiller",                                               # Laboratory
}
TOTAL_EXPECTED = 126


def main() -> int:
    text = BINDINGS.read_text(encoding="utf-8")
    before = {bid: json.loads(text)["bindings"][bid]["scene_sha256"] for bid in IDS}
    if "--check" in sys.argv:
        data = json.loads(text)
        marked = {bid: b.get("template", "") for bid, b in data["bindings"].items() if b.get("template", "") != ""}
        for bid in IDS:
            assert marked.get(bid) == "ItemBase", f"{bid}: 标记缺失"
            assert data["bindings"][bid]["scene_sha256"] == before[bid], f"{bid}: sha256 变了"
        assert len(marked) == TOTAL_EXPECTED, f"总数 {len(marked)} != {TOTAL_EXPECTED}"
        print("MARKS_IN_SYNC", len(marked))
        return 0
    for bid in IDS:
        i = text.index('"%s": {' % bid)
        j = text.index("\n    }", i)
        block = text[i:j]
        assert '"template"' not in block, f"{bid}: 已有标记"
        k = block.index('"png_sha256"')
        nl = block.find("\n", k)
        if nl == -1:
            # png_sha256 是块内最后一个属性（无尾换行）
            block_new = block + ',\n      "template": "ItemBase"'
        else:
            sep = "" if block[k:nl].rstrip().endswith(",") else ","
            block_new = block[:nl] + sep + '\n      "template": "ItemBase"' + block[nl:]
        text = text[:i] + block_new + text[j:]
    data = json.loads(text)
    marked = {bid: b["template"] for bid, b in data["bindings"].items() if b.get("template", "") != ""}
    for bid in IDS:
        assert marked[bid] == "ItemBase", bid
        assert data["bindings"][bid]["scene_sha256"] == before[bid], bid + " sha256 changed!"
    assert len(marked) == TOTAL_EXPECTED, f"总数 {len(marked)} != {TOTAL_EXPECTED}"
    BINDINGS.write_text(text, encoding="utf-8")
    print("WROTE, total marked:", len(marked))


if __name__ == "__main__":
    sys.exit(main())
