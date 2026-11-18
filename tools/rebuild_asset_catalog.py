"""Rebuild small scene metadata without loading textures or creating game nodes.

Default is a read-only consistency check. Use --write after changing original
item scenes or ItemData.csv. Preserves the recovered scene resolver's ordering.
Reviewed metadata for previously pruned scenes is pinned separately, because its
socket counts are still consumed by the runtime. --strict-sources reports those
unavailable sources as a failure rather than treating them as verified files.
"""
from pathlib import Path
import argparse, ast, csv, hashlib, json, re

BUNDLE = Path(__file__).resolve().parents[1]
RETAINED_METADATA = BUNDLE/'tools/qa/retained_catalog_metadata.json'


def record_digest(record):
    payload = json.dumps(record, ensure_ascii=False, sort_keys=True, separators=(',', ':'))
    return hashlib.sha256(payload.encode('utf8')).hexdigest()


def preserve_reviewed_metadata(project, rebuilt, existing):
    """Keep only exact, reviewed legacy rows; never excuse a newly missing file.

    A pin is valid only while both the old row and its precise missing-path set
    match. Live scene changes, new removals, changed sockets and CSV additions
    continue to appear as ordinary differences. This does not prove that a
    pruned scene can load and does not change runtime resource resolution.
    """
    pins = json.loads(RETAINED_METADATA.read_text(encoding='utf8'))['items']
    retained = []
    for name, row in rebuilt['items'].items():
        old = existing.get('items', {}).get(name, {})
        if row == old or name not in pins:
            continue
        pin = pins[name]
        if record_digest(old) != pin['record_sha256']:
            continue
        missing = sorted(old[field] for field in ('scene', 'animation')
                         if old.get(field) and not (project/old[field][6:]).is_file())
        if missing != pin['missing_paths']:
            continue
        available = dict(old)
        for field in ('scene', 'animation'):
            if available.get(field) in missing:
                available[field] = ''
                if field == 'scene': available['sockets'] = 0
        if row == available:
            rebuilt['items'][name] = dict(old)
            retained.append(name)
    return sorted(retained)

def build(project):
    rows = csv.DictReader((project/'Sheets/CSV/ItemData.csv').open(encoding='utf-8-sig', newline=''))
    records = {}
    for row in rows:
        name = row.get('name', '').strip()
        if not name: continue
        compact = name.replace(' ', '')
        kind = row.get('type', '').replace(' ', '')
        candidates = [f'Items/{"Gems/" if kind == "Gem" else ""}{compact}.tscn',
                      f'Items/Exclusive/{"Chess/" if kind == "ChessPiece" else ""}{compact}.tscn',
                      f'Items/Exclusive/Unreleased/{compact}.tscn']
        scene = next((p for p in candidates if (project/p).is_file()), '')
        animations = [f'Items/Animations/{compact}Animation.tscn',
                      f'Items/Exclusive/Animations/{compact}Animation.tscn',
                      f'Items/Exclusive/Unreleased/{compact}Animation.tscn']
        animation = next((p for p in animations if (project/p).is_file()), '')
        source = (project/scene).read_text(encoding='utf-8-sig') if scene else ''
        sockets = len(re.findall(r'(?m)^\[node name="GemSocket[^"]*"', source))
        records[name] = {'scene': 'res://'+scene if scene else '',
                         'animation': 'res://'+animation if animation else '', 'sockets': sockets}
    source = (project/'Items/Exclusive/SpeakwithAnimals.gd').read_text(encoding='utf-8-sig')
    pets = ast.literal_eval(re.search(r'const pets = (\[[\s\S]*?\])', source).group(1))
    return {'format': 1, 'items': records, 'appropriation_pets': pets}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=BUNDLE/'project')
    parser.add_argument('--write', action='store_true')
    parser.add_argument('--strict-sources', action='store_true', help='also fail for reviewed, unavailable legacy source scenes')
    args = parser.parse_args()
    target = args.project/'PvE/asset_catalog.json'
    data = build(args.project)
    existing = json.loads(target.read_text(encoding='utf-8-sig')) if target.is_file() else {}
    retained = preserve_reviewed_metadata(args.project, data, existing)
    differences = [name for name in sorted(set(data['items']) | set(existing.get('items', {})))
                   if data['items'].get(name) != existing.get('items', {}).get(name)]
    unreviewed_removals = [name for name in differences if name in data['items']
                          and any(existing.get('items', {}).get(name, {}).get(field)
                                  and not data['items'][name].get(field)
                                  for field in ('scene', 'animation'))]
    print(json.dumps({'items': len(data['items']), 'changed_items': differences,
                      'retained_unverifiable_items': retained,
                      'unreviewed_source_removals': unreviewed_removals,
                      'pets_match': data['appropriation_pets'] == existing.get('appropriation_pets'),
                      'write': args.write}, ensure_ascii=False, indent=2))
    if args.strict_sources and retained:
        raise SystemExit(1)
    if args.write and unreviewed_removals:
        raise SystemExit('Refusing to erase unreviewed missing-source metadata; review source removal and socket semantics first.')
    if args.write:
        target.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf8')
    elif differences or data['appropriation_pets'] != existing.get('appropriation_pets'):
        raise SystemExit(1)

if __name__ == '__main__': main()
