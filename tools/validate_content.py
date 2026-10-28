"""Independent configuration audit: references, frozen scope, route reachability and full geometry."""
from __future__ import annotations
import argparse, json, re, sys
from pathlib import Path

def split(value):
    return str(value or '').split('|') if value else []

def params(value):
    if isinstance(value, dict): return dict(value)
    return {token.partition(':')[0]:token.partition(':')[2] if ':' in token else True for token in split(value)}

def validate(tables, source=None, check_assets=True, asset_project=None):
    errors, warnings = [], []
    counts = {'tables':len(tables), 'rows':sum(map(len,tables.values())), 'layouts':0, 'content_pool_checks':0,
              'reference_checks':0, 'parameter_checks':0, 'localized_keys':0}
    def fail(message): errors.append(message)
    def rows(name):
        if name not in tables: fail('缺少配置表：'+name)
        return tables.get(name, [])
    def by(name, field='id'): return {str(row[field]):row for row in rows(name)}
    def fk(name, column, target, field='id', optional=False, allowed=()):
        targets = by(target, field)
        for row in rows(name):
            for value in split(row.get(column,'')) or ([] if optional else ['']):
                counts['reference_checks'] += 1
                if str(value) not in targets and value not in allowed:
                    fail(f'{name}.{column}：缺少引用 {target}.{field}={value}')
    if len(tables) != 57: fail('应有56张内容表及1张清单；实际表数'+str(len(tables)))
    manifest=rows('config_manifest');listed={row['file'] for row in manifest}
    expected={name+'.csv' for name in tables if name!='config_manifest'}
    if listed != expected or len(manifest)!=56: fail('配置清单必须且只能覆盖全部56张内容表')
    for entry in manifest:
        if len(tables.get(str(entry['file']).removesuffix('.csv'),[])) != entry['row_count']:
            fail('清单行数不符：'+entry['file'])
    for name, records in tables.items():
        for row in records:
            for column,value in row.items():
                if column=='id' or column.endswith('_id'):
                    for token in split(value):
                        if not re.fullmatch('[a-z][a-z0-9_]*',str(token)): fail(f'{name}.{column}：非法稳定ID {token}')
    specifications='''items rarity rarities
items shape_id item_shapes
items tags tags
item_effects item_id items
item_effects trigger_id trigger_templates
item_effects condition_id condition_templates
item_effects spatial_template_id spatial_templates
item_effects effect_type effect_templates
characters passive_id character_passives
characters exclusive_tags tags
character_passives character_id characters
character_passives trigger_id trigger_templates
character_passives condition_id condition_templates
character_passives effect_type effect_templates
character_archetypes character_id characters
character_archetypes primary_tags tags
character_archetypes counter_tags tags
character_loadouts character_id characters
character_loadouts archetype_hint character_archetypes
character_loadouts starting_items items
character_loadouts starting_bag_id bags
starting_build_items loadout_id character_loadouts
starting_build_items item_id items
bags rarity rarities
bags shape_id bag_shapes
recipes result_item_id items
recipe_ingredients recipe_id recipes
recipe_ingredients item_id items
shop_slot_rules shop_rule_id shop_rules
shop_rarity_curve act_id acts
economy_curve act_id acts
act_progression act_id acts
node_templates reward_table_id reward_tables
route_templates act_id acts
route_templates allowed_nodes node_templates
route_templates required_nodes node_templates
enemy_archetypes threat_tags tags
enemy_archetypes weakness_tags tags
enemy_builds act_id acts
enemy_builds archetype_id enemy_archetypes
enemy_builds difficulty_min difficulty_levels
enemy_builds difficulty_max difficulty_levels
enemy_builds threat_tags tags
enemy_builds weakness_tags tags
enemy_build_bags enemy_build_id enemy_builds
enemy_build_bags bag_id bags
enemy_build_items enemy_build_id enemy_builds
enemy_build_items item_id items
encounter_affixes trigger_id trigger_templates
encounter_affixes effect_type effect_templates
encounter_templates act_id acts
encounter_templates node_type node_templates
encounter_templates enemy_build_pool enemy_builds
encounter_templates reward_table_id reward_tables
bosses act_id acts
bosses reward_table_id reward_tables
bosses threat_tags tags
bosses weakness_tags tags
boss_phases boss_id bosses
boss_build_items boss_id bosses
boss_build_items item_id items
reward_entries reward_table_id reward_tables
reward_entries reward_type run_effect_templates
event_choices event_id events
event_choice_effects choice_id event_choices
event_choice_effects effect_type run_effect_templates
rest_action_effects rest_action_id rest_actions
rest_action_effects effect_type run_effect_templates
achievements stat_key stat_definitions
stat_definitions source_metric telemetry_metrics'''
    for spec in specifications.splitlines():
        name,column,target=spec.split();fk(name,column,target,optional=column=='required_nodes')
    fk('enemy_builds','affix_id','encounter_affixes',optional=True)
    fk('encounter_templates','affix_pool','encounter_affixes',optional=True)
    fk('node_templates','shop_rule_id','shop_rules',allowed=('none',))
    frozen={'items':72,'bags':10,'recipes':24,'recipe_ingredients':48,'characters':2,
      'character_archetypes':6,'character_loadouts':4,'difficulty_levels':8,'enemy_builds':30,
      'bosses':3,'boss_phases':6,'events':12,'reward_tables':5,'reward_entries':20,
      'tutorial_steps':16,'achievements':20,'telemetry_metrics':24,'stat_definitions':19,'rest_actions':2}
    for name, count in frozen.items():
        if len(rows(name)) != count: fail(f'{name}：冻结数量应为{count}，实际{len(rows(name))}')
    for act in rows('acts'):
        enemies=[row for row in rows('enemy_builds') if row['act_id']==act['id']]
        if sum(r['node_type']=='normal' for r in enemies)!=8 or sum(r['node_type']=='elite' for r in enemies)!=2:
            fail(act['id']+'：敌人模板必须8普通+2精英')
    locale_maps=[by('localization_zh_cn','key'),by('localization_en','key')]
    if set(locale_maps[0]) != set(locale_maps[1]): fail('中英文文本键不一致')
    counts['localized_keys']=len(locale_maps[0])
    for language,locale in zip(('zh_CN','en'),locale_maps):
        for key,row in locale.items():
            if not row['text']: fail(language+'：空文本 '+key)
            if language=='en' and re.search('[\u3400-\u9fff]',row['text']): fail('英文文本仍含中文：'+key)
    for name,records in tables.items():
        for row in records:
            for column in ('name_key','description_key','text_key','title_key','body_key'):
                if column in row and any(row[column] not in locale for locale in locale_maps): fail(f'{name}.{column}：缺少双语文本 {row[column]}')
    shape_lookup={**by('item_shapes'),**by('bag_shapes')};item_lookup=by('items');bag_lookup=by('bags')
    def cells(shape, rotation=0, origin=(0,0)):
        raw=[tuple(map(int,cell.split(':'))) for cell in split(shape['cells'])]
        for unused in range(int(rotation)//90): raw=[(-y,x) for x,y in raw]
        minimum=(min(x for x,y in raw),min(y for x,y in raw))
        return {(x-minimum[0]+origin[0],y-minimum[1]+origin[1]) for x,y in raw}
    for name in ('item_shapes','bag_shapes'):
        for shape in rows(name):
            try:
                shape_cells=cells(shape)
                if len(shape_cells)!=shape['cell_count'] or len(shape_cells)!=len(split(shape['cells'])): fail(shape['id']+'：形状格数或重复格错误')
                if not {int(v) for v in split(shape['allowed_rotations'])} <= {0,90,180,270}: fail(shape['id']+'：旋转枚举非法')
                connected={next(iter(shape_cells))};pending=list(connected)
                while pending:
                    x,y=pending.pop()
                    for c in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
                        if c in shape_cells and c not in connected: connected.add(c);pending.append(c)
                if connected != shape_cells: fail(shape['id']+'：形状不是四向连通')
            except (ValueError,KeyError,StopIteration): fail(shape['id']+'：形状或坐标无法解析')
    for bag in rows('bags'):
        if not set(tuple(map(int,c.split(':'))) for c in split(bag['special_cells'])) <= cells(shape_lookup[bag['shape_id']]): fail(bag['id']+'：特殊格越出背包')
    rules={r['key']:r['value'] for r in rows('game_rules')};width=int(rules.get('grid_width',9));height=int(rules.get('grid_height',7))
    def layout(label,bags,items):
        counts['layouts']+=1;covered=set();occupied=set();uids=set()
        for kind,entries,definitions in (('背包',bags,bag_lookup),('物品',items,item_lookup)):
            for entry in entries:
                uid=entry.get('instance_id','bag'+str(len(covered)))
                if kind=='物品' and uid in uids: fail(label+'：重复物品实例 '+uid)
                if kind=='物品': uids.add(uid)
                definition=definitions.get(entry.get('bag_id' if kind=='背包' else 'item_id'))
                if not definition: continue
                shape=shape_lookup[definition['shape_id']];rotation=entry.get('rotation',0)
                if rotation not in [int(v) for v in split(shape['allowed_rotations'])]: fail(label+'：不允许的旋转 '+uid)
                current=cells(shape,rotation,(entry['origin_x'],entry['origin_y']))
                if any(x<0 or y<0 or x>=width or y>=height for x,y in current): fail(label+'：'+kind+'超出9×7画布 '+uid)
                if kind=='背包':
                    if current & covered: fail(label+'：背包相互重叠 '+uid)
                    covered |= current
                else:
                    if not current <= covered: fail(label+'：物品未完全放进背包 '+uid)
                    if current & occupied: fail(label+'：物品相互重叠 '+uid)
                    occupied |= current
    for loadout in rows('character_loadouts'):
        starters=[r for r in rows('starting_build_items') if r['loadout_id']==loadout['id']]
        if sorted(r['item_id'] for r in starters)!=sorted(split(loadout['starting_items'])): fail(loadout['id']+'：开局物品列表与布局不一致')
        layout(loadout['id'],[dict(bag_id=loadout['starting_bag_id'],origin_x=0,origin_y=0,rotation=0)],starters)
    for enemy in rows('enemy_builds'):
        layout(enemy['id'],[r for r in rows('enemy_build_bags') if r['enemy_build_id']==enemy['id']],
               [r for r in rows('enemy_build_items') if r['enemy_build_id']==enemy['id']])
    for boss in rows('bosses'):
        bags=[]
        if not boss.get('bag_layout'): fail(boss['id']+'：缺少Boss必须遵守的背包布局规则')
        for index,token in enumerate(split(boss.get('bag_layout'))):
            try:
                bag,x,y,rotation=token.split(':');bags.append(dict(bag_id=bag,origin_x=int(x),origin_y=int(y),rotation=int(rotation),instance_id='bag'+str(index)))
                if bag not in bag_lookup: fail(boss['id']+'：Boss背包引用不存在 '+bag)
            except ValueError: fail(boss['id']+'：Boss背包布局字段非法 '+token)
        phases=sorted([r for r in rows('boss_phases') if r['boss_id']==boss['id']],key=lambda r:r['phase'])
        if [r['phase'] for r in phases]!=[1,2]: fail(boss['id']+'：必须且只能有两个阶段')
        if phases and (phases[0]['health_threshold_pct']!=1 or phases[-1]['health_threshold_pct']>=1): fail(boss['id']+'：阶段生命阈值错误')
        for phase in (1,2):
            layout(boss['id']+'_phase_'+str(phase),bags,[r for r in rows('boss_build_items') if r['boss_id']==boss['id'] and r['phase']<=phase])
        for row in rows('boss_build_items'):
            if row['boss_id']==boss['id'] and row['phase'] not in (1,2): fail(boss['id']+'：物品引用不存在阶段')
    # Route states retain previous node type and exact battle count across all reachable choices.
    node_lookup=by('node_templates');states={('',0,0)}
    noncombat_cap=int(rules.get('max_noncombat_nodes_per_act',1))
    if noncombat_cap!=1: fail('D02要求每章最多1个纯非战斗节点，以保证12至15场战斗')
    for act in sorted(rows('acts'),key=lambda a:a['order']):
        states={(previous,battles,0) for previous,battles,unused in states}
        steps=sorted([r for r in rows('route_templates') if r['act_id']==act['id']],key=lambda r:r['step'])
        if [r['step'] for r in steps]!=[1,2,3,4,5]: fail(act['id']+'：必须有1至5节点')
        elite_candidates=False
        for step in steps:
            allowed=set(split(step['allowed_nodes']));required=set(split(step['required_nodes']));low=step['candidate_count_min'];high=step['candidate_count_max']
            if not required <= allowed: fail(step['id']+'：必选候选不在允许节点集合')
            if step['step']==5:
                if allowed!={'boss'} or required!={'boss'} or low!=1 or high!=1: fail(step['id']+'：章末Boss必须唯一强制节点')
            elif not (2<=low<=high<=3): fail(step['id']+'：非Boss候选数量必须2至3')
            if len(required)>low: fail(step['id']+'：必选候选数量超过最少候选数')
            next_states=set()
            for previous,battle_count,noncombat_count in states:
                eligible={node for node in allowed if (previous not in split(step['forbid_previous_types']) or node_lookup.get(node,{}).get('node_type') in ('combat','boss')) and (node_lookup.get(node,{}).get('node_type') in ('combat','boss') or noncombat_count<noncombat_cap)}
                if not required <= eligible: fail(step['id']+'：前序'+previous+'会禁用强制候选')
                if len(eligible)<low: fail(step['id']+'：前序'+previous+'后可用候选不足')
                for node in eligible:
                    kind=node_lookup.get(node,{}).get('node_type','')
                    next_states.add((kind,battle_count+int(kind in ('combat','boss')),noncombat_count+int(kind not in ('combat','boss'))))
            states=next_states
            elite_candidates |= 'elite_combat' in required
        if not elite_candidates: fail(act['id']+'：未保证至少一个精英候选')
    route_range={'min':min((s[1] for s in states),default=0),'max':max((s[1] for s in states),default=0)}
    if route_range['min']<12 or route_range['max']>15: fail('D02可达战斗数必须12至15，实际'+str(route_range))
    ingredients={};recipe_by_result=by('recipes','result_item_id')
    for row in rows('recipe_ingredients'): ingredients.setdefault(row['recipe_id'],[]).append(row['item_id'])
    def depth(item,stack=()):
        if item not in recipe_by_result: return 0
        if item in stack: fail('配方循环：'+item);return 99
        recipe=recipe_by_result[item]
        return 1+max((depth(i,stack+(item,)) for i in ingredients.get(recipe['id'],[])),default=0)
    for recipe in rows('recipes'):
        current=ingredients.get(recipe['id'],[])
        if len(current)!=2 or recipe['result_item_id'] in current: fail(recipe['id']+'：配方必须两材料且结果不能作自身材料')
        if depth(recipe['result_item_id'])!=recipe['tier'] or recipe['tier']>2: fail(recipe['id']+'：配方深度与tier不一致或超过二阶')
    unlock_targets={'character':'characters','loadout':'character_loadouts','difficulty':'difficulty_levels'}
    for unlock in rows('unlock_rules'):
        kind=unlock['unlock_type'];target=unlock['target_id']
        if kind not in unlock_targets or target not in by(unlock_targets[kind]): fail(unlock['id']+'：解锁目标不存在')
        if kind in ('character','loadout') and unlock['requirement_type']!='default': fail(unlock['id']+'：两角色及其两套开局必须默认可选')
    if any('numeric_tier' in r or 'numeric_tier_delta' in str(r) for records in tables.values() for r in records): fail('冻结范围禁止独立物品数值强化等级')
    run_templates=by('run_effect_templates');statuses=by('statuses');tags=by('tags')
    for name, effect_column in (('event_choice_effects','effect_type'),('rest_action_effects','effect_type'),('reward_entries','reward_type')):
        for row in rows(name):
            effect=row[effect_column];parsed=params(row['params']);counts['parameter_checks']+=1
            if effect not in run_templates: continue
            for token in split(run_templates[effect]['param_format']):
                key,unused,kind=token.partition(':')
                if key not in parsed: fail(f'{name} {effect}：缺少参数 {key}');continue
                try:
                    if kind=='int' and not re.fullmatch(r'-?\d+',str(parsed[key])): raise ValueError()
                    if kind=='float': float(parsed[key])
                except ValueError: fail(f'{name} {effect}：参数 {key} 类型应为 {kind}')
            if effect=='upgrade_item' and (parsed.get('mode')!='defined_recipe' or str(parsed.get('tier_max'))!='2' or float(parsed.get('fallback_discount',0))!=0.2): fail(name+'：升级只能复用二阶配方，否则20%商店券')
            if effect=='specific_item' and parsed.get('item_id',row.get('content_id')) not in item_lookup: fail(name+'：指定物品参数引用不存在')
            for key,target in (('rarity',by('rarities')),('tag',tags)):
                if key in parsed:
                    for token in str(parsed[key]).split('_or_'):
                        if token not in target: fail(name+'：参数'+key+'引用不存在 '+token)
    for name in ('item_effects','character_passives','encounter_affixes'):
        for row in rows(name):
            parsed=params(row.get('effect_params',''));counts['parameter_checks']+=1
            if row['effect_type']=='apply_status':
                status=str(parsed.get('status_id',parsed.get('value',''))).split(':')[0]
                dynamic_echo = row.get('trigger_id')=='status_applied' and 'repeat_pct' in parsed and 0<float(parsed['repeat_pct'])<=1
                if status not in statuses and not dynamic_echo: fail(name+'：状态参数引用不存在 '+status)
            if name=='item_effects' and row['trigger_id'] in ('attack_hit','target_activated','damage_taken','armor_gained','status_applied','interval') and row['internal_cooldown']<0.5: fail(row['id']+'：高频触发内置冷却至少0.5秒')
            condition=row.get('condition_id','');raw=str(row.get('condition_params',''))
            if condition in ('source_has_tag','target_has_tag') and raw and ':' not in raw and raw not in tags: fail(name+'：条件标签引用不存在 '+raw)
            if condition=='enemy_has_status' and raw and ':' not in raw and raw not in statuses: fail(name+'：条件状态引用不存在 '+raw)
    for parent_name, effects_name, key in (('event_choices','event_choice_effects','choice_id'),('rest_actions','rest_action_effects','rest_action_id')):
        for parent in rows(parent_name):
            if parent['effect_count']!=sum(r[key]==parent['id'] for r in rows(effects_name)): fail(parent['id']+'：效果条目数与声明不一致')
    for event in rows('events'):
        if not 2<=sum(r['event_id']==event['id'] for r in rows('event_choices'))<=3: fail(event['id']+'：事件必须2至3个选择')
    for rest in rows('rest_action_effects'):
        if rest['rest_action_id']=='rest_recover' and not .25<=float(params(rest['params']).get('amount',0))<=.35: fail('休息恢复量必须25%至35%')
    for row in rows('shop_rarity_curve'):
        if abs(sum(row[k+'_weight'] for k in ('common','rare','legendary'))-1)>1e-9: fail(row['act_id']+'：商店稀有度概率和不为1')
    for name in ('shop_pool_weights','reward_entries','events'):
        if any(row['weight']<=0 for row in rows(name)): fail(name+'：权重必须为正')
    def content_pool(effect,parsed,act,character):
        result=[];is_bag=effect=='bag_pool'
        for row in rows('bags' if is_bag else 'items'):
            if row['chapter_min']>act and str(parsed.get('ignore_chapter_gate','false'))!='true': continue
            if parsed.get('rarity') and row['rarity'] not in str(parsed['rarity']).split('_or_'): continue
            if not is_bag:
                owner=parsed.get('owner','current_or_public');owners={'public',character}
                if owner=='alchemist_or_public': owners={'public','alchemist'}
                elif owner=='public': owners={'public'}
                if row['owner_pool'] not in owners: continue
                if parsed.get('tag') and not set(str(parsed['tag']).split('_or_')) & set(split(row['tags'])): continue
            result.append(row['id'])
        return result
    choices=by('event_choices');events=by('events')
    for name,column in (('reward_entries','reward_type'),('event_choice_effects','effect_type')):
        for row in rows(name):
            effect=row[column];parsed=params(row['params'])
            if effect not in ('item_pool','bag_pool'): continue
            if 'ignore_chapter_gate' in parsed and (name!='reward_entries' or row['reward_table_id']!='reward_boss'): fail(name+'：只有显式Boss赠礼可绕过章节门槛')
            parent=row if name=='reward_entries' else events[choices[row['choice_id']]['event_id']]
            for act in range(int(parent['act_min']),int(parent['act_max'])+1):
                for character in by('characters'):
                    counts['content_pool_checks']+=1
                    if not content_pool(effect,parsed,act,character): fail(f'{name} {row.get("id",row.get("choice_id"))}：{character}第{act}章奖励池为空')
    if check_assets and source:
        project=Path(asset_project) if asset_project else Path(source).parents[3]
        binding_path=project/'PvE/asset_bindings.json'
        bindings=json.loads(binding_path.read_text(encoding='utf-8'))['bindings'] if binding_path.is_file() else {}
        for row in rows('items')+rows('bags'):
            binding=bindings.get(row['id'],{})
            if row.get('icon_ref','')!=binding.get('png') or not row.get('icon_ref','').startswith('res://') or not (project/row.get('icon_ref','')[6:]).is_file(): fail(row['id']+'：原PNG绑定资源不存在')
            if 'vfx_ref' in row and (row['vfx_ref']!=(binding.get('animation') or binding.get('scene')) or not (project/row['vfx_ref'][6:]).is_file()): fail(row['id']+'：原动画场景绑定不存在')
    return {'ok':not errors,'error':errors[0] if errors else '', 'errors':errors,'warnings':warnings,'counts':counts,'route_battle_range':route_range}

if __name__=='__main__':
    from import_content import ROOT, parse_table
    parser=argparse.ArgumentParser();parser.add_argument('--source',type=Path,default=ROOT/'project/PvE/Rules/content/tables');parser.add_argument('--report',type=Path);parser.add_argument('--skip-assets',action='store_true');parser.add_argument('--summary',action='store_true');args=parser.parse_args()
    try:
        tables={p.stem:parse_table(p)[0] for p in sorted(args.source.glob('*.csv'))}
        result=validate(tables,args.source,not args.skip_assets)
    except (ValueError,KeyError,TypeError) as error: result={'ok':False,'error':str(error),'errors':[str(error)]}
    text=json.dumps(result,ensure_ascii=False,indent=2)
    if args.report: args.report.parent.mkdir(parents=True,exist_ok=True);args.report.write_text(text+'\n',encoding='utf-8')
    print(json.dumps({'ok':result['ok'],'errors':len(result.get('errors',[])),'counts':result.get('counts',{})},ensure_ascii=False) if args.summary else text);sys.exit(0 if result['ok'] else 1)
