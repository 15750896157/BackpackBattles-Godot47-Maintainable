# -*- coding: utf-8 -*-
"""收尾刀：剩余 22 个绑定 id 加 template 标记（19 ItemBase + 3 GemBase），
达成 166/166 全量覆盖。铁规：scene_sha256 原样保留。"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / 'project'
BINDINGS = ROOT / 'PvE' / 'asset_bindings.json'
MARKS = {
    # BurningBanner（Exclusive）
    "column_standard": "ItemBase", "guardian_standard": "ItemBase", "row_banner": "ItemBase",
    "supply_knight_seal": "ItemBase", "supply_weapon_case": "ItemBase",
    # BoxofRiches
    "compact_rack": "ItemBase",
    # Sandbag（Exclusive）
    "counterweight": "ItemBase",
    # DemonicFlask
    "ember_phial": "ItemBase", "supply_wooden_staff": "ItemBase",
    # BurningCoal（Gems，宝石基座）
    "ember_stone": "GemBase", "supply_flint": "GemBase", "supply_gem_red": "GemBase",
    # Cauldron（Exclusive）
    "philosophers_kettle": "ItemBase", "supply_gluttony_crest": "ItemBase",
    "wildfire_alembic": "ItemBase",
    # StrongPestilenceFlask
    "plague_retort": "ItemBase", "supply_demonic_codex": "ItemBase",
    # SpiritBells（Exclusive）
    "resonant_bell": "ItemBase", "supply_thunder_ring": "ItemBase",
    # PoisonDagger
    "supply_basic_staff": "ItemBase", "supply_puppet": "ItemBase", "venom_needle": "ItemBase",
}
TOTAL_EXPECTED = 166


def main() -> int:
    text = BINDINGS.read_text(encoding="utf-8")
    before = {bid: json.loads(text)["bindings"][bid]["scene_sha256"] for bid in MARKS}
    if "--check" in sys.argv:
        data = json.loads(text)
        marked = {bid: b.get("template", "") for bid, b in data["bindings"].items() if b.get("template", "") != ""}
        for bid, tmpl in MARKS.items():
            assert marked.get(bid) == tmpl, f"{bid}: 标记缺失或不符"
            assert data["bindings"][bid]["scene_sha256"] == before[bid], f"{bid}: sha256 变了"
        assert len(marked) == TOTAL_EXPECTED, f"总数 {len(marked)} != {TOTAL_EXPECTED}"
        print("MARKS_IN_SYNC", len(marked))
        return 0
    for bid, tmpl in MARKS.items():
        i = text.index('"%s": {' % bid)
        j = text.index("\n    }", i)
        block = text[i:j]
        assert '"template"' not in block, f"{bid}: 已有标记"
        k = block.index('"png_sha256"')
        nl = block.find("\n", k)
        if nl == -1:
            # png_sha256 是块内最后一个属性（无尾换行）
            block_new = block + ',\n      "template": "%s"' % tmpl
        else:
            sep = "" if block[k:nl].rstrip().endswith(",") else ","
            block_new = block[:nl] + sep + '\n      "template": "%s"' % tmpl + block[nl:]
        text = text[:i] + block_new + text[j:]
    data = json.loads(text)
    marked = {bid: b["template"] for bid, b in data["bindings"].items() if b.get("template", "") != ""}
    for bid, tmpl in MARKS.items():
        assert marked[bid] == tmpl, bid
        assert data["bindings"][bid]["scene_sha256"] == before[bid], bid + " sha256 changed!"
    assert len(marked) == TOTAL_EXPECTED, f"总数 {len(marked)} != {TOTAL_EXPECTED}"
    BINDINGS.write_text(text, encoding="utf-8")
    print("WROTE, total marked:", len(marked))


if __name__ == "__main__":
    sys.exit(main())
