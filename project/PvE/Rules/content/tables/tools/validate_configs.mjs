import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const errors = [];
const warnings = [];

function fail(message) {
  errors.push(message);
}

function warn(message) {
  warnings.push(message);
}

function parseCsv(text, fileName) {
  const records = [];
  let record = [];
  let field = "";
  let quoted = false;

  for (let index = 0; index < text.length; index += 1) {
    const char = text[index];
    if (quoted) {
      if (char === '"') {
        if (text[index + 1] === '"') {
          field += '"';
          index += 1;
        } else {
          quoted = false;
        }
      } else {
        field += char;
      }
      continue;
    }

    if (char === '"') {
      if (field.length !== 0) fail(`${fileName}: quote begins inside an unquoted field`);
      quoted = true;
    } else if (char === ",") {
      record.push(field);
      field = "";
    } else if (char === "\n") {
      record.push(field);
      records.push(record);
      record = [];
      field = "";
    } else if (char !== "\r") {
      field += char;
    }
  }

  if (quoted) fail(`${fileName}: unterminated quoted field`);
  if (field.length > 0 || record.length > 0) {
    record.push(field);
    records.push(record);
  }
  if (records.at(-1)?.length === 1 && records.at(-1)[0] === "") records.pop();
  if (records.length === 0) {
    fail(`${fileName}: empty CSV`);
    return { columns: [], rows: [] };
  }

  const columns = records[0];
  if (new Set(columns).size !== columns.length) fail(`${fileName}: duplicate column name`);
  const rows = records.slice(1).map((values, index) => {
    if (values.length !== columns.length) {
      fail(`${fileName}:${index + 2}: expected ${columns.length} columns, received ${values.length}`);
    }
    return Object.fromEntries(columns.map((column, columnIndex) => [column, values[columnIndex] ?? ""]));
  });
  return { columns, rows };
}

const csvFiles = fs.readdirSync(ROOT).filter((name) => name.endsWith(".csv")).sort();
const tables = new Map(csvFiles.map((name) => {
  const text = fs.readFileSync(path.join(ROOT, name), "utf8");
  if (text.includes("\r")) fail(`${name}: line endings must be LF`);
  if (text.charCodeAt(0) === 0xfeff) fail(`${name}: UTF-8 BOM is not allowed`);
  return [name, parseCsv(text, name)];
}));

function table(name) {
  const result = tables.get(name);
  if (!result) {
    fail(`missing table: ${name}`);
    return { columns: [], rows: [] };
  }
  return result;
}

function rows(name) {
  return table(name).rows;
}

function values(name, column = "id") {
  return new Set(rows(name).map((row) => row[column]).filter(Boolean));
}

function splitList(value) {
  return value ? value.split("|").filter(Boolean) : [];
}

function number(value) {
  return Number(value);
}

function params(value) {
  const result = {};
  for (const token of splitList(value)) {
    const separator = token.indexOf(":");
    if (separator >= 0) result[token.slice(0, separator)] = token.slice(separator + 1);
  }
  return result;
}

const primaryKeys = {
  "act_progression.csv": ["act_id", "checkpoint"],
  "boss_build_items.csv": ["boss_id", "phase", "instance_id"],
  "boss_phases.csv": ["boss_id", "phase"],
  "enemy_build_bags.csv": ["enemy_build_id", "instance_id"],
  "enemy_build_items.csv": ["enemy_build_id", "instance_id"],
  "event_choice_effects.csv": ["choice_id", "sequence"],
  "game_rules.csv": ["key"],
  "localization_en.csv": ["key"],
  "localization_zh_cn.csv": ["key"],
  "recipe_ingredients.csv": ["recipe_id", "slot"],
  "rest_action_effects.csv": ["rest_action_id", "sequence"],
  "reward_entries.csv": ["reward_table_id", "id"],
  "shop_slot_rules.csv": ["shop_rule_id", "slot_index"],
  "starting_build_items.csv": ["loadout_id", "instance_id"],
};

for (const [name, spec] of tables) {
  const keyColumns = primaryKeys[name] ?? [spec.columns[0]];
  const seen = new Set();
  for (const [index, row] of spec.rows.entries()) {
    const key = keyColumns.map((column) => row[column]).join("\u001f");
    if (keyColumns.some((column) => !row[column])) fail(`${name}:${index + 2}: empty primary-key component (${keyColumns.join(", ")})`);
    if (seen.has(key)) fail(`${name}:${index + 2}: duplicate primary key ${key}`);
    seen.add(key);

    for (const column of spec.columns.filter((entry) => entry === "id" || entry.endsWith("_id"))) {
      for (const id of splitList(row[column])) {
        if (!/^[a-z][a-z0-9_]*$/.test(id)) fail(`${name}:${index + 2}: ${column} is not snake_case: ${id}`);
      }
    }
  }
}

