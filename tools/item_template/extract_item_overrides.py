# -*- coding: utf-8 -*-
"""从原版物品场景提取「数据覆盖」JSON（试点 3 件 + 第二刀 6 件）。

为什么做：把「手写 .tscn 文件覆盖」改成「新基场景 + 运行时数据覆盖」，
覆盖数据必须逐字节忠实于原版场景，否则迁移不成立。
输出：yinxon/project/PvE/item_template_overrides.json（9 件场景，服务 16 个绑定 id）。
只读分析 + 写一个新 JSON，不改任何游戏原文件。

用法：py -3 tz/extract_item_overrides.py [--check]
  --check = 只校验已生成的 JSON 与源场景仍然一致（供验收调用），不重写。

第二刀新增（2026-11-18）：
  1. 宝石两件（PerfectAmethyst/RegularSapphire）基场景是 Items/Gems/Gem.tscn
     （它本身是 Item.tscn 的实例）。提取时先解析 Gem.tscn 得共享基数据，
     再用宝石场景自身的覆盖段叠加，等价于 Godot 的场景合并语义。
     宝石共享的 SocketDetectionArea/GemAnimation 不进数据——
     它们整体搬进新基场景 PvE/Items/GemBase.tscn（照抄原版 Item→Gem 层级）。
  2. Rope 的 SpeedTimer（Timer + MultiTimer.gd + multi_timeout 信号连接）
     作为「额外节点」进数据，运行时按数据动态创建。
  3. body 碰撞节点 index 从硬编码 5 放宽为任意（简单件是 7，宝石是 5）。
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(r"d:\GIt\yingx\yinxon\project")
OUT = ROOT / "PvE" / "item_template_overrides.json"

# 场景文件名（去空格）-> 配置。ids = 一份数据服务的绑定 definition_id 列表。
# base: "item" = 直接实例 Items/Item.tscn；"gem" = 实例 Items/Gems/Gem.tscn。
SCENES = {
    # ---- 第一刀试点（3 件，保持不动）----
    "LuckyClover": {"ids": ["lucky_coin", "supply_greed_crest", "supply_lucky_cat"], "base": "item"},
    "WalrusTusk": {"ids": ["iron_nail"], "base": "item"},
    "FlyAgaric": {"ids": ["spore_jar"], "base": "item"},
    # ---- 第二刀（6 件）----
    "Anvil": {"ids": ["execution_anvil", "supply_wrath_crest"], "base": "item", "sub": "Exclusive"},
    "Coil": {"ids": ["caustic_coil"], "base": "item", "sub": "Exclusive"},
    "SliceofBread": {"ids": ["travel_ration", "supply_bread"], "base": "item", "sub": "Exclusive"},
    "Rope": {"ids": ["storage_hook"], "base": "item", "sub": "Exclusive"},
    "PerfectAmethyst": {"ids": ["focus_prism", "supply_elven_gemstone", "supply_gem_purple"], "base": "gem"},
    "RegularSapphire": {"ids": ["glass_bead", "supply_gem_blue"], "base": "gem"},
    # ---- 第三刀：条件槽位·粒子（2 件，纯粒子无其他槽位）----
    "Battery": {"ids": ["charging_weight"], "base": "item", "sub": "Exclusive"},
    "Repeater": {"ids": ["repeater_crossbow"], "base": "item", "sub": "Exclusive"},
    # ---- 第三刀续：粒子类收尾（7 件；StarofCourage 带一个 Glow Sprite2D = 灯光类第一块砖）----
    "Generator": {"ids": ["momentum_gear"], "base": "item", "sub": "Exclusive"},
    "MagicMirror": {"ids": ["scout_lens", "supply_elven_charm"], "base": "item", "sub": "Exclusive"},
    "PerpetuumMobile": {"ids": ["overdrive_ratchet", "supply_pride_crest"], "base": "item", "sub": "Exclusive"},
    "SmithingForDummies": {"ids": ["field_manual", "supply_codex"], "base": "item", "sub": "Exclusive"},
    "StarofCourage": {"ids": ["star_compass", "supply_crown_crest"], "base": "item", "sub": "Exclusive"},
    "TimeDilator": {"ids": ["cooling_fan", "supply_ice_pack"], "base": "item", "sub": "Exclusive"},
    "PocketSand": {"ids": ["quicksand_vial", "supply_ice_cube", "supply_sloth_crest"], "base": "item"},
    # ---- 第四刀：宝石孔 GemSocket（14 件；孔位=Icon/Sockets 下 GemSocket.tscn 的 position 列表）----
    # 挡住没进的 10 件（留给后续刀）：BionicArmor/Chainsaw/Halberd/ThorsHammer=动画槽位，
    # ClawsofAttack/DragonscaleArmor/SpikedShield/WoodenBuckler=碰撞形状槽位，
    # BurningTorch=灯光带嵌套动画，PoisonDagger=粒子带内嵌 CanvasItemMaterial。
    "Axe": {"ids": ["broad_axe", "supply_double_axe"], "base": "item", "sub": "Exclusive"},
    "Dagger": {"ids": ["utility_knife", "supply_dagger", "supply_wooden_knife"], "base": "item"},
    "DoubleAxe": {"ids": ["heavy_cleaver", "supply_battle_axe"], "base": "item", "sub": "Exclusive"},
    "Hammer": {"ids": ["stone_hammer", "supply_wooden_club"], "base": "item"},
    "HeroSword": {"ids": ["iron_sword", "supply_iron_longsword"], "base": "item"},
    "LeatherArmor": {"ids": ["leather_wrap", "supply_leather_armor"], "base": "item"},
    "Pot": {"ids": ["renewal_mortar", "supply_herb_pouch"], "base": "item", "sub": "Exclusive"},
    "Scissorswords": {"ids": ["twin_needles", "supply_kite_dagger"], "base": "item", "sub": "Exclusive"},
    "ShieldofValor": {"ids": ["tower_shield", "supply_holy_bulwark"], "base": "item"},
    "Spear": {"ids": ["hunting_spear", "supply_blossom_bow", "supply_bow", "supply_composite_bow",
                      "supply_elven_bow", "supply_hero_bow", "supply_magic_bow", "supply_spear",
                      "supply_vine_bow", "supply_wooden_bow"], "base": "item"},
    "SpikedWall": {"ids": ["retaliation_spikes", "supply_thorn_mail"], "base": "item", "sub": "Exclusive"},
    "SpringLoader": {"ids": ["clockwork_spring", "supply_copper_watch"], "base": "item", "sub": "Exclusive"},
    "StoneArmor": {"ids": ["plated_vest", "supply_plate_armor"], "base": "item", "sub": "Exclusive"},
    "Wrench": {"ids": ["repair_kit", "supply_medical_case"], "base": "item", "sub": "Exclusive"},
    # ---- 第五刀：碰撞形状 CollisionShape2D（10 件 = 6 件纯碰撞 + 4 件宝石孔+碰撞并存解锁）----
    # LeatherBag（bag_release_* 9 id）被结构总账拦下：格区 TileMap，顺延格区刀。
    "BagofStones": {"ids": ["sling", "supply_stone"], "base": "item"},
    "CustomerCard": {"ids": ["merchant_token", "supply_discount_card", "supply_token"], "base": "item"},
    "Cog": {"ids": ["gear_link", "supply_jade_gloves"], "base": "item", "sub": "Exclusive"},
    "HealingHerbs": {"ids": ["bandage_roll", "healing_herb", "supply_elven_wreath", "supply_gem_green",
                             "supply_potted_plant", "supply_vine_ring"], "base": "item"},
    "Piggybank": {"ids": ["salvage_pouch", "supply_salvage_pouch"], "base": "item"},
    "Whetstone": {"ids": ["sharpening_stone", "supply_gem_yellow", "supply_whetstone"], "base": "item"},
    "ClawsofAttack": {"ids": ["arsenal_bracer"], "base": "item"},
    "DragonscaleArmor": {"ids": ["layered_plates", "supply_squire_armor"], "base": "item", "sub": "Exclusive"},
    "SpikedShield": {"ids": ["spiked_guard"], "base": "item"},
    "WoodenBuckler": {"ids": ["buckler"], "base": "item"},
    # ---- 第六刀：动画（8 件，动画包场景 PvE/Items/Anims/<Stem>Anim.tscn 由 tz/build_anim_bundles.py 生成）----
    # anim_targets = 抽进包场景的目标节点名（连同 Icon 下 AnimationPlayer，结构总账跳过、不进 extra_nodes）。
    "BionicArmor": {"ids": ["bastion_core"], "base": "item", "sub": "Exclusive", "anim_targets": ["CircleLight"]},
    "Chainsaw": {"ids": ["chain_blade"], "base": "item", "sub": "Exclusive", "anim_root_player": True},
    "Halberd": {"ids": ["crescent_glaive"], "base": "item", "sub": "Exclusive", "anim_targets": ["Shine"]},
    "BloodAmulet": {"ids": ["supply_envy_crest", "transfusion_tube"], "base": "item", "anim_targets": ["AmuletGlow"]},
    "CursedHairComb": {"ids": ["fracture_charm", "supply_voodoo_doll"], "base": "item", "anim_targets": ["AmuletGlow"]},
    "StoneBadge": {"ids": ["duelist_mark", "supply_honor_medal", "supply_priest_badge"], "base": "item",
                    "sub": "Exclusive", "anim_targets": ["Glow"]},
    "PoisonIvy": {"ids": ["thorn_extract"], "base": "item", "anim_targets": ["Glow"]},
    "YggdrasilLeaf": {"ids": ["regeneration_leaf", "supply_elven_tear"], "base": "item", "anim_targets": ["Glow"]},
    # ---- 灯光刀（3 件；动画包三模式：ThorsHammer=A 模式（WithLight+Idle，包根 use_parent_material 穿透材质链），
    #      OilLamp/BurningTorch=C 模式（TorchLight 即包根，闪烁 AnimationPlayer 挂根下，Icon/TorchLight 路径不变）----
    # anim_targets 语义 = 进包的全部 Icon 下节点名（目标 + AnimationPlayer 名，如 ThorsHammer 的 Idle）。
    # anim_root_target = C 模式：包实例名 = 目标节点名（挂 Icon 下保持原路径）。
    # required_animations = 包内 AnimationPlayer 的动画断言（QA 走既有 interface 机制）。
    "ThorsHammer": {"ids": ["siege_maul"], "base": "item", "sub": "Exclusive",
                     "anim_targets": ["WithLight", "Idle"],
                     "required_animations": {"Icon/ThorsHammerAnim/Idle": ["Flash"]}},
    "OilLamp": {"ids": ["ignition_lens", "supply_chaos_staff"], "base": "item", "sub": "Exclusive",
                 "anim_targets": ["TorchLight"], "anim_root_target": "TorchLight",
                 "required_animations": {"Icon/TorchLight/FlickerAnimation": ["Flicker"]}},
    "BurningTorch": {"ids": ["coal_burner"], "base": "item",
                      "anim_targets": ["TorchLight"], "anim_root_target": "TorchLight",
                      "required_animations": {"Icon/TorchLight/AnimationPlayer": ["Flicker"],
                                               "Icon/TorchLight/FlickerAnimation": ["Flicker"]}},
    # ---- 药剂刀（6 件/17 绑定；侦查结论：potionColor 在场景根属性（脚本 @export），
    #      Laboratory 根 rotation=-6.27446、ClickArea 节点自身 position=(17,-19)；
    #      BottleOfBooze/Fluid 瓶子是 PackedScene 实例节点+属性覆盖（extra_nodes scene 模式直接支持，
    #      内嵌 ShaderMaterial/Curve 走 _dump_subres_tres 抽 .tres）。
    #      本刀同修第六刀漏收的 ClickArea 节点自身 position/visible（Chainsaw 0,-99 错位 bug）----
    "HealthPotion": {"ids": ["tonic_bottle", "supply_dusk_robe"], "base": "item"},
    "HeroicPotion": {"ids": ["stamina_flask", "supply_apprentice_robe", "supply_fruit", "supply_mana_gem"], "base": "item"},
    "DivinePotion": {"ids": ["cleansing_salt", "supply_cross", "supply_holy_cross"], "base": "item", "sub": "Exclusive"},
    "VampiricPotion": {"ids": ["blood_cup", "supply_blood_crystal_necklace", "supply_blood_ring",
                                 "supply_lust_crest", "supply_vampire_fang"], "base": "item", "sub": "Exclusive"},
    "PestilenceFlask": {"ids": ["toxin_bottle", "supply_voodoo_staff"], "base": "item"},
    "Laboratory": {"ids": ["venom_distiller"], "base": "item", "sub": "Exclusive"},
}

ITEM_TSCN = "res://Items/Item.tscn"
GEM_TSCN = "res://Items/Gems/Gem.tscn"
GEM_TEMPLATE = "res://PvE/Items/GemBase.tscn"

# 根下已知子节点（这些是模板结构，不算「额外节点」）。
KNOWN_CHILDREN = {
    "CollisionMap", "Icon", "Sockets", "ClickArea", "CollisionPolygon2D",
    "CollisionShape2D", "BottomCenter", "AnimationPlayer", "DragParticles", "Lock",
}
# 额外节点允许的类型白名单：出现白名单外的类型 = 场景有本文档没覆盖的结构，停手汇报。
# GPUParticles2D = 粒子槽位；Sprite2D = 发光贴图（Glow，灯光类第一块砖，2026-11-18）。
EXTRA_NODE_TYPES = {"Timer", "GPUParticles2D", "Sprite2D"}
# 额外节点允许的挂载父节点白名单（根 or Icon——引擎两处都扫描收集 SpecificDragParticles）。
EXTRA_NODE_PARENTS = {".", "Icon"}

# 已知唯一的内嵌 shader（溶解高亮）。只认这一段代码，别的直接报错拦下。
DISSOLVE_SIG = "smoothstep(progress - 0.05, progress + 0.05, dot(UV, direction))"


def _scalar(raw: str):
    """把 tscn 属性值转成 JSON 可序列化的标量。只认 bool/int/float/字符串。"""
    raw = raw.strip()
    if raw == "true":
        return True
    if raw == "false":
        return False
    if re.fullmatch(r"-?\d+", raw):
        return int(raw)
    if re.fullmatch(r"-?\d+\.\d+", raw):
        return float(raw)
    return raw


def _prop_value(raw: str, ext: dict, subres_ctx=None):
    """额外节点属性值：Color/Vector2/ExtResource 转成带类型标记的 dict，其余走标量。
    类型标记由 ItemTemplate.gd 的 _decode 对应还原。
    subres_ctx = (subres, ext_lines, scene_stem) 时，SubResource 引用抽成 .tres 文件返回路径。"""
    raw = raw.strip()
    m = re.fullmatch(r"Color\(([^)]+)\)", raw)
    if m:
        return {"color": [float(v.strip()) for v in m.group(1).split(",")]}
    m = re.fullmatch(r"Vector2\(([^)]+)\)", raw)
    if m:
        return {"vec2": [float(v.strip()) for v in m.group(1).split(",")]}
    m = re.fullmatch(r'ExtResource\("([^"]+)"\)', raw)
    if m:
        return {"res": ext[m.group(1)][1]}
    m = re.fullmatch(r'SubResource\("([^"]+)"\)', raw)
    if m and subres_ctx is not None:
        subres, ext_lines, scene_stem = subres_ctx
        return {"res": _dump_subres_tres(subres, ext_lines, m.group(1), scene_stem)}
    assert not re.match(r'^(Packed|NodePath|Array|Dictionary|SubResource|Object)', raw), \
        f"额外节点属性值类型未覆盖，停手汇报：{raw}"
    return _scalar(raw)


def _dump_subres_tres(subres: dict, ext_lines: dict, sid: str, scene_stem: str) -> str:
    """把场景内嵌 sub_resource（材质类，含嵌套 Curve/Gradient/纹理引用）抽成独立 .tres。
    幂等：文件已存在直接返回路径。返回 res:// 路径。"""
    out_dir = ROOT / "PvE" / "Items" / "Particles"
    out_dir.mkdir(parents=True, exist_ok=True)
    fname = f"{scene_stem}_mat{re.sub(r'[^A-Za-z0-9]', '_', sid)}.tres"
    dest = out_dir / fname
    res_path = f"res://PvE/Items/Particles/{fname}"
    if dest.exists():
        return res_path
    # 递归收集依赖（嵌套 SubResource 块 + ExtResource 行）
    main_type, main_blk = subres[sid]
    seen_sub, seen_ext = {sid}, set()

    def collect(blk):
        for ref in re.findall(r'SubResource\("([^"]+)"\)', blk):
            if ref not in seen_sub:
                seen_sub.add(ref)
                collect(subres[ref][1])
        seen_ext.update(re.findall(r'ExtResource\("([^"]+)"\)', blk))

    collect(main_blk)
    parts = [f"[gd_resource type=\"{main_type}\" load_steps={len(seen_sub) + len(seen_ext) + 1} format=3]"]
    for eid in sorted(seen_ext):
        assert eid in ext_lines, f"{scene_stem}: 内嵌材质引用未知 ext_resource {eid}，停手汇报"
        parts.append(ext_lines[eid])
    parts.append("")
    # 拓扑序输出：被引用的 sub_resource 必须先定义（Godot .tres 顺序解析，不支持后向引用）
    emitted = set()

    def emit(s):
        if s in emitted or s == sid:
            return
        emitted.add(s)
        for ref in re.findall(r'SubResource\("([^"]+)"\)', subres[s][1]):
            emit(ref)
        parts.append(f"[sub_resource type=\"{subres[s][0]}\" id=\"{s}\"]")
        parts.append(subres[s][1].rstrip())
        parts.append("")

    for s in sorted(seen_sub):
        emit(s)
    parts.append("[resource]")
    parts.append(main_blk.rstrip())
    dest.write_text("\n".join(parts) + "\n", encoding="utf-8")
    return res_path


