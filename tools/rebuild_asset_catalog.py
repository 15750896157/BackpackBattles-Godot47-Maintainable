"""Rebuild small scene metadata without loading textures or creating game nodes.

Default is a read-only consistency check. Use --write after changing original
item scenes or ItemData.csv. Preserves the recovered scene resolver's ordering.
"""
from pathlib import Path
import argparse, ast, csv, json, re

BUNDLE = Path(__file__).resolve().parents[1]

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
    args = parser.parse_args()
    target = args.project/'PvE/asset_catalog.json'
    data = build(args.project)
    existing = json.loads(target.read_text(encoding='utf-8-sig')) if target.is_file() else {}
    differences = [name for name in sorted(set(data['items']) | set(existing.get('items', {})))
                   if data['items'].get(name) != existing.get('items', {}).get(name)]
    print(json.dumps({'items': len(data['items']), 'changed_items': differences,
                      'pets_match': data['appropriation_pets'] == existing.get('appropriation_pets'),
                      'write': args.write}, ensure_ascii=False, indent=2))
    if args.write:
        target.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf8')
    elif differences or data['appropriation_pets'] != existing.get('appropriation_pets'):
        raise SystemExit(1)

if __name__ == '__main__': main()