function foreignKey(sourceFile, sourceColumn, targetFile, targetColumn = "id", options = {}) {
  const targets = values(targetFile, targetColumn);
  const allowed = new Set(options.allow ?? []);
  for (const [index, row] of rows(sourceFile).entries()) {
    const sourceValues = options.list ? splitList(row[sourceColumn]) : [row[sourceColumn]];
    for (const value of sourceValues) {
      if (!value && options.optional) continue;
      if (allowed.has(value)) continue;
      if (!targets.has(value)) fail(`${sourceFile}:${index + 2}: ${sourceColumn} references missing ${targetFile}.${targetColumn}: ${value}`);
    }
  }
}

foreignKey("items.csv", "rarity", "rarities.csv");
foreignKey("items.csv", "shape_id", "item_shapes.csv");
foreignKey("items.csv", "tags", "tags.csv", "id", { list: true });
foreignKey("item_effects.csv", "item_id", "items.csv");
foreignKey("item_effects.csv", "trigger_id", "trigger_templates.csv");
foreignKey("item_effects.csv", "condition_id", "condition_templates.csv");
foreignKey("item_effects.csv", "spatial_template_id", "spatial_templates.csv");
foreignKey("item_effects.csv", "effect_type", "effect_templates.csv");
foreignKey("characters.csv", "passive_id", "character_passives.csv");
foreignKey("characters.csv", "exclusive_tags", "tags.csv", "id", { list: true });
foreignKey("character_passives.csv", "character_id", "characters.csv");
foreignKey("character_passives.csv", "trigger_id", "trigger_templates.csv");
foreignKey("character_passives.csv", "condition_id", "condition_templates.csv");
foreignKey("character_passives.csv", "effect_type", "effect_templates.csv");
foreignKey("character_archetypes.csv", "character_id", "characters.csv");
foreignKey("character_archetypes.csv", "primary_tags", "tags.csv", "id", { list: true });
foreignKey("character_loadouts.csv", "character_id", "characters.csv");
foreignKey("character_loadouts.csv", "archetype_hint", "character_archetypes.csv");
foreignKey("character_loadouts.csv", "starting_items", "items.csv", "id", { list: true });
foreignKey("character_loadouts.csv", "starting_bag_id", "bags.csv");
foreignKey("starting_build_items.csv", "loadout_id", "character_loadouts.csv");
foreignKey("starting_build_items.csv", "item_id", "items.csv");
foreignKey("bags.csv", "rarity", "rarities.csv");
foreignKey("bags.csv", "shape_id", "bag_shapes.csv");
foreignKey("recipes.csv", "result_item_id", "items.csv");
foreignKey("recipe_ingredients.csv", "recipe_id", "recipes.csv");
foreignKey("recipe_ingredients.csv", "item_id", "items.csv");
foreignKey("shop_slot_rules.csv", "shop_rule_id", "shop_rules.csv");
foreignKey("shop_rarity_curve.csv", "act_id", "acts.csv");
foreignKey("economy_curve.csv", "act_id", "acts.csv");
foreignKey("act_progression.csv", "act_id", "acts.csv");
foreignKey("node_templates.csv", "reward_table_id", "reward_tables.csv");
foreignKey("node_templates.csv", "shop_rule_id", "shop_rules.csv", "id", { allow: ["none"] });
foreignKey("route_templates.csv", "act_id", "acts.csv");
foreignKey("route_templates.csv", "allowed_nodes", "node_templates.csv", "id", { list: true });
foreignKey("route_templates.csv", "required_nodes", "node_templates.csv", "id", { list: true, optional: true });
foreignKey("enemy_builds.csv", "act_id", "acts.csv");
foreignKey("enemy_builds.csv", "archetype_id", "enemy_archetypes.csv");
foreignKey("enemy_builds.csv", "difficulty_min", "difficulty_levels.csv");
foreignKey("enemy_builds.csv", "difficulty_max", "difficulty_levels.csv");
foreignKey("enemy_builds.csv", "affix_id", "encounter_affixes.csv", "id", { optional: true });
foreignKey("enemy_build_bags.csv", "enemy_build_id", "enemy_builds.csv");
foreignKey("enemy_build_bags.csv", "bag_id", "bags.csv");
foreignKey("enemy_build_items.csv", "enemy_build_id", "enemy_builds.csv");
foreignKey("enemy_build_items.csv", "item_id", "items.csv");
foreignKey("encounter_affixes.csv", "trigger_id", "trigger_templates.csv");
foreignKey("encounter_affixes.csv", "effect_type", "effect_templates.csv");
foreignKey("encounter_templates.csv", "act_id", "acts.csv");
foreignKey("encounter_templates.csv", "node_type", "node_templates.csv");
foreignKey("encounter_templates.csv", "enemy_build_pool", "enemy_builds.csv", "id", { list: true });
foreignKey("encounter_templates.csv", "affix_pool", "encounter_affixes.csv", "id", { list: true, optional: true });
foreignKey("encounter_templates.csv", "reward_table_id", "reward_tables.csv");
foreignKey("bosses.csv", "act_id", "acts.csv");
foreignKey("bosses.csv", "reward_table_id", "reward_tables.csv");
foreignKey("boss_phases.csv", "boss_id", "bosses.csv");
foreignKey("boss_build_items.csv", "boss_id", "bosses.csv");
foreignKey("boss_build_items.csv", "item_id", "items.csv");
foreignKey("reward_entries.csv", "reward_table_id", "reward_tables.csv");
foreignKey("reward_entries.csv", "reward_type", "run_effect_templates.csv");
foreignKey("event_choices.csv", "event_id", "events.csv");
foreignKey("event_choice_effects.csv", "choice_id", "event_choices.csv");
foreignKey("event_choice_effects.csv", "effect_type", "run_effect_templates.csv");
foreignKey("rest_action_effects.csv", "rest_action_id", "rest_actions.csv");
foreignKey("rest_action_effects.csv", "effect_type", "run_effect_templates.csv");
foreignKey("achievements.csv", "stat_key", "stat_definitions.csv");