def parse_tscn(path: Path, expect_base: str, capture_extras: bool, anim_targets: set = None) -> dict:
    """解析一个「实例化基场景 + 覆盖」的原版场景。段缺失时对应键为 None，由调用方合并。
    anim_targets：动画包成员节点名（Icon 下目标节点 + AnimationPlayer）——进包场景，这里跳过。"""
    text = path.read_text(encoding="utf-8")
    skip_on_icon = (anim_targets or set()) | {"AnimationPlayer"}
    # --- ext_resource：id -> (type, path) ---
    ext = {}
    for m in re.finditer(r'\[ext_resource type="([^"]+)" path="([^"]+)" id="([^"]+)"', text):
        ext[m.group(3)] = (m.group(1), m.group(2))
    ext_lines = {}
    for m in re.finditer(r'\[ext_resource [^\]]+\]', text):
        idm = re.search(r'id="([^"]+)"', m.group(0))
        ext_lines[idm.group(1)] = m.group(0)
    # --- sub_resource：id -> (type, block)，供内嵌材质抽取 ---
    subres = {}
    for m in re.finditer(r'\[sub_resource type="(\w+)" id="([^"]+)"\]\s*\n(.*?)(?=\n\[|\s*\Z)', text, re.S):
        subres[m.group(2)] = (m.group(1), m.group(3))
    subres_ctx = (subres, ext_lines, path.stem)
    # --- 根节点 ---
    root_m = re.search(r'\[node name="([^"]+)" instance=ExtResource\("([^"]+)"\)\]', text)
    if not root_m:
        raise AssertionError(f"{path.name}: 找不到实例化根节点（不是基场景实例？）")
    root_name = root_m.group(1).replace('"', "")
    base_scene = ext[root_m.group(2)][1]
    expected = ITEM_TSCN if expect_base == "item" else GEM_TSCN
    if base_scene != expected:
        raise AssertionError(f"{path.name}: 基场景是 {base_scene}，预期 {expected}")
    # --- 根节点属性段（到下一个 [node 为止）---
    root_block = text[root_m.end():text.index("\n[node", root_m.end())]
    script = ext[re.search(r'script = ExtResource\("([^"]+)"\)', root_block).group(1)][1]
    # 根属性白名单：脚本/物理材质由固定槽位收；药剂刀新增 rotation / potionColor
    # （脚本 @export 属性）。__meta__ = 编辑器参考线，非运行时数据，安全忽略。
    # 出现别的 = 未知根属性，停手汇报（防静默丢根属性）。
    root_keys = set(re.findall(r'^(\w+) = ', root_block, re.M))
    assert root_keys <= {"script", "physics_material_override", "rotation", "potionColor", "__meta__"}, \
        f"{path.name}: 根节点有未知属性 {root_keys}，停手汇报"
    root_props = {}
    rot_m = re.search(r'^rotation = (-?[\d.eE+-]+)$', root_block, re.M)
    if rot_m:
        root_props["rotation"] = float(rot_m.group(1))
    pc_m = re.search(r'^potionColor = Color\(([^)]+)\)$', root_block, re.M)
    if pc_m:
        root_props["potionColor"] = [float(v.strip()) for v in pc_m.group(1).split(",")]
    # --- physics material（sub_resource）---
    pm = re.search(
        r'\[sub_resource type="PhysicsMaterial" id="(\d+)"\]\s*\nresource_local_to_scene = true\s*\nfriction = ([\d.]+)\s*\nbounce = ([\d.]+)',
        text)
    friction, bounce = float(pm.group(2)), float(pm.group(3))
    # --- CollisionMap（宝石场景自身不覆盖此节点，允许缺失）---
    cm = re.search(
        r'\[node name="CollisionMap" parent="\." index="\d+"\]\s*\n(?:position = Vector2\(([^)]+)\)\s*\n)?format = 2\s*\nlayer_0/tile_data = PackedInt32Array\(([^)]*)\)',
        text)
    collision_map = None
    if cm:
        cm_pos = [float(v) for v in cm.group(1).split(",")] if cm.group(1) else [0.0, 0.0]
        cells = []
        raw = [int(v.strip()) for v in cm.group(2).split(",")] if cm.group(2).strip() else []
        assert len(raw) % 3 == 0, f"{path.name}: tile_data 不是 3 的倍数"
        for i in range(0, len(raw), 3):
            packed, tile_id, _flip = raw[i], raw[i + 1], raw[i + 2]
            x = packed & 0xFFFF
            if x >= 0x8000:
                x -= 0x10000
            y = (packed - x) // 65536
            cells.append([x, y, tile_id])
        collision_map = {"position": cm_pos, "cells": cells}
    # --- Icon ---
    icon = re.search(r'\[node name="Icon" parent="\." index="\d+"\]\s*\n(.*?)(?=\n\[node)', text, re.S)
    ib = icon.group(1)
    tex = ext[re.search(r'texture = ExtResource\("([^"]+)"\)', ib).group(1)][1]
    pos_m = re.search(r'position = Vector2\(([^)]+)\)', ib)
    scale_m = re.search(r'scale = Vector2\(([^)]+)\)', ib)
    # Icon material（溶解 shader 参数）
    material = None
    mat_m = re.search(r'material = SubResource\("(\d+)"\)', ib)
    if mat_m:
        sub_m = re.search(
            r'\[sub_resource type="ShaderMaterial" id="%s"\]\s*\nresource_local_to_scene = true\s*\nshader = SubResource\("(\d+)"\)\s*\n((?:shader_parameter/.*\n)+)' % mat_m.group(1),
            text)
        shader_m = re.search(r'\[sub_resource type="Shader" id="%s"\]\s*\ncode = "(.*?)"\s*\n' % sub_m.group(1), text, re.S)
        code = shader_m.group(1)
        assert code.strip().startswith("shader_type canvas_item;"), f"{path.name}: 未知 shader"
        assert DISSOLVE_SIG in code, f"{path.name}: 只认溶解 shader，发现别的 shader 代码，停手汇报"
        params = {}
        for pm_line in re.finditer(r'shader_parameter/(\w+) = (.+)', sub_m.group(2)):
            raw_param = pm_line.group(2).strip().removeprefix("Vector2")
            params[pm_line.group(1)] = json.loads(raw_param.replace("(", "[").replace(")", "]"))
        material = {"shader": "res://PvE/Items/ItemDissolve.gdshader", "params": params}
    icon_data = {
        "texture": tex,
        "position": ([float(v) for v in pos_m.group(1).split(",")] if pos_m else [0.0, 0.0]),
        "scale": ([float(v) for v in scale_m.group(1).split(",")] if scale_m else [2.0, 2.0]),
        "material": material,
    }
    # --- Sockets scale（允许缺失）---
    socks = re.search(r'\[node name="Sockets" parent="Icon" index="\d+"\]\s*\nscale = Vector2\(([^)]+)\)', text)
    sockets_scale = [float(v) for v in socks.group(1).split(",")] if socks else None
    # --- 宝石孔（Icon/Sockets 下实例化的 GemSocket.tscn）。原版每孔只有 position 一项覆盖；
    #     出现别的属性 = 孔位结构超出本刀范围，停手汇报。---
    gem_sockets = []
    socket_nodes = list(re.finditer(r'\[node name="([^"]+)"(?: type="(\w+)")? parent="Icon/Sockets" index="\d+"(?: instance=ExtResource\("([^"]+)"\))?\]', text))
    for sm in socket_nodes:
        name, ntype, inst = sm.group(1), sm.group(2), sm.group(3)
        assert inst is not None and ext[inst][1] == "res://Items/GemSocket.tscn", \
            f"{path.name}: Sockets 下 {name} 不是 GemSocket 实例，停手汇报"
        block_end = text.find("\n[node", sm.end())
        block = text[sm.end():block_end if block_end != -1 else len(text)]
        keys = re.findall(r'^(\w+) = ', block, re.M)
        assert set(keys) <= {"position"}, f"{path.name}: 宝石孔 {name} 有未覆盖属性 {keys}，停手汇报"
        pos_m = re.search(r'position = Vector2\(([^)]+)\)', block)
        gem_sockets.append({"name": name,
                            "position": [float(v) for v in pos_m.group(1).split(",")] if pos_m else [0.0, 0.0]})
    # --- ClickArea polygon（宝石场景不覆盖；部分物品多一行 visible = false，允许缺失）---
    click = re.search(
        r'\[node name="CollisionPolygon2D" parent="ClickArea" index="0"\]\s*\n(?:visible = false\s*\n)?polygon = PackedVector2Array\(([^)]*)\)', text)
    # ClickArea 只改了 position、没重述 polygon 的场景（Spring Loader）：位置必须进数据，
    # 否则多边形会带着基场景的 0 偏移悄悄错位。
    click_position = None
    click_block = re.search(r'\[node name="CollisionPolygon2D" parent="ClickArea" index="0"\]\s*\n(.*?)(?=\n\[|\s*\Z)', text, re.S)
    if click_block:
        cp = re.search(r'position = Vector2\(([^)]+)\)', click_block.group(1))
        if cp:
            click_position = [float(v) for v in cp.group(1).split(",")]
    # ClickArea 节点自身的属性覆盖：position（Laboratory 17,-19、Chainsaw 0,-99）+ visible
    # （基场景默认 false，4 件覆盖 true）。基默认不进数据；出现别的属性 = 停手汇报。
    # 注：Chainsaw 的 position 是第六刀漏收的真 bug（点击区错位 -99px），本刀顺手修。
    click_area_position = None
    click_area_visible = None
    ca_block = re.search(r'\[node name="ClickArea" parent="\." index="\d+"\]\s*\n(.*?)(?=\n\[|\s*\Z)', text, re.S)
    if ca_block and ca_block.group(1).strip():
        ca_keys = set(re.findall(r'^(\w+) = ', ca_block.group(1), re.M))
        assert ca_keys <= {"position", "visible"}, f"{path.name}: ClickArea 有未知属性 {ca_keys}，停手汇报"
        cap = re.search(r'position = Vector2\(([^)]+)\)', ca_block.group(1))
        if cap:
            click_area_position = [float(v) for v in cap.group(1).split(",")]
        cav = re.search(r'visible = (\w+)', ca_block.group(1))
        if cav:
            assert cav.group(1) == "true", f"{path.name}: ClickArea visible={cav.group(1)}，停手汇报"
            click_area_visible = True
    # 场景没覆盖点击多边形 = 继承基场景（Pot 就属于这种），由 build 补默认值；
    # 宝石场景则继承 Gems/Gem.tscn 的 -32 方块，不能在场景层塞默认值。
    click_poly = json.loads("[" + click.group(1).replace(", ", ",") + "]") if click else None
    # --- BottomCenter ---
    bc = re.search(r'\[node name="BottomCenter" parent="\." index="\d+"\]\s*\nposition = Vector2\(([^)]+)\)', text)
    bottom_center = [float(v) for v in bc.group(1).split(",")] if bc else None
    # --- 根下碰撞形状（CollisionPolygon2D；index 不限，visible 行可省=继承基场景的 false；
    #     type= 可省——继承节点的覆盖段不重述 type，宝石场景就是这种情况）---
    body = re.search(
        r'\[node name="CollisionPolygon2D"(?: type="CollisionPolygon2D")? parent="\." index="\d+"\]\s*\n(?:visible = false\s*\n)?(?:position = Vector2\(([^)]+)\)\s*\n)?polygon = PackedVector2Array\(([^)]*)\)',
        text)
    body_collision = None
    if body:
        body_pos = [float(v) for v in body.group(1).split(",")] if body.group(1) else [0.0, 0.0]
        body_collision = {"type": "polygon", "position": body_pos,
                          "polygon": json.loads("[" + body.group(2).replace(", ", ",") + "]")}
    # --- 根下碰撞形状槽位（CollisionShape2D + 内嵌 Shape2D 子资源；装备触发区的感应范围）---
    #     只认圆/胶囊/矩形三种形状；节点属性只认 visible(false)/position/rotation/shape，
    #     出现别的 = 超出本刀范围，停手汇报。
    collision_shape = None
    cs_node = re.search(
        r'\[node name="CollisionShape2D" type="CollisionShape2D" parent="\." index="\d+"\]\s*\n(.*?)(?=\n\[|\s*\Z)', text, re.S)
    if cs_node:
        blk = cs_node.group(1)
        keys = set(re.findall(r'^(\w+) = ', blk, re.M))
        assert keys <= {"visible", "position", "rotation", "shape"}, \
            f"{path.name}: 碰撞形状节点有未覆盖属性 {keys}，停手汇报"
        vis_m = re.search(r'visible = (\w+)', blk)
        assert vis_m is None or vis_m.group(1) == "false", \
            f"{path.name}: 碰撞形状 visible 不是 false？停手汇报"
        pos_m = re.search(r'position = Vector2\(([^)]+)\)', blk)
        rot_m = re.search(r'rotation = ([\d.eE+-]+)', blk)
        sub_m = re.search(r'shape = SubResource\("([^"]+)"\)', blk)
        assert sub_m, f"{path.name}: 碰撞形状 shape 不是内嵌 SubResource，停手汇报"
        sr_m = re.search(r'\[sub_resource type="(\w+Shape2D)" id="' + re.escape(sub_m.group(1)) + r'"\]\s*\n(.*?)(?=\n\[|\s*\Z)', text, re.S)
        assert sr_m, f"{path.name}: 找不到 shape 子资源 {sub_m.group(1)}，停手汇报"
        stype = sr_m.group(1)
        assert stype in ("CircleShape2D", "CapsuleShape2D", "RectangleShape2D"), \
            f"{path.name}: 未知形状类型 {stype}，停手汇报"
        params = {}
        for pm in re.finditer(r'^(\w+) = (.+)$', sr_m.group(2), re.M):
            k, v = pm.group(1), pm.group(2).strip()
            if v.startswith("Vector2("):
                params[k] = [float(x) for x in v[8:-1].split(",")]
            else:
                params[k] = float(v)
        collision_shape = {"type": stype, "params": params,
                            "position": [float(v) for v in pos_m.group(1).split(",")] if pos_m else [0.0, 0.0]}
        if rot_m:
            collision_shape["rotation"] = float(rot_m.group(1))
    # --- 额外节点（如 Rope 的 SpeedTimer、粒子槽位的 SpecificDragParticles）。
    #     只在 capture_extras 时收集；宝石的共享节点由 GemBase.tscn 承担，不进数据。---
    extra_nodes = []
    if capture_extras:
        # 结构总账：除了固定接口节点、宝石孔、点击区多边形，其余节点必须落在额外节点白名单里，
        # 且不得再带子节点。宁可拦下，不允许「漏收养出一个少动画的物品」。
        for m in re.finditer(r'\[node name="([^"]+)"(?: type="(\w+)")?(?: parent="([^"]+)")?(?: index="\d+")?(?: instance=ExtResource\("([^"]+)"\))?\]', text):
            name, ntype, nparent, ninst = m.group(1), m.group(2), m.group(3), m.group(4)
            if nparent is None:
                continue
            if nparent == "." and name in KNOWN_CHILDREN:
                continue
            if nparent == "Icon" and name == "Sockets":
                continue
            if nparent == "Icon" and name in skip_on_icon:
                continue
            # 动画包成员的子节点（如 Icon/TorchLight 下的闪烁 AnimationPlayer）进包场景，跳过；
            # 更深的层级（Icon/TorchLight/Xxx 的孙节点）不跳——落到下方断言拦下，防静默丢失。
            if nparent.startswith("Icon/") and nparent.count("/") == 1 \
                    and nparent.split("/")[1] in skip_on_icon:
                continue
            if nparent == "Icon/Sockets":
                continue
            if nparent == "ClickArea" and name == "CollisionPolygon2D":
                continue
            if nparent in EXTRA_NODE_PARENTS:
                if ninst is not None:
                    # 整场景实例（如 SkillLight.tscn）：子树由原场景自带，允许。
                    assert ntype is None, f"{path.name}: 额外节点 {name} 同时有 type 和 instance，停手汇报"
                    assert ext[ninst][0] == "PackedScene", f"{path.name}: 额外节点 {name} 实例不是 PackedScene，停手汇报"
                else:
                    assert ntype is not None and ntype in EXTRA_NODE_TYPES, \
                        f"{path.name}: 额外节点 {name} 类型 {ntype} 不在白名单，停手汇报"
            else:
                assert False, f"{path.name}: 节点 {name}（parent={nparent}）是额外节点 {nparent.split('/')[0]} 的子结构，本刀不支持，停手汇报"
        # 先收集全部信号连接，校验 from 必须指向额外节点、to 必须是根
        all_connections = [(c.group(1), c.group(2), c.group(3), c.group(4))
                           for c in re.finditer(r'\[connection signal="(\w+)" from="([^"]+)" to="([^"]+)" method="(\w+)"\]', text)]
        extra_names = {m.group(1) for m in re.finditer(r'\[node name="(\w+)"(?: type="\w+")? parent="(\.|Icon)" index="\d+"(?: instance=ExtResource\("[^"]+"\))?\]', text)
                       if not (m.group(2) == "." and m.group(1) in KNOWN_CHILDREN)
                       and not (m.group(2) == "Icon" and m.group(1) in skip_on_icon)}
        for sig, frm, to, _method in all_connections:
            assert frm in extra_names, f"{path.name}: 连接来源 {frm} 不是额外节点，停手汇报"
            assert to == ".", f"{path.name}: 连接目标 {to} 不是根节点，停手汇报"
        for m in re.finditer(r'\[node name="(\w+)"(?: type="(\w+)")? parent="(\.|Icon)" index="\d+"(?: instance=ExtResource\("([^"]+)"\))?\]\s*\n(.*?)(?=\n\[|\s*\Z)', text, re.S):
            name, ntype, nparent, ninst, block = m.group(1), m.group(2), m.group(3), m.group(4), m.group(5)
            if nparent == "." and name in KNOWN_CHILDREN:
                continue
            if nparent == "Icon" and name in skip_on_icon:
                continue
            if nparent == "Icon" and name == "Sockets":
                continue
            if ninst is not None:
                spec = {"name": name, "scene": ext[ninst][1]}
            else:
                assert ntype in EXTRA_NODE_TYPES, f"{path.name}: 额外节点 {name} 类型 {ntype} 不在白名单，停手汇报"
                spec = {"name": name, "type": ntype}
            assert nparent in EXTRA_NODE_PARENTS, f"{path.name}: 额外节点 {name} 挂载 {nparent} 不在白名单，停手汇报"
            if nparent != ".":
                spec["parent"] = nparent
            script_m = re.search(r'script = ExtResource\("([^"]+)"\)', block)
            props = {}
            for pm_line in re.finditer(r'^(\w+) = (.+)$', block, re.M):
                key, value = pm_line.group(1), pm_line.group(2)
                if key == "script":
                    continue
                props[key] = _prop_value(value, ext, subres_ctx)
            if props:
                spec["props"] = props
            if script_m:
                spec["script"] = ext[script_m.group(1)][1]
            connections = [{"signal": sig, "method": method}
                            for sig, frm, _to, method in all_connections if frm == name]
            if connections:
                spec["connections"] = connections
            extra_nodes.append(spec)

    return {
        "root_name": root_name,
        "script": script,
        "root_props": root_props,
        "physics": {"friction": friction, "bounce": bounce},
        "icon": icon_data,
        "collision_map": collision_map,
        "sockets_scale": sockets_scale,
        "click_polygon": click_poly,
        "click_position": click_position,
        "click_area_position": click_area_position,
        "click_area_visible": click_area_visible,
        "bottom_center": bottom_center,
        "body_collision": body_collision,
        "gem_sockets": gem_sockets,
        "collision_shape": collision_shape,
        "extra_nodes": extra_nodes,
    }


