# -*- coding: utf-8 -*-
"""动画刀·包场景生成器：把物品的"动画+目标节点"抽成独立包场景 PvE/Items/Anims/<Stem>Anim.tscn。

三类模式（轨道 NodePath 相对 AnimationPlayer.root_node(默认"..")，零改写原则）：
  A. 同级模式：包根=Node2D 容器，内含目标节点 + AnimationPlayer（兄弟关系保持），
     轨道 'Xxx:prop' 相对包根——与原"相对 Icon"语义一致。挂 Icon 下。
     ThorsHammer 补充：包根加 use_parent_material=true——WithLight 的继承材质链
     经包根（get_material 递归取父链）直达 Icon 的溶解 ShaderMaterial。
  B. 根挂模式（Chainsaw）：包根=AnimationPlayer 本身，挂 Icon 原位。
     轨道 '.'=Icon 自身、'..'=物品根——原位保持，零改写。
  C. 目标即根模式（灯光刀）：包根=目标节点本身（如 TorchLight），其 AnimationPlayer
     子节点原样挂在包根下（parent="Icon/<target>" → parent="."）——轨道 '.'=目标自身，
     原父子结构保持，零改写。包实例挂 Icon 下、实例名=目标名，Icon/TorchLight 路径不变。
生成后由提取器在 overrides JSON 的 extra_nodes 里加 {"name":..., "scene":..., "parent": "Icon"}。
"""
import re
import sys
import io
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
ROOT = Path(r'd:\GIt\yingx\yinxon\project')
OUT = ROOT / 'PvE' / 'Items' / 'Anims'
OUT.mkdir(parents=True, exist_ok=True)

# (stem, sub, mode, targets, player, root_upm)
#   mode: A=同级容器 / B=AnimationPlayer 为根 / C=目标节点为根（带 AnimationPlayer 子树）
#   player: Icon 下 AnimationPlayer 节点名（A 模式用；第六刀 8 件都叫 AnimationPlayer，ThorsHammer 叫 Idle）
#   root_upm: A 模式包根是否加 use_parent_material=true（材质继承链穿透包根）
ITEMS = [
    # ---- 第六刀（8 件，输出必须与已验收版本字节一致）----
    ('BionicArmor', 'Exclusive', 'A', ['CircleLight'], 'AnimationPlayer', False),
    ('Halberd', 'Exclusive', 'A', ['Shine'], 'AnimationPlayer', False),
    ('BloodAmulet', '', 'A', ['AmuletGlow'], 'AnimationPlayer', False),
    ('CursedHairComb', '', 'A', ['AmuletGlow'], 'AnimationPlayer', False),
    ('StoneBadge', 'Exclusive', 'A', ['Glow'], 'AnimationPlayer', False),
    ('PoisonIvy', '', 'A', ['Glow'], 'AnimationPlayer', False),
    ('YggdrasilLeaf', '', 'A', ['Glow'], 'AnimationPlayer', False),
    ('Chainsaw', 'Exclusive', 'B', [], '', False),
    # ---- 灯光刀（3 件）----
    ('ThorsHammer', 'Exclusive', 'A', ['WithLight'], 'Idle', True),
    ('OilLamp', 'Exclusive', 'C', ['TorchLight'], '', False),
    ('BurningTorch', '', 'C', ['TorchLight'], '', False),
]


