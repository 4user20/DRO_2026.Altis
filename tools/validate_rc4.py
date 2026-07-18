from pathlib import Path
import re, json, sys
root=Path(__file__).resolve().parents[1]

def strip_comments_strings(s):
    out=[]; i=0; state='code'
    while i<len(s):
        if state=='code':
            if s.startswith('//',i): state='line'; out.extend('  '); i+=2
            elif s.startswith('/*',i): state='block'; out.extend('  '); i+=2
            elif s[i]=='"': state='string'; out.append(' '); i+=1
            else: out.append(s[i]); i+=1
        elif state=='line':
            if s[i]=='\n': state='code'; out.append('\n')
            else: out.append(' ')
            i+=1
        elif state=='block':
            if s.startswith('*/',i): state='code'; out.extend('  '); i+=2
            else: out.append('\n' if s[i]=='\n' else ' '); i+=1
        else:
            if s[i]=='"':
                if i+1<len(s) and s[i+1]=='"': out.extend('  '); i+=2
                else: state='code'; out.append(' '); i+=1
            else: out.append('\n' if s[i]=='\n' else ' '); i+=1
    if state=='line': state='code'
    return ''.join(out),state

text_ext={'.sqf','.hpp','.ext','.sqm'}
files=[p for p in root.rglob('*') if p.is_file() and p.suffix.lower() in text_ext]
errors=[]
for p in files:
    s=p.read_text(errors='replace')
    clean,state=strip_comments_strings(s)
    stack=[]; line=1; pairs={')':'(',']':'[','}':'{'}
    for ch in clean:
        if ch=='\n': line+=1
        elif ch in '([{': stack.append((ch,line))
        elif ch in ')]}':
            if not stack or stack[-1][0]!=pairs[ch]:
                errors.append(f'{p.relative_to(root)}:{line}: mismatch {ch}, stack={stack[-3:]}')
                break
            stack.pop()
    else:
        if stack: errors.append(f'{p.relative_to(root)}: unclosed {stack[-1]}')
        if state!='code': errors.append(f'{p.relative_to(root)}: unclosed {state}')

cfg=(root/'dro2026/CfgFunctions.hpp').read_text()
registered=set(re.findall(r'\bclass\s+(\w+)\s*\{(?:\s*(?:preInit|postInit)\s*=\s*1\s*;)?\s*\};',cfg))
fnfiles={p.stem[3:] for p in (root/'dro2026/functions').rglob('fn_*.sqf')}
calls=set()
for p in root.rglob('*.sqf'):
    calls.update(re.findall(r'DRO2026_fnc_(\w+)',p.read_text(errors='replace')))
func={
 'unregistered_files':sorted(fnfiles-registered),
 'missing_files':sorted(registered-fnfiles),
 'unregistered_calls':sorted(calls-registered-{'log'}),
}
patterns={
 'Bo_Mk82 in dro2026':r'Bo_Mk82',
 'Titan injection in FPV':r'M_Titan_(?:AT|AP)',
 'fp1_base_F':r'fp1_base_F',
 'Pook class creation':r'createVehicle\s*\[\s*"[^"]*pook',
 'legacy infinite directors':r'while\s*\{\s*true\s*\}',
 'bad tokenList':r'_tokenList\s+findIf',
}
findings={}
for label,pat in patterns.items():
    arr=[]
    scope=(root/'dro2026').rglob('*.sqf') if label not in {'legacy infinite directors'} else root.rglob('*.sqf')
    for p in scope:
        for n,line in enumerate(p.read_text(errors='replace').splitlines(),1):
            if re.search(pat,line,re.I): arr.append(f'{p.relative_to(root)}:{n}:{line.strip()}')
    findings[label]=arr

# Detect likely direct local-variable misuse in global event handler strings is out of scope, but check new support funcs presence.
report={
 'text_files':len(files),
 'delimiter_errors':errors,
 'functions':func,
 'registered_count':len(registered),
 'function_file_count':len(fnfiles),
 'findings':findings,
}
print(json.dumps(report,ensure_ascii=False,indent=2))
if errors or any(func.values()): sys.exit(1)