def merge(base: dict, overlay: dict) -> dict:
    """场景合并语义：overlay 里非 None 的字段覆盖 base。宝石 = Gem.tscn 基 + 宝石场景覆盖。"""
    eff = {}
    for key in overlay:
        ov = overlay[key]
        if isinstance(ov, dict) and key == "icon":
            eff[key] = {k: (ov[k] if ov[k] is not None else base[key][k]) for k in ov}
        elif key in ("extra_nodes", "gem_sockets"):
            eff[key] = ov or base.get(key) or []
        else:
            eff[key] = ov if ov is not None else base[key]
    # 必有字段断言：合并完不允许缺
    for key in ("collision_map", "click_polygon", "bottom_center", "body_collision", "sockets_scale"):
        assert eff.get(key) is not None, f"合并后 {key} 缺失，停手汇报"
    return eff


def build() -> dict:
    out = {"_format": "item_template_overrides_v1",
           "_note": "新基场景 PvE/Items/ItemBase.tscn（宝石用 GemBase.tscn）+ 本数据运行时覆盖；来源=原版场景逐字段提取"}
    items = {}
    for scene_stem, cfg in sorted(SCENES.items()):
        if cfg["base"] == "gem":
            # 先解析共享基 Gem.tscn（其共享额外节点由 GemBase.tscn 承担，不捕获），
            # 再解析宝石场景自身覆盖，按场景合并语义叠加。
            # Gem.tscn 是 Item.tscn 的实例，按 item 基解析；
            # 其共享额外节点由 GemBase.tscn 承担，不捕获。
            base_data = parse_tscn(ROOT / "Items" / "Gems" / "Gem.tscn", "item", capture_extras=False)
            scene_data = parse_tscn(ROOT / "Items" / "Gems" / f"{scene_stem}.tscn", "gem", capture_extras=True)
            data = merge(base_data, scene_data)
            data["template_scene"] = GEM_TEMPLATE
            # GemBase.tscn 承担的共享节点 + 动画，进数据供 QA 在实例上断言
            data["interface_nodes"] = ["SocketDetectionArea", "SocketDetectionArea/CollisionShape2D", "GemAnimation"]
            data["required_animations"] = {"GemAnimation": ["Sparkle", "HotSwapHover"]}
        else:
            sub = cfg.get("sub", "")
            scene_path = ROOT / "Items" / sub / f"{scene_stem}.tscn" if sub else ROOT / "Items" / f"{scene_stem}.tscn"
            data = parse_tscn(scene_path, "item", capture_extras=True,
                              anim_targets=set(cfg.get("anim_targets", ())))
            # 动画包：目标节点+AnimationPlayer 已抽进 PvE/Items/Anims/<Stem>Anim.tscn，这里挂引用。
            # 包实例名三选一：B 模式=AnimationPlayer（Chainsaw 原位）、C 模式=目标名（Icon/TorchLight 路径不变）、A 模式=<Stem>Anim。
            if cfg.get("anim_targets") or cfg.get("anim_root_player"):
                if cfg.get("anim_root_player"):
                    bundle_name = "AnimationPlayer"
                elif cfg.get("anim_root_target"):
                    bundle_name = str(cfg["anim_root_target"])
                else:
                    bundle_name = f"{scene_stem}Anim"
                data["extra_nodes"].append({"name": bundle_name,
                                             "scene": f"res://PvE/Items/Anims/{scene_stem}Anim.tscn",
                                             "parent": "Icon"})
            # 动画包内的 AnimationPlayer 动画清单（QA 走既有 required_animations 机制断言）
            if cfg.get("required_animations"):
                data["required_animations"] = cfg["required_animations"]
            if data["click_polygon"] is None:
                base_text = (ROOT / "Items" / "Item.tscn").read_text(encoding="utf-8")
                base_click = re.search(
                    r'\[node name="CollisionPolygon2D" type="CollisionPolygon2D" parent="ClickArea"\]\s*\npolygon = PackedVector2Array\(([^)]*)\)', base_text)
                assert base_click, f"{scene_stem}: 点击多边形既没覆盖也找不到基场景默认值，停手汇报"
                data["click_polygon"] = [float(v) for v in base_click.group(1).split(",")]
            if data["sockets_scale"] is None:
                # 基场景 Item.tscn 的 Sockets 默认 scale（未覆盖 = 继承此值）
                data["sockets_scale"] = [0.5, 0.5]
            if data["collision_map"] is None:
                # 基场景 CollisionMap 默认 tile_data 解码：4 格方块 (-1,-1)(0,-1)(-1,0)(0,0)，source_id=3
                data["collision_map"] = {"position": [0.0, 0.0],
                                          "cells": [[-1, -1, 3], [0, -1, 3], [-1, 0, 3], [0, 0, 3]]}
            if data["bottom_center"] is None:
                # 基场景 BottomCenter 默认 (0, 32)
                data["bottom_center"] = [0.0, 32.0]
            for key in ("collision_map", "click_polygon", "bottom_center", "sockets_scale"):
                assert data[key] is not None, f"{scene_stem}: {key} 缺失，停手汇报"
            # 物理体二选一：多边形（CollisionPolygon2D）或形状（CollisionShape2D：圆/胶囊/矩形）
            assert data["body_collision"] is not None or data.get("collision_shape") is not None, \
                f"{scene_stem}: 物理体缺失（既无 body_collision 也无 collision_shape），停手汇报"
        # 只在非默认时输出新键，试点 3 件的输出保持字节不变
        if not data["extra_nodes"]:
            data.pop("extra_nodes")
        if not data.get("gem_sockets"):
            data.pop("gem_sockets", None)
        if data.get("collision_shape") is None:
            data.pop("collision_shape", None)
        if data.get("click_position") is None:
            data.pop("click_position", None)
        if not data.get("root_props"):
            data.pop("root_props", None)
        if data.get("click_area_position") is None:
            data.pop("click_area_position", None)
        if data.get("click_area_visible") is None:
            data.pop("click_area_visible", None)
        data["definition_ids"] = cfg["ids"]
        items[scene_stem] = data
    out["items"] = items
    return out


def main() -> int:
    fresh = build()
    if "--check" in sys.argv:
        if not OUT.exists():
            print("OVERRIDES_MISSING")
            return 1
        current = json.loads(OUT.read_text(encoding="utf-8-sig"))
        if current == fresh:
            print("OVERRIDES_IN_SYNC")
            return 0
        print("OVERRIDES_STALE")
        return 1
    OUT.write_text(json.dumps(fresh, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print("WROTE", OUT, "items:", len(fresh["items"]))
    for name, data in fresh["items"].items():
        extras = ",".join(n["name"] for n in data.get("extra_nodes", []))
        tmpl = data.get("template_scene", "ItemBase")
        print(f"  {name}: cells={len(data['collision_map']['cells'])} "
              f"material={'dissolve' if data['icon']['material'] else 'base'} "
              f"template={tmpl} extras=[{extras}]")
    return 0


if __name__ == "__main__":
    sys.exit(main())