const telemetryIds = values("telemetry_metrics.csv");
for (const [index, row] of rows("stat_definitions.csv").entries()) {
  for (const metric of splitList(row.source_metric)) {
    if (!telemetryIds.has(metric)) fail(`stat_definitions.csv:${index + 2}: missing source metric ${metric}`);
  }
}

const unlockTargets = {
  character: values("characters.csv"),
  loadout: values("character_loadouts.csv"),
  difficulty: values("difficulty_levels.csv"),
};
for (const [index, row] of rows("unlock_rules.csv").entries()) {
  const targets = unlockTargets[row.unlock_type];
  if (!targets) fail(`unlock_rules.csv:${index + 2}: unsupported unlock_type ${row.unlock_type}`);
  else if (!targets.has(row.target_id)) fail(`unlock_rules.csv:${index + 2}: missing target ${row.target_id}`);
  if (row.requirement_type === "boss_kill" && !values("bosses.csv").has(row.requirement_params)) {
    fail(`unlock_rules.csv:${index + 2}: missing boss requirement ${row.requirement_params}`);
  }
  if (row.requirement_type === "run_clear") {
    const difficultyId = params(row.requirement_params).difficulty;
    if (!values("difficulty_levels.csv").has(difficultyId)) fail(`unlock_rules.csv:${index + 2}: missing difficulty requirement ${difficultyId}`);
  }
}

const zhKeys = values("localization_zh_cn.csv", "key");
const enKeys = values("localization_en.csv", "key");
for (const key of zhKeys) if (!enKeys.has(key)) fail(`localization_en.csv: missing key ${key}`);
for (const key of enKeys) if (!zhKeys.has(key)) fail(`localization_zh_cn.csv: missing key ${key}`);
const localizedColumns = new Set(["name_key", "description_key", "text_key", "title_key", "body_key"]);
for (const [name, spec] of tables) {
  for (const column of spec.columns.filter((entry) => localizedColumns.has(entry))) {
    for (const [index, row] of spec.rows.entries()) {
      if (!zhKeys.has(row[column]) || !enKeys.has(row[column])) fail(`${name}:${index + 2}: ${column} missing in one or both locales: ${row[column]}`);
    }
  }
}
for (const locale of ["localization_zh_cn.csv", "localization_en.csv"]) {
  for (const [index, row] of rows(locale).entries()) if (!row.text) fail(`${locale}:${index + 2}: empty localized text`);
}

