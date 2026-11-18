"""Refresh paths in the maintained list of original-script delegates."""
import argparse
from functools import lru_cache
import json
from pathlib import Path
import re

BUNDLE = Path(__file__).resolve().parents[1]
PROJECT = BUNDLE / "project"
INDEX = BUNDLE / "docs/代码维护索引.json"
GAME_ENTRY = "Core/Game.gd"
GAME_SCRIPTS = (
    GAME_ENTRY,
    "Runtime/Compatibility/GameState.gd",
    "Runtime/Compatibility/GameProfileCompatibility.gd",
    "Runtime/Compatibility/GameRunCompatibility.gd",
    "Runtime/Compatibility/GameInteractionCompatibility.gd",
)
TOP_LEVEL = re.compile(r"(?m)^(?:(?:static )?func|@onready var|var|const|signal|enum|class)\s+(\w+)")
DELEGATE = re.compile(r'(?:preload|load)\("res://([^"]+\.gd)"\)\.([\w.]+)\(')

@lru_cache(None)
def functions(path):
    file = (PROJECT / path).resolve()
    if not file.is_relative_to(PROJECT) or not file.is_file():
        return {}
    source = file.read_text(encoding="utf-8-sig")
    declarations = list(TOP_LEVEL.finditer(source))
    result = {}
    for index, decl in enumerate(declarations):
        if not decl[0].startswith(("func ", "static func ")):
            continue
        end = declarations[index + 1].start() if index + 1 < len(declarations) else len(source)
        result[decl[1]] = source[decl.start():end]
    return result

def refresh(index):
    refreshed = []
    removed = []
    relocated = 0
    for item in index:
        source = item["scene_script"]
        method = item["method"]
        game = source == GAME_ENTRY or item.get("entry_point") == GAME_ENTRY
        sources = GAME_SCRIPTS if game else (source,)
        candidates = [(path, functions(path)[method]) for path in sources if method in functions(path)]
        if not candidates:
            removed.append({"source": source, "method": method, "reason": "method missing"})
            continue
        if len(candidates) != 1:
            raise ValueError(f"Ambiguous method location: {source}:{method}")
        path, body = candidates[0]
        delegates = list(dict.fromkeys(DELEGATE.findall(body)))
        preferred = [pair for pair in delegates if pair[0] == item["implementation"] and pair[1].split(".")[-1] == method]
        if not preferred:
            preferred = [pair for pair in delegates if pair[0] == item["implementation"]]
        choices = preferred or delegates
        if len(choices) != 1:
            if not choices:
                removed.append({"source": source, "method": method, "reason": "no explicit delegated implementation"})
                continue
            raise ValueError(f"Ambiguous implementation: {path}:{method}")
        implementation, call = choices[0]
        target = (PROJECT / implementation).resolve()
        if not target.is_relative_to(PROJECT) or not target.is_file():
            raise ValueError(f"Missing implementation: {implementation}")
        leaf = call.split(".")[-1]
        if not re.search(r"(?m)^\s*(?:static )?func\s+"+re.escape(leaf)+r"\s*\(", target.read_text(encoding="utf-8-sig")):
            raise ValueError(f"Missing function: {implementation}:{call}")
        record = dict(item)
        record["scene_script"] = path
        record["implementation"] = implementation
        record["coroutine"] = bool(re.search(r"\bawait\s+(?:preload|load)\(", body))
        if game and path != GAME_ENTRY:
            record["entry_point"] = GAME_ENTRY
        if path != source:
            relocated += 1
        refreshed.append(record)
    return refreshed, removed, relocated

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    current = json.loads(INDEX.read_text(encoding="utf-8-sig"))
    refreshed, removed, relocated = refresh(current)
    changed = current != refreshed
    report = {"ok": not changed or args.write, "before": len(current), "entries": len(refreshed),
              "relocated": relocated, "removed": removed, "changed": changed}
    if args.write and changed:
        INDEX.write_text(json.dumps(refreshed, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    if args.report:
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False))
    return 0 if report["ok"] else 1

if __name__ == "__main__":
    raise SystemExit(main())