def extract(stem, sub, mode, targets, player='AnimationPlayer', root_upm=False):
    src = ROOT / 'Items' / sub / (stem + '.tscn')
    t = src.read_text(encoding='utf-8')
    used_ext = set()
    sub_blocks = []

    def collect_anim_subresources(blocks_text):
        """从节点块文本里收 anims/X = SubResource("id") 引用，搬对应 Animation sub_resource。"""
        ids = [sid for _, _, sid in re.findall(r'(\w+)/(\w+) = SubResource\("([^"]+)"\)', blocks_text)]
        for sid in ids:
            sm = re.search(r'\[sub_resource type="Animation" id="' + re.escape(sid) + r'"\]\s*\n(.*?)(?=\n\[|\s*\Z)', t, re.S)
            assert sm, f'{stem}: 未找到 Animation 子资源 {sid}'
            sub_blocks.append('[sub_resource type="Animation" id="' + sid + '"]\n' + sm.group(1).rstrip())
            used_ext.update(re.findall(r'ExtResource\("([^"]+)"\)', sm.group(1)))

    if mode == 'A':
        # Icon 下 AnimationPlayer 节点块（名字可配置：第六刀都叫 AnimationPlayer，ThorsHammer 叫 Idle）
        apm = re.search(r'\[node name="' + re.escape(player) + r'" type="AnimationPlayer" parent="Icon"[^\]]*\]\s*\n(.*?)(?=\n\[|\s*\Z)', t, re.S)
        assert apm, f'{stem}: 未找到 Icon 下 AnimationPlayer（{player}）'
        ap_blk = apm.group(1)
        collect_anim_subresources(ap_blk)
        target_blocks = []
        for tn in targets:
            tm = re.search(r'\[node name="' + tn + r'"[^\]]*parent="Icon"[^\]]*\]\s*\n(.*?)(?=\n\[|\s*\Z)', t, re.S)
            assert tm, f'{stem}: 未找到目标节点 {tn}'
            target_blocks.append((tn, tm.group(0)))
        for _, blk in target_blocks:
            used_ext |= set(re.findall(r'ExtResource\("([^"]+)"\)', blk))
        used_ext |= set(re.findall(r'ExtResource\("([^"]+)"\)', ap_blk))
        # ext_resource 头行
        ext_lines = _ext_lines(t, stem, used_ext)
        # 拼装新场景（结构与第六刀完全一致：包根 Node2D + 目标 + AnimationPlayer）
        out = ['[gd_scene load_steps=' + str(len(ext_lines) + len(sub_blocks) + 1) + ' format=3]']
        out += ext_lines
        out += ['']
        out += sub_blocks
        out += ['']
        root_line = f'[node name="{stem}Anim" type="Node2D"]'
        if root_upm:
            root_line += '\nuse_parent_material = true'
        out.append(root_line)
        for tn, blk in target_blocks:
            out.append(re.sub(r'parent="Icon"', 'parent="."', blk, count=1))
        out.append(re.sub(r'parent="Icon"', 'parent="."', apm.group(0).rstrip() + '\n', count=1).rstrip())
    elif mode == 'B':
        apm = re.search(r'\[node name="AnimationPlayer" type="AnimationPlayer" parent="Icon"[^\]]*\]\s*\n(.*?)(?=\n\[|\s*\Z)', t, re.S)
        assert apm, f'{stem}: 未找到 Icon 下 AnimationPlayer'
        ap_blk = apm.group(1)
        collect_anim_subresources(ap_blk)
        used_ext |= set(re.findall(r'ExtResource\("([^"]+)"\)', ap_blk))
        ext_lines = _ext_lines(t, stem, used_ext)
        out = ['[gd_scene load_steps=' + str(len(ext_lines) + len(sub_blocks) + 1) + ' format=3]']
        out += ext_lines
        out += ['']
        out += sub_blocks
        out += ['']
        # B：AnimationPlayer 直接做根（无 parent 属性）
        root_ap = re.sub(r' parent="Icon"', '', apm.group(0).rstrip(), count=1)
        out.append(root_ap)
    else:
        # C：目标节点即包根，Icon/<target> 下子节点（AnimationPlayer 等）原样搬到包根下
        assert len(targets) == 1, f'{stem}: C 模式只支持单目标'
        target = targets[0]
        tm = re.search(r'\[node name="' + re.escape(target) + r'"[^\]]*parent="Icon"[^\]]*\]\s*\n(.*?)(?=\n\[|\s*\Z)', t, re.S)
        assert tm, f'{stem}: 未找到目标节点 {target}'
        used_ext |= set(re.findall(r'ExtResource\("([^"]+)"\)', tm.group(0)))
        child_ms = list(re.finditer(
            r'\[node name="(\w+)"(?: type="(\w+)")? parent="Icon/' + re.escape(target) + r'"[^\]]*\]\s*\n(.*?)(?=\n\[|\s*\Z)', t, re.S))
        assert child_ms, f'{stem}: {target} 下没有子节点（不需要 C 模式？）'
        all_children_blk = ''
        for cm in child_ms:
            used_ext |= set(re.findall(r'ExtResource\("([^"]+)"\)', cm.group(0)))
            collect_anim_subresources(cm.group(0))
            all_children_blk += cm.group(0)
        ext_lines = _ext_lines(t, stem, used_ext)
        out = ['[gd_scene load_steps=' + str(len(ext_lines) + len(sub_blocks) + 1) + ' format=3]']
        out += ext_lines
        out += ['']
        out += sub_blocks
        out += ['']
        # 根：目标节点头去掉 parent/index
        root_blk = re.sub(r'\s*parent="Icon"[^\]]*\]', ']', tm.group(0).rstrip(), count=1)
        out.append(root_blk)
        # 子节点：parent="Icon/<target>" → parent="."
        for cm in child_ms:
            out.append(re.sub(r'parent="Icon/' + re.escape(target) + '"', 'parent="."', cm.group(0).rstrip() + '\n', count=1).rstrip())
    text = '\n'.join(out) + '\n'
    dest = OUT / f'{stem}Anim.tscn'
    dest.write_text(text, encoding='utf-8')
    print(f'{stem}: -> {dest.relative_to(ROOT)}  mode={mode} anims={len(sub_blocks)} targets={targets} ext={len(ext_lines)}')


def _ext_lines(t, stem, used_ext):
    lines = []
    for eid in sorted(used_ext):
        em = re.search(r'\[ext_resource type="([^"]+)" path="([^"]+)" id="' + re.escape(eid) + r'"[^\]]*\]', t)
        assert em, f'{stem}: 未找到 ext_resource {eid}'
        lines.append(em.group(0))
    return lines


for stem, sub, mode, targets, player, root_upm in ITEMS:
    extract(stem, sub, mode, targets, player, root_upm)
print('DONE')