const exactCounts = {
  "items.csv": 72,
  "bags.csv": 10,
  "recipes.csv": 24,
  "recipe_ingredients.csv": 48,
  "characters.csv": 2,
  "character_archetypes.csv": 6,
  "character_loadouts.csv": 4,
  "difficulty_levels.csv": 8,
  "enemy_builds.csv": 30,
  "bosses.csv": 3,
  "boss_phases.csv": 6,
  "events.csv": 12,
  "reward_tables.csv": 5,
  "reward_entries.csv": 20,
  "tutorial_steps.csv": 16,
  "achievements.csv": 20,
  "telemetry_metrics.csv": 24,
  "stat_definitions.csv": 19,
};
for (const [name, expected] of Object.entries(exactCounts)) {
  if (rows(name).length !== expected) fail(`${name}: expected ${expected} rows, received ${rows(name).length}`);
}

for (const actId of values("acts.csv")) {
  const actEnemies = rows("enemy_builds.csv").filter((row) => row.act_id === actId);
  const normal = actEnemies.filter((row) => row.node_type === "normal").length;
  const elite = actEnemies.filter((row) => row.node_type === "elite").length;
  if (normal !== 8 || elite !== 2) fail(`${actId}: expected 8 normal and 2 elite enemy builds, received ${normal} and ${elite}`);
}

const choiceCounts = new Map();
for (const row of rows("event_choices.csv")) choiceCounts.set(row.event_id, (choiceCounts.get(row.event_id) ?? 0) + 1);
for (const eventId of values("events.csv")) if ((choiceCounts.get(eventId) ?? 0) < 2) fail(`${eventId}: event must have at least two choices`);

function validateEffectCount(parentFile, effectFile, parentKey, effectKey) {
  const counts = new Map();
  for (const row of rows(effectFile)) counts.set(row[effectKey], (counts.get(row[effectKey]) ?? 0) + 1);
  for (const [index, row] of rows(parentFile).entries()) {
    const actual = counts.get(row[parentKey]) ?? 0;
    if (number(row.effect_count) !== actual) fail(`${parentFile}:${index + 2}: effect_count=${row.effect_count}, actual=${actual}`);
  }
}
validateEffectCount("event_choices.csv", "event_choice_effects.csv", "id", "choice_id");
validateEffectCount("rest_actions.csv", "rest_action_effects.csv", "id", "rest_action_id");

const validRotations = new Set([0, 90, 180, 270]);
function validateShapeTable(name) {
  for (const [index, row] of rows(name).entries()) {
    const cells = splitList(row.cells);
    const unique = new Set(cells);
    if (!unique.has("0:0")) fail(`${name}:${index + 2}: shape does not include 0:0`);
    if (unique.size !== cells.length) fail(`${name}:${index + 2}: duplicate shape cell`);
    if (number(row.cell_count) !== cells.length) fail(`${name}:${index + 2}: cell_count does not match cells`);
    const pending = [cells[0]];
    const visited = new Set();
    while (pending.length > 0) {
      const cell = pending.pop();
      if (!cell || visited.has(cell)) continue;
      visited.add(cell);
      const [x, y] = cell.split(":").map(Number);
      for (const neighbor of [`${x + 1}:${y}`, `${x - 1}:${y}`, `${x}:${y + 1}`, `${x}:${y - 1}`]) {
        if (unique.has(neighbor) && !visited.has(neighbor)) pending.push(neighbor);
      }
    }
    if (visited.size !== cells.length) fail(`${name}:${index + 2}: shape is not four-way connected`);
    for (const rotation of splitList(row.allowed_rotations).map(Number)) {
      if (!validRotations.has(rotation)) fail(`${name}:${index + 2}: invalid rotation ${rotation}`);
    }
  }
}
validateShapeTable("item_shapes.csv");
validateShapeTable("bag_shapes.csv");

const cellsByBagShape = new Map(rows("bag_shapes.csv").map((row) => [row.id, new Set(splitList(row.cells))]));
for (const [index, bag] of rows("bags.csv").entries()) {
  const validCells = cellsByBagShape.get(bag.shape_id);
  for (const cell of splitList(bag.special_cells)) {
    if (!validCells?.has(cell)) fail(`bags.csv:${index + 2}: special cell ${cell} is outside ${bag.shape_id}`);
  }
}

