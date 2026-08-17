import re
from pathlib import Path
root = Path('.')
api = root / 'api_client.dart'
text = api.read_text(encoding='utf-8')
consts = [(m.group(1), m.group(3).strip()) for m in re.finditer(r'^\s*static const String\s+(\w+)\s*=\s*(["\'])(.+?)\2;', text, re.MULTILINE)]
methods = [(m.group(1), m.group(3).strip()) for m in re.finditer(r'^\s*static String\s+(\w+)\([^\)]*\)\s*=>\s*(["\'])(.+?)\2;', text, re.MULTILINE)]
files = [p for p in root.rglob('*.dart') if p.name != 'api_client.dart']
usage = {name: 0 for name,_ in consts+methods}
for p in files:
    content = p.read_text(encoding='utf-8')
    for name,_ in consts+methods:
        if re.search(r'\bApiClient\.' + re.escape(name) + r'\b', content):
            usage[name] += 1
unused = [(name, endpoint) for name, endpoint in consts+methods if usage[name] == 0]
print('TOTAL_ENDPOINTS', len(consts)+len(methods))
print('USED', sum(1 for v in usage.values() if v > 0))
print('UNUSED', len(unused))
for name, endpoint in unused:
    print(f'{name}: {endpoint}')
