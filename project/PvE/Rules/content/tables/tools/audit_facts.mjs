import fs from 'node:fs';
// Geometry is rebuilt from stable item IDs, not fixed slots. No global/random placement.
export function normalizeFacts(tables, loc) {
  const get = (name) => tables[name + '.csv'].rows;
  if (!get('game_rules').some(row => row.key === 'max_noncombat_nodes_per_act')) get('game_rules').push({key:'max_noncombat_nodes_per_act',value:1,value_type:'int',scope:'route',description:'每章最多1个商人、事件或休息节点；保证三章12至15场战斗'});
  const by = (name) => new Map(get(name).map(row => [row.id, row]));
  const itemBy = by('items'), bagBy = by('bags');
  // Both actors begin with full stamina; capped start recovery would always do nothing.
  bagBy.get('bag_gear_sling').special_effect='cooldown_pct:-0.05';
  loc.get('bag.bag_gear_sling.desc').zh_cn='齿轮吊带提供固定有效格；与星位或其四向邻格关联的同包物品，冷却时间缩短5%。';
  loc.get('bag.bag_gear_sling.desc').en='Gear Sling Bag provides fixed valid cells. Items in this bag linked to its star cell or orthogonal neighbors have 5% shorter cooldowns.';
  const shapes = new Map([...get('item_shapes'), ...get('bag_shapes')].map(row => [row.id, row]));
  const split = value => String(value || '').split('|').filter(Boolean);
  const cells = (shape, rotation) => {
    let result = split(shapes.get(shape).cells).map(cell => cell.split(':').map(Number));
    for (let i=0; i<rotation/90; i++) result = result.map(([x,y]) => [-y,x]);
    const minX=Math.min(...result.map(c=>c[0])), minY=Math.min(...result.map(c=>c[1]));
    return result.map(([x,y])=>[x-minX,y-minY]);
  };
  const occupied = (bag) => cells(bagBy.get(bag.bag_id).shape_id, bag.rotation).map(([x,y])=>`${x+bag.origin_x}:${y+bag.origin_y}`);
  function pack(items,bags) {
    const valid=new Set(bags.flatMap(occupied)), used=new Set(), placed=new Map();
    const ordered=items.map((row,index)=>({row,index,count:split(shapes.get(itemBy.get(row.item_id).shape_id).cells).length}))
      .sort((a,b)=>b.count-a.count || a.index-b.index);
    const visit = depth => {
      if(depth===ordered.length) return true;
      const row=ordered[depth].row, shape=itemBy.get(row.item_id).shape_id;
      const orientations=new Set();
      for(const rotation of split(shapes.get(shape).allowed_rotations).map(Number)) {
        const offsets=cells(shape,rotation), signature=offsets.map(c=>c.join(':')).sort().join('|');
        if(orientations.has(signature)) continue; orientations.add(signature);
        for(let y=0;y<7;y++) for(let x=0;x<9;x++) {
          const absolute=offsets.map(([dx,dy])=>`${x+dx}:${y+dy}`);
          if(absolute.some(cell=>!valid.has(cell)||used.has(cell))) continue;
          absolute.forEach(cell=>used.add(cell)); placed.set(row.instance_id,{origin_x:x,origin_y:y,rotation});
          if(visit(depth+1)) return true;
          absolute.forEach(cell=>used.delete(cell)); placed.delete(row.instance_id);
        }
      }
      return false;
    };
    if(!visit(0)) return false;
    items.forEach(row=>Object.assign(row,placed.get(row.instance_id)));
    return true;
  }
  for(const loadout of get('character_loadouts')) {
    const items=get('starting_build_items').filter(row=>row.loadout_id===loadout.id);
    if(!pack(items,[{bag_id:loadout.starting_bag_id,origin_x:0,origin_y:0,rotation:0}])) throw Error(`Unable to pack starter ${loadout.id}`);
  }
  for(const enemy of get('enemy_builds')) {
    const items=get('enemy_build_items').filter(row=>row.enemy_build_id===enemy.id);
    const bags=get('enemy_build_bags').filter(row=>row.enemy_build_id===enemy.id);
    for(const row of items) delete row.numeric_tier;
    if(pack(items,bags)) continue;
    const covered=new Set(bags.flatMap(occupied));
    let placed=false;
    for(let y=0;y<5 && !placed;y++) for(let x=0;x<7 && !placed;x++) {
      const extra={enemy_build_id:enemy.id,instance_id:enemy.id+'_bag_3',bag_id:'bag_canvas_frame',origin_x:x,origin_y:y,rotation:0};
      if(occupied(extra).some(cell=>covered.has(cell))) continue;
      if(pack(items,[...bags,extra])) {get('enemy_build_bags').push(extra);placed=true;}
    }
    if(!placed) throw Error(`Unable to pack enemy ${enemy.id}`);
  }
  tables['enemy_build_items.csv'].columns=tables['enemy_build_items.csv'].columns.filter(column=>column!=='numeric_tier');
  const bossBags=[0,3].flatMap(y=>[0,3,6].map(x=>({bag_id:'bag_canvas_frame',origin_x:x,origin_y:y,rotation:0})));
  tables['bosses.csv'].columns.push('bag_layout');
  for(const boss of get('bosses')) {
    boss.bag_layout=bossBags.map(bag=>`${bag.bag_id}:${bag.origin_x}:${bag.origin_y}:${bag.rotation}`).join('|');
    if(!pack(get('boss_build_items').filter(row=>row.boss_id===boss.id),bossBags)) throw Error(`Unable to pack boss ${boss.id}`);
  }
  for(const row of get('route_templates')) {
    if(row.step===1) {row.candidate_count_min=2;row.candidate_count_max=2;row.allowed_nodes='normal_combat|danger_combat';row.required_nodes='normal_combat';}
    if(row.step===3 && row.act_id==='act_1') row.required_nodes='';
    if(row.step===4) {row.allowed_nodes='normal_combat|elite_combat|rest|merchant|event';row.required_nodes='elite_combat';}
  }
  for(const row of get('unlock_rules')) if(row.unlock_type==='loadout') {row.requirement_type='default';row.requirement_params='';}
  get('game_rules').find(row=>row.key==='content_version').value='0.1.3';
  get('game_rules').find(row=>row.key==='content_version').description='规划冲突与真实布局修正基线';
  const upgrade='mode:defined_recipe|selector:player_choice|tier_max:2|fallback_discount:0.20|duration_shops:1';
  get('run_effect_templates').find(row=>row.id==='upgrade_item').param_format='mode:string|selector:string|tier_max:int|fallback_discount:float|duration_shops:int';
  for(const row of get('reward_entries')) if(row.reward_type==='upgrade_item') row.params=upgrade;
  // Explicit Boss gifts may arrive early; generic elite loot obeys chapter gates.
  for(const row of get('reward_entries')) {
    if(row.reward_table_id==='reward_boss' && ['item_pool','bag_pool'].includes(row.reward_type)) row.params+='|ignore_chapter_gate:true';
    if(row.id==='elite_legendary_item') row.act_min=3;
  }
  for(const row of get('event_choice_effects')) if(row.effect_type==='upgrade_item') row.params=upgrade;
  tables['rest_actions.csv'].rows=get('rest_actions').filter(row=>row.id!=='rest_maintenance');
  const fieldCraft=get('rest_actions').find(row=>row.id==='rest_field_craft');fieldCraft.requirements='always';fieldCraft.effect_count=1;
  tables['rest_action_effects.csv'].rows=get('rest_action_effects').filter(row=>row.rest_action_id!=='rest_maintenance');
  Object.assign(get('rest_action_effects').find(row=>row.rest_action_id==='rest_field_craft'),{effect_type:'upgrade_item',params:upgrade});
  tables['rest_actions.csv'].description='休息节点二选一：恢复生命或复用二阶配方升级，无法升级时提供商店折扣券。';
  loc.delete('rest.rest_maintenance.name');loc.delete('rest.rest_maintenance.desc');
  loc.get('rest.rest_field_craft.name').zh_cn='配方升级 / 折扣券';loc.get('rest.rest_field_craft.name').en='Recipe Upgrade / Coupon';
  loc.get('rest.rest_field_craft.desc').zh_cn='免费把已有一阶配方成品转化为引用它的二阶配方结果；没有符合条件的物品时，获得下次商店20%折扣券。';
  loc.get('rest.rest_field_craft.desc').en='Upgrade an owned tier-1 recipe result into a defined tier-2 result. If none is eligible, gain a 20% discount for the next shop.';
  loc.get('run_effect.upgrade_item.name').zh_cn='配方升级或折扣券';loc.get('run_effect.upgrade_item.name').en='Recipe Upgrade or Discount Coupon';
  for(const suffix of ['event_field_smith_forge','event_echo_forge_temper']) {
    const entry=loc.get(`event_choice.${suffix}.text`);
    if(entry) {entry.zh_cn += '（按二阶配方，无适用对象时给20%商店折扣券）';entry.en += ' (defined tier-2 recipe; otherwise a 20% shop coupon)';}
  }
  const english={weapon:'Items that actively deal physical damage.',armor:'Items that generate or depend on armor.',stamina:'Items that generate, save, or consume stamina.',tempo:'Items that change cooldowns, cooldown advancement, or trigger frequency.',heavy:'Items with high damage, large shapes, or long cooldowns.',combo:'Items built around repeated hits and consecutive activations.',counter:'Items triggered by damage taken, armor gained, or blocking.',poison:'Items that apply or use poison stacks.',burn:'Items that apply or use burn stacks.',healing:'Items that heal, regenerate, or convert healing.',cleanse:'Items that remove negative statuses.',potion:'Consumable and status containers used by the alchemist.',herb:'Materials used for healing, poison, and crafting.',spatial:'Items that depend on adjacency, direction, rows, columns, or star cells.',economy:'Items that affect gold, shops, refreshes, or selling.',utility:'Items that provide general build tools.'};
  for(const [id,text] of Object.entries(english)) loc.get(`tag.${id}.desc`).en=text;
  // Intel vocabulary is descriptive, never a new item mechanic or hidden multiplier.
  loc.set('content_changed',{key:'content_changed',zh_cn:'内容已更新，路线选项已重新生成。',en:'Content updated. Route choices have been refreshed.'});
  loc.set('route_no_longer_available',{key:'route_no_longer_available',zh_cn:'此路线已不符合当前章节规则，选项已重新生成。',en:'This route no longer meets the chapter rules. Choices have been refreshed.'});
  const intel={slow:['减速','Slow','用减速打断高频触发。','Slow disrupts frequent activations.'],vulnerable:['易伤','Vulnerable','用易伤放大生命伤害。','Vulnerable amplifies health damage.'],true_damage:['真实伤害','True Damage','穿过护甲直接造成伤害。','Damage that bypasses armor.'],burst:['爆发','Burst','集中伤害压制恢复与累积效果。','Concentrated damage counters recovery and scaling.'],focused_build:['专注流派','Focused Build','用一致的流派协同对抗分散构筑。','A focused synergy counters a scattered build.']};
  for(const [id,[zh,en,zhDesc,enDesc]] of Object.entries(intel)) {
    loc.set(`tag.${id}.name`,{key:`tag.${id}.name`,zh_cn:zh,en});
    loc.set(`tag.${id}.desc`,{key:`tag.${id}.desc`,zh_cn:zhDesc,en:enDesc});
    get('tags').push({id,name_key:`tag.${id}.name`,description_key:`tag.${id}.desc`,category:'intel'});
  }
  const native = JSON.parse(fs.readFileSync(new URL('../../../../asset_bindings.json', import.meta.url), 'utf8')).bindings;
  for(const row of get('items')) {
    if(!native[row.id]) throw new Error(`Missing explicit original asset binding: ${row.id}`);
    row.icon_ref=native[row.id].png;
    row.vfx_ref=native[row.id].animation || native[row.id].scene;
  }
  if(!tables['bags.csv'].columns.includes('icon_ref')) tables['bags.csv'].columns.push('icon_ref');
  for(const row of get('bags')) {
    if(!native[row.id]) throw new Error(`Missing explicit original bag binding: ${row.id}`);
    row.icon_ref=native[row.id].png;
  }
}

