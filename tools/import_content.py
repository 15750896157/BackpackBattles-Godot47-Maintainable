"""Compile CSV facts for the original-asset PvE project. Never create art or audio.

Only Python's standard library is required. Paths default to this bundle's project,
so this tool works after moving the whole bundle to another directory.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "project"
RULE_CONTENT = Path("PvE/Rules/content")
STRING_COLUMNS = {
    "id", "key", "text", "schema_version", "content_version", "file",
    "primary_key_hint", "description", "value_type", "params", "condition_params",
    "effect_params", "special_effect_params", "requirements", "cells", "special_cells",
    "relative_cells", "allowed_rotations", "bag_layout",
}
NUMBER = re.compile(r"^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?$")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def typed(value: str, column: str = ""):
    if column in STRING_COLUMNS or column.endswith(("_id", "_key", "_ref")) or "|" in value:
        return value
    if value in ("true", "false"):
        return value == "true"
    if NUMBER.fullmatch(value):
        return float(value) if any(character in value for character in ".eE") else int(value)
    return value


def parse_table(path: Path):
    with path.open(encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream, strict=True)
        columns = reader.fieldnames or []
        if not columns or "" in columns or len(columns) != len(set(columns)):
            raise ValueError(f"{path.name}: empty or duplicate header")
        rows = []
        for line, row in enumerate(reader, 2):
            if None in row or any(value is None for value in row.values()):
                raise ValueError(f"{path.name}:{line}: column count mismatch")
            result = {key: typed(value, key) for key, value in row.items()}
            if "value_type" in row and "value" in row:
                if row["value_type"] == "bool" and row["value"] not in ("true", "false"):
                    raise ValueError(f"{path.name}:{line}: bool must be true or false")
                converter = {"int": int, "float": float, "bool": lambda value: value == "true", "string": str}.get(row["value_type"])
                if converter is None:
                    raise ValueError(f"{path.name}:{line}: unknown value_type {row['value_type']}")
                result["value"] = converter(row["value"])
            if any(isinstance(value, float) and not math.isfinite(value) for value in result.values()):
                raise ValueError(f"{path.name}:{line}: non-finite number")
            rows.append(result)
    return rows, columns


def source_resource(project: Path, reference: str) -> Path:
    if not reference.startswith("res://"):
        raise ValueError("原素材必须使用 res:// 工程资源路径：" + reference)
    resolved = (project / reference[6:]).resolve()
    if not resolved.is_relative_to(project.resolve()) or not resolved.is_file():
        raise ValueError("资源路径不存在或越出工程：" + reference)
    return resolved


def build(project: Path, output: Path | None = None, validate_only: bool = False) -> dict:
    project = project.resolve()
    content = project / RULE_CONTENT
    source = content / "tables"
    output = output.resolve() if output else content / "compiled"
    schema_path = content / "schema.json"
    schema = json.loads(schema_path.read_text(encoding="utf-8-sig"))
    tables, columns, files = {}, {}, {}
    for path in sorted(source.glob("*.csv")):
        tables[path.stem], headers = parse_table(path)
        columns[path.stem] = {column: sorted({type(row[column]).__name__ for row in tables[path.stem]}) for column in headers}
        files[path.name] = digest(path)
    if set(tables) != set(schema["tables"]):
        raise ValueError("CSV集合与schema不一致")
    keys = {Path(row["file"]).stem: str(row["primary_key_hint"]).split("|") for row in tables["config_manifest"]}
    keys["config_manifest"] = ["file"]
    for name, records in tables.items():
        expected = schema["tables"][name]
        if set(expected) != set(columns[name]):
            raise ValueError(name + "：字段集合与schema不一致")
        if name not in keys or any(key not in expected for key in keys[name]):
            raise ValueError(name + "：无效清单主键")
        seen = set()
        for row in records:
            key = tuple(str(row[column]) for column in keys[name])
            if "" in key or key in seen:
                raise ValueError(name + "：重复或空主键 " + repr(key))
            seen.add(key)
            for column, value in row.items():
                if type(value).__name__ not in expected[column]:
                    raise ValueError(name + "." + column + "：字段类型不符")
    binding_path = project / "PvE/asset_bindings.json"
    bindings = json.loads(binding_path.read_text(encoding="utf-8-sig"))["bindings"]
    definitions = tables["items"] + tables["bags"]
    if set(bindings) != {row["id"] for row in definitions}:
        raise ValueError("每个物品与背包必须且只能有一个明确的原素材绑定")
    assets = {}
    for row in definitions:
        binding = bindings[row["id"]]
        if row["icon_ref"] != binding["png"] or source_resource(project, row["icon_ref"]).suffix.lower() != ".png":
            raise ValueError(row["id"] + "：必须引用绑定的原PNG，不能生成SVG替代")
        if "vfx_ref" in row and row["vfx_ref"] != (binding.get("animation") or binding["scene"]):
            raise ValueError(row["id"] + "：动画引用必须来自原场景")
        for reference in {binding["png"], binding["scene"], binding.get("animation")} - {"", None}:
            assets[reference] = digest(source_resource(project, reference))
        for field in ("scene", "png"):
            if digest(source_resource(project, binding[field])) != binding[field + "_sha256"]:
                raise ValueError(row["id"] + "：原素材字节已改变 " + field)
    catalog = json.loads((content / "vfx_catalog.json").read_text(encoding="utf-8-sig"))
    if catalog.get("format") != "native-source-vfx" or catalog.get("generated_visuals") is not False:
        raise ValueError("VFX目录必须是原场景引用元数据")
    from validate_content import validate
    validation = validate(tables, source, check_assets=False)
    if not validation["ok"]:
        raise ValueError("配置审计失败：\n" + "\n".join(validation["errors"]))
    version = next(row["value"] for row in tables["game_rules"] if row["key"] == "content_version")
    if version != schema["content_version"] or any(row["schema_version"] != version for row in tables["config_manifest"]):
        raise ValueError("content_version/schema_version不一致")
    canonical = json.dumps(tables, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False).encode("utf-8")
    content_digest = hashlib.sha256(canonical).hexdigest()
    cache = {"format": "backpack-pve-content", "schema_version": 1, "content_version": version,
        "content_sha256": content_digest, "tables": tables, "primary_keys": keys, "columns": columns, "validation": validation}
    manifest = {"content_version": version, "content_sha256": content_digest, "files": files, "assets": assets,
        "schema_sha256": digest(schema_path), "bindings_sha256": digest(binding_path), "validation": validation,
        "table_counts": {name: len(rows) for name, rows in tables.items()}, "content_tables": len(tables) - 1,
        "locales": ["zh_CN", "en"], "source_format": "CSV only; source files are read-only; encrypted exports and import caches are excluded",
        "visual_status": "Uses byte-identical original project PNG, scene, font, sound and animation resources; this tool creates no visual or audio assets.",
        "generated_assets": False, "definitions": "Existing read-only Godot definition classes consume this typed cache via ContentDB."}
    if not validate_only:
        output.mkdir(parents=True, exist_ok=True)
        (output / "content.json").write_text(json.dumps(cache, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n", encoding="utf-8")
        (output / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    return {"ok": True, "content_version": version, "content_sha256": content_digest, "tables": len(tables),
        "rows": sum(map(len, tables.values())), "bindings": len(bindings), "counts": validation["counts"],
        "validate_only": validate_only, "generated_assets": False}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=PROJECT, help="bundle project directory")
    parser.add_argument("--output", type=Path, help="cache output directory; default is project/PvE/Rules/content/compiled")
    parser.add_argument("--validate-only", action="store_true", help="validate without writing any file")
    args = parser.parse_args()
    try:
        print(json.dumps(build(args.project, args.output, args.validate_only), ensure_ascii=False))
    except (ValueError, KeyError, TypeError, OSError, csv.Error) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