const itemShapeByItem = new Map(rows("items.csv").map((row) => [row.id, row.shape_id]));
const bagShapeByBag = new Map(rows("bags.csv").map((row) => [row.id, row.shape_id]));
const allowedByShape = new Map([
  ...rows("item_shapes.csv"),
  ...rows("bag_shapes.csv"),
].map((row) => [row.id, new Set(splitList(row.allowed_rotations).map(Number))]));
function validateLayoutRotations(file, entityColumn, shapeLookup) {
  for (const [index, row] of rows(file).entries()) {
    const shapeId = shapeLookup.get(row[entityColumn]);
    const rotation = number(row.rotation);
    if (!validRotations.has(rotation)) fail(`${file}:${index + 2}: invalid rotation ${row.rotation}`);
    else if (shapeId && !allowedByShape.get(shapeId)?.has(rotation)) fail(`${file}:${index + 2}: rotation ${rotation} is not allowed for ${shapeId}`);
  }
}
validateLayoutRotations("starting_build_items.csv", "item_id", itemShapeByItem);
validateLayoutRotations("enemy_build_items.csv", "item_id", itemShapeByItem);
validateLayoutRotations("boss_build_items.csv", "item_id", itemShapeByItem);
validateLayoutRotations("enemy_build_bags.csv", "bag_id", bagShapeByBag);

for (const [index, row] of rows("shop_rarity_curve.csv").entries()) {
  const total = number(row.common_weight) + number(row.rare_weight) + number(row.legendary_weight);
  if (Math.abs(total - 1) > 1e-9) fail(`shop_rarity_curve.csv:${index + 2}: rarity weights total ${total}`);
}
for (const file of ["shop_pool_weights.csv", "reward_entries.csv", "events.csv"]) {
  for (const [index, row] of rows(file).entries()) if (number(row.weight) <= 0) fail(`${file}:${index + 2}: weight must be positive`);
}

const ingredientsByRecipe = new Map();
for (const row of rows("recipe_ingredients.csv")) {
  const list = ingredientsByRecipe.get(row.recipe_id) ?? [];
  list.push(row.item_id);
  ingredientsByRecipe.set(row.recipe_id, list);
}
const recipeByResult = new Map(rows("recipes.csv").map((row) => [row.result_item_id, row]));
for (const [index, recipe] of rows("recipes.csv").entries()) {
  const ingredients = ingredientsByRecipe.get(recipe.id) ?? [];
  if (ingredients.length !== 2) fail(`recipes.csv:${index + 2}: recipe must have exactly two ingredients`);
  if (ingredients.includes(recipe.result_item_id)) fail(`recipes.csv:${index + 2}: recipe output is also an ingredient`);
}
const depthMemo = new Map();
function recipeDepth(itemId, stack = new Set()) {
  const recipe = recipeByResult.get(itemId);
  if (!recipe) return 0;
  if (stack.has(itemId)) {
    fail(`recipes.csv: crafting cycle includes ${itemId}`);
    return 99;
  }
  if (depthMemo.has(itemId)) return depthMemo.get(itemId);
  const next = new Set(stack);
  next.add(itemId);
  const ingredientDepth = Math.max(...(ingredientsByRecipe.get(recipe.id) ?? []).map((ingredient) => recipeDepth(ingredient, next)), 0);
  const depth = ingredientDepth + 1;
  depthMemo.set(itemId, depth);
  return depth;
}
for (const recipe of rows("recipes.csv")) {
  const depth = recipeDepth(recipe.result_item_id);
  if (depth > 2) fail(`${recipe.id}: crafting depth ${depth} exceeds 2`);
  if (depth !== number(recipe.tier)) fail(`${recipe.id}: tier ${recipe.tier} does not match crafting depth ${depth}`);
}

for (const bossId of values("bosses.csv")) {
  const phases = rows("boss_phases.csv").filter((row) => row.boss_id === bossId).sort((a, b) => number(a.phase) - number(b.phase));
  if (phases.map((row) => number(row.phase)).join("|") !== "1|2") fail(`${bossId}: phases must be exactly 1 and 2`);
  for (let index = 1; index < phases.length; index += 1) {
    if (number(phases[index].health_threshold_pct) >= number(phases[index - 1].health_threshold_pct)) fail(`${bossId}: phase thresholds must strictly decrease`);
  }
}
const bossPhaseKeys = new Set(rows("boss_phases.csv").map((row) => `${row.boss_id}|${row.phase}`));
for (const [index, row] of rows("boss_build_items.csv").entries()) {
  if (!bossPhaseKeys.has(`${row.boss_id}|${row.phase}`)) fail(`boss_build_items.csv:${index + 2}: references missing boss phase`);
}

