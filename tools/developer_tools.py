"""Launch isolated original-asset PvE authoring tools or the deterministic batch CLI.

Copies rule modules into a temporary project with no original Game autoload. Source
CSVs, art, audio and user saves are never changed. All locations are bundle-relative.
"""
from pathlib import Path
import argparse
import json
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def stage_project(project: Path, stage: Path) -> Path:
    project = project.resolve()
    destination = stage / 'PvE/Rules'
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(project / 'PvE/Rules', destination, dirs_exist_ok=True, ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
    bindings = project / 'PvE/asset_bindings.json'
    shutil.copy2(bindings, stage / 'PvE/asset_bindings.json')
    definitions = json.loads(bindings.read_text(encoding='utf-8-sig'))['bindings']
    resources = {entry['png'] for entry in definitions.values()}
    resources.add('res://Assets/Fonts/Localized/NotoSansSC-Regular_.otf')
    for reference in resources:
        source = (project / reference[6:]).resolve()
        if not source.is_relative_to(project) or not source.is_file():
            raise ValueError('Source resource missing or outside project: ' + reference)
        target = stage / reference[6:]
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    (stage / 'project.godot').write_text('config_version=5\n\n[application]\nconfig/name="Backpack PvE Developer Tools"\nrun/main_scene="res://PvE/Rules/tools/DeveloperTools.tscn"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="BackpackPvEDeveloperTools47"\n\n[display]\nwindow/size/viewport_width=1440\nwindow/size/viewport_height=900\n\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding='utf8')
    return stage


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=ROOT / 'project')
    parser.add_argument('--engine', type=Path, default=ROOT / 'engine/Godot_v4.7-stable_win64_console.exe')
    parser.add_argument('--stage', type=Path, help='optional isolated tool workspace, must be outside the source project')
    parser.add_argument('--prepare-only', action='store_true', help='import the isolated workspace without opening a window')
    parser.add_argument('--batch', action='store_true')
    parser.add_argument('--player-file', type=Path)
    parser.add_argument('--enemy-file', type=Path)
    parser.add_argument('--loadout', default='armorer_blades')
    parser.add_argument('--enemy-id', default='rust_scout_a')
    parser.add_argument('--difficulty', default='standard')
    parser.add_argument('--seed', type=int, default=1)
    parser.add_argument('--count', type=int, default=20)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    engine = args.engine.resolve()
    source_project = args.project.resolve()
    if not engine.is_file(): raise ValueError('Godot 4.7 engine missing: ' + str(engine))
    stage = args.stage.resolve() if args.stage else Path(tempfile.mkdtemp(prefix='BackpackPvEDeveloperTools_')).resolve()
    if stage == source_project or stage.is_relative_to(source_project): raise ValueError('Tool workspace must be outside the source project')
    if stage.exists() and any(stage.iterdir()) and not (stage / '.pve_developer_workspace').is_file():
        raise ValueError('Existing non-tool directory cannot be used as tool workspace: ' + str(stage))
    stage.mkdir(parents=True, exist_ok=True)
    (stage / '.pve_developer_workspace').write_text('Isolated Backpack PvE developer tools; source project is read-only.\n', encoding='utf8')
    stage_project(source_project, stage)
    imported = subprocess.run([str(engine), '--headless', '--path', str(stage), '--editor', '--import', '--quit'], capture_output=True, text=True)
    diagnostics = imported.stdout + imported.stderr
    if imported.returncode or 'SCRIPT ERROR' in diagnostics or 'Parse Error' in diagnostics:
        sys.stderr.write(imported.stdout + imported.stderr); return imported.returncode or 1
    if args.prepare_only:
        print(json.dumps({'ok': True, 'stage': str(stage), 'autoloads': [], 'source_read_only': True})); return 0
    command = [str(engine), '--path', str(stage)]
    if args.batch:
        command += ['--headless', '--script', 'res://PvE/Rules/tools/BatchCLI.gd', '--', '--loadout', args.loadout, '--enemy-id', args.enemy_id, '--difficulty', args.difficulty, '--seed', str(args.seed), '--count', str(args.count)]
        for option in ['player_file', 'enemy_file', 'output']:
            value = getattr(args, option)
            if value is not None: command += ['--' + option.replace('_', '-'), str(value.resolve())]
    else:
        command += ['--rendering-method', 'gl_compatibility', '--resolution', '1440x900']
    return subprocess.run(command).returncode


if __name__ == '__main__':
    try: sys.exit(main())
    except (ValueError, OSError, KeyError) as error:
        print(str(error), file=sys.stderr); sys.exit(1)
