# -*- coding: utf-8 -*-
"""药剂刀·侦查：8 件药剂场景的 BottleOfBooze 子场景用法 + potionColor/foam 属性分布。只读。"""
import re, sys, io, json
from pathlib import Path
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
ROOT = Path(r'd:\GIt\yingx\yinxon\project')
data = json.loads((ROOT / 'PvE' / 'asset_bindings.json').read_text(encoding='utf-8-sig'))
bound = {}
for bid, b in data['bindings'].items():
    bound.setdefault(b['name'].replace(' ', ''), []).append(bid)
already = {b['name'].replace(' ', '') for b in data['bindings'].values() if b.get('template', '') != ''}

for stem in ['HealthPotion', 'VampiricPotion', 'PestilenceFlask', 'Laboratory', 'ManaregenPotion',
              'StrengthPotion', 'CrateofFreshMilk', 'Potionbelt']:
    # 找场景
    p = None
    for sub in ('', 'Exclusive', 'Gems'):
        c = ROOT / 'Items' / sub / (stem + '.tscn')
        if c.exists():
            p = c
            break
    if p is None:
        print(f'{stem}: 场景未找到')
        continue
    t = p.read_text(encoding='utf-8')
    ids = sorted(bound.get(stem, []))
    tag = '[已迁]' if stem in already else (f'{len(ids)}id' if ids else '无绑定!')
    boozes = re.findall(r'\[node name="(\w+)" parent="(\.|Icon)" instance=ExtResource\("([^"]+)"\)[^\]]*BottleOfBooze[^\]]*\]', t)
    # 实际上 instance 节点引用 ext —— 找 BottleOfBooze 的 ext id 再找节点
    booze_ext = re.findall(r'\[ext_resource type="(?:PackedScene|Node2D|\w+)" path="res://[^"]*BottleOfBooze[^"]*" id="([^"]+)"', t)
    nodes = []
    for eid in booze_ext:
        for m in re.finditer(r'\[node name="(\w+)" parent="([^"]+)" instance=ExtResource\("' + re.escape(eid) + r'"\)[^\]]*\]\s*\n(.*?)(?=\n\[|\s*\Z)', t, re.S):
            nodes.append((m.group(1), m.group(2), m.group(3)[:150]))
    potion_color = re.search(r'potionColor = Color\(([^)]+)\)', t)
    foam = 'foam' in t
    print(f'===== {stem} {tag} =====')
    for n, par, blk in nodes:
        print(f'  实例 {n} parent={par}: {blk!r}')
    print(f'  potionColor={potion_color.group(1) if potion_color else None} foam={foam}')
