"""Auditable source comparison. Standard library only; no code obfuscation."""
from pathlib import Path
import argparse,collections,hashlib,json,re
TOKEN=re.compile(r'"""[\s\S]*?"""|\'\'\'[\s\S]*?\'\'\'|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|#[^\n]*|[A-Za-z_][A-Za-z_0-9]*|\d+(?:\.\d+)?|\S')
KEYWORDS=set('extends class_name class func static var const signal enum if elif else for in while break continue return pass match true false null and or not is as await self super setget onready export preload load'.split())
EXCLUDES={'.godot','addons','tests','verification'}
def sources(root):return sorted(p for p in root.rglob('*.gd') if not any(x in p.parts for x in EXCLUDES))
def tokens(path):
    values=[]
    for m in TOKEN.finditer(path.read_text(encoding='utf-8-sig')):
        value=m.group()
        if value.startswith('#'):continue
        if value.startswith(('"',"'")):value='STR'
        elif value[0].isdigit():value='NUM'
        elif re.fullmatch('[A-Za-z_][A-Za-z_0-9]*',value) and value not in KEYWORDS:value='ID'
        values.append(value)
    return values
def grams(values):
    return [hashlib.blake2b(' '.join(values[i:i+25]).encode(),digest_size=8).digest() for i in range(max(0,len(values)-24))]
def measure(root,reference,original):
    rows=[];groups=collections.defaultdict(lambda:{'windows':0,'matched':0,'files':0})
    total={'files':0,'bytes':0,'lines':0,'nonblank_lines':0,'exact_original_files':0,'normalized_25_token_windows':0,'matched_original_windows':0}
    for p in sources(root):
        rel=p.relative_to(root).as_posix();raw=p.read_bytes();text=raw.decode('utf-8-sig');windows=grams(tokens(p));matched=sum(w in reference for w in windows)
        row={'path':rel,'windows':len(windows),'matched':matched,'match_percent':round(100*matched/max(1,len(windows)),3)}
        rows.append(row)
        group=groups[rel.split('/')[0]];group['files']+=1;group['windows']+=len(windows);group['matched']+=matched
        total['files']+=1;total['bytes']+=len(raw);total['lines']+=len(text.splitlines());total['nonblank_lines']+=sum(bool(x.strip()) for x in text.splitlines())
        total['normalized_25_token_windows']+=len(windows);total['matched_original_windows']+=matched
        total['exact_original_files']+=bool((original/rel).is_file() and raw==(original/rel).read_bytes())
    total['original_window_match_percent']=round(100*total['matched_original_windows']/max(1,total['normalized_25_token_windows']),3)
    for group in groups.values():group['match_percent']=round(100*group['matched']/max(1,group['windows']),3)
    return total,rows,dict(groups)
def main():
    bundle=Path(__file__).resolve().parents[1]
    parser=argparse.ArgumentParser(description='25-token structural comparison, including compatibility facades and domain services. Not an external plagiarism score.')
    parser.add_argument('--original',type=Path,default=bundle.parent/'BackpackBattles_Godot461_Local/project')
    parser.add_argument('--baseline',type=Path)
    parser.add_argument('--current',type=Path,default=bundle/'project')
    parser.add_argument('--output',type=Path,default=bundle/'verification/source-structure-latest.json')
    parser.add_argument('--target',type=float,default=30.0,help='Overall match target in percent; default 30 for the current maintainable revision.')
    args=parser.parse_args()
    for root in [args.original,args.current]+([args.baseline] if args.baseline else []):
        if not root.is_dir():parser.error('Missing project: '+str(root))
    original=args.original.resolve();reference=set()
    for p in sources(original):reference.update(grams(tokens(p)))
    after,rows,groups=measure(args.current.resolve(),reference,original)
    result={'method':'Same 25-token window method as 2026-10-19; identifiers, literals and numbers normalized; comments and formatting ignored. Facades and implementations both included. No padded code or test code in the denominator.','scope':'Production GDScript; not a percentage of independent authorship or a promise about other comparison tools.','excludes':sorted(EXCLUDES),'original':str(original),'current':str(args.current.resolve()),'after':after,'groups':groups,'files':rows,'target_percent':args.target,'target_met':after['original_window_match_percent']<args.target,'modules_at_or_below_30':[r for r in rows if r['path'].startswith('Runtime/') and r['windows']>=200 and r['match_percent']<=30]}
    if args.baseline:result['before']=measure(args.baseline.resolve(),reference,original)[0]
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8')
    print(json.dumps({k:result[k] for k in ['after','target_met']},ensure_ascii=False,indent=2))
if __name__=='__main__':main()
