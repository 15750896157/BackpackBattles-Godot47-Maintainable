"""Run the shipped pure-rule tests in an isolated Godot project without Game autoloads."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import sys

from developer_tools import stage_project

ROOT = Path(__file__).resolve().parents[1]
TESTS = Path(__file__).resolve().parent / 'qa/test_sources'
NAMES = ['combat_tests', 'inventory_economy_tests', 'flow_contract_tests', 'content_tests',
         'quality_rule_tests', 'rule_text_tests', 'tools_ui_tests', 'route_contract_tests', 'content_migration_tests']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=ROOT / 'project')
    parser.add_argument('--engine', type=Path, default=ROOT / 'engine/Godot_v4.7-stable_win64_console.exe')
    parser.add_argument('--output', type=Path, default=ROOT / 'verification/rule_test_rerun')
    parser.add_argument('--campaign', action='store_true', help='also run the four deterministic complete-campaign player simulations')
    args = parser.parse_args()
    project, engine, output = args.project.resolve(), args.engine.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix='BackpackPvERuleTests_')).resolve()
    (stage / '.pve_developer_workspace').write_text('Isolated pure-rule test workspace. No original Game autoloads.\n', encoding='utf-8')
    stage_project(project, stage)
    shutil.copytree(TESTS, stage / 'tests', dirs_exist_ok=True)
    fixture_dir = stage / 'migration_fixtures'
    shutil.copytree(TESTS.parent / 'migration_fixtures', fixture_dir)
    imported = subprocess.run([str(engine), '--headless', '--path', str(stage), '--editor', '--import', '--quit'], capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=180)
    (output / 'import.stdout').write_text(imported.stdout, encoding='utf-8')
    (output / 'import.stderr').write_text(imported.stderr, encoding='utf-8')
    if imported.returncode or 'SCRIPT ERROR' in imported.stdout + imported.stderr or 'Parse Error' in imported.stdout + imported.stderr:
        print('Isolated test import failed. See ' + str(output)); return 1
    env = os.environ.copy()
    env['PVE_CONTENT_QA_DIR'] = str(output / 'resource_roundtrips')
    env['PVE_CONTENT_QA_REPORT'] = str(output / 'content_tests.json')
    env['PVE_MIGRATION_FIXTURE_DIR'] = str(fixture_dir)
    results = []
    for name in NAMES + (['campaign_simulation'] if args.campaign else []):
        completed = subprocess.run([str(engine), '--headless', '--path', str(stage), '--script', 'res://tests/' + name + '.gd'], capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=180, env=env)
        (output / (name + '.stdout')).write_text(completed.stdout, encoding='utf-8')
        (output / (name + '.stderr')).write_text(completed.stderr, encoding='utf-8')
        details = {}
        for line in completed.stdout.splitlines():
            brace = line.find('{')
            if brace >= 0:
                try: details = json.loads(line[brace:])
                except json.JSONDecodeError: pass
        result = {'name': name, 'exit_code': completed.returncode, 'stderr_bytes': len(completed.stderr.encode()), 'checks': details.get('checks', 0), 'failures': details.get('failures', []), 'source_sha256': hashlib.sha256((stage / 'tests' / (name + '.gd')).read_bytes()).hexdigest()}
        results.append(result)
        (output / (name + '.json')).write_text(json.dumps(details, ensure_ascii=False, indent=2), encoding='utf-8')
        print(json.dumps(result, ensure_ascii=False), flush=True)
        if completed.returncode or completed.stderr: break
    cache = json.loads((project / 'PvE/Rules/content/compiled/content.json').read_text(encoding='utf-8'))
    summary = {'ok': len(results) == len(NAMES) + int(args.campaign) and all(row['exit_code'] == 0 and row['stderr_bytes'] == 0 and not row['failures'] for row in results), 'content_version': cache['content_version'], 'content_sha256': cache['content_sha256'], 'checks': sum(row['checks'] for row in results), 'autoloads': [], 'source_project_read_only': True, 'stage': str(stage), 'results': results}
    (output / 'summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
    return 0 if summary['ok'] else 1


if __name__ == '__main__':
    try: sys.exit(main())
    except (ValueError, OSError, subprocess.TimeoutExpired) as error:
        print(str(error), file=sys.stderr); sys.exit(1)