for (const actId of values("acts.csv")) {
  const steps = rows("route_templates.csv").filter((row) => row.act_id === actId).sort((a, b) => number(a.step) - number(b.step));
  if (steps.map((row) => number(row.step)).join("|") !== "1|2|3|4|5") fail(`${actId}: route steps must be exactly 1 through 5`);
  const finalStep = steps.at(-1);
  if (!finalStep || finalStep.allowed_nodes !== "boss" || finalStep.required_nodes !== "boss") fail(`${actId}: final route step must only be boss`);
}

const rarityById = new Map(rows("rarities.csv").map((row) => [row.id, row]));
for (const [index, item] of rows("items.csv").entries()) {
  const rarity = rarityById.get(item.rarity);
  const price = number(item.base_price);
  if (rarity && (price < number(rarity.price_min) || price > number(rarity.price_max))) fail(`items.csv:${index + 2}: price ${price} outside ${item.rarity} range`);
}
for (const [index, bag] of rows("bags.csv").entries()) {
  if (bag.availability === "starter" && number(bag.base_price) !== 0) fail(`bags.csv:${index + 2}: starter bag price must be 0`);
  if (bag.availability === "shop") {
    const rarity = rarityById.get(bag.rarity);
    const price = number(bag.base_price);
    if (rarity && (price < number(rarity.price_min) || price > number(rarity.price_max))) fail(`bags.csv:${index + 2}: shop bag price ${price} outside ${bag.rarity} range`);
  }
}

const highFrequencyTriggers = new Set(["attack_hit", "target_activated", "damage_taken", "armor_gained", "status_applied", "interval"]);
const effectsPerItem = new Map();
for (const [index, effect] of rows("item_effects.csv").entries()) {
  effectsPerItem.set(effect.item_id, (effectsPerItem.get(effect.item_id) ?? 0) + 1);
  if (highFrequencyTriggers.has(effect.trigger_id) && number(effect.internal_cooldown) < 0.5) {
    fail(`item_effects.csv:${index + 2}: high-frequency trigger ${effect.trigger_id} requires at least 0.5 seconds internal cooldown`);
  }
}
for (const [itemId, count] of effectsPerItem) if (count > 2) fail(`${itemId}: item has ${count} triggers, maximum is 2`);

for (const [index, row] of rows("event_choice_effects.csv").entries()) {
  if (row.effect_type === "specific_item") {
    const itemId = params(row.params).item_id;
    if (!values("items.csv").has(itemId)) fail(`event_choice_effects.csv:${index + 2}: missing specific item ${itemId}`);
  }
}
for (const [index, row] of rows("reward_entries.csv").entries()) {
  if (row.reward_type === "specific_item") {
    const itemId = row.content_id || params(row.params).item_id;
    if (!values("items.csv").has(itemId)) fail(`reward_entries.csv:${index + 2}: missing specific item ${itemId}`);
  }
}

const manifest = rows("config_manifest.csv");
const listedFiles = new Set(manifest.map((row) => row.file));
for (const [index, row] of manifest.entries()) {
  if (row.file === "config_manifest.csv") fail(`config_manifest.csv:${index + 2}: manifest must not list itself`);
  const spec = tables.get(row.file);
  if (!spec) fail(`config_manifest.csv:${index + 2}: missing listed file ${row.file}`);
  else if (number(row.row_count) !== spec.rows.length) fail(`config_manifest.csv:${index + 2}: row_count for ${row.file} is ${row.row_count}, actual ${spec.rows.length}`);
}
for (const name of csvFiles.filter((entry) => entry !== "config_manifest.csv")) {
  if (!listedFiles.has(name)) fail(`config_manifest.csv: does not list ${name}`);
}
if (listedFiles.size !== csvFiles.length - 1) fail(`config_manifest.csv: expected ${csvFiles.length - 1} unique entries, received ${listedFiles.size}`);

if (warnings.length > 0) {
  console.log(`Warnings (${warnings.length}):`);
  for (const message of warnings) console.log(`- ${message}`);
}

if (errors.length > 0) {
  console.error(`Validation failed with ${errors.length} error(s):`);
  for (const message of errors) console.error(`- ${message}`);
  process.exitCode = 1;
} else {
  console.log(`Validation passed: ${csvFiles.length} CSV files, ${manifest.length} manifest entries, 0 errors.`);
  console.log("Validated schema, keys, references, localization, frozen counts, shapes, rotations, recipes, routes, bosses, economy, effects, and manifest counts.");
  console.log("Full placement geometry remains an editor-time Godot PlacementService check.");
}
