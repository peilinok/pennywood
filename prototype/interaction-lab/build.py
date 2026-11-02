"""Build an offline child-interaction prototype using only the Python standard library."""
from pathlib import Path
import base64
import json

root = Path(__file__).resolve().parents[2]
assets = {}
for name in ('mascot', 'book', 'telescope'):
    data = (root / 'assets' / 'svg' / f'{name}.svg').read_bytes()
    assets[name] = 'data:image/svg+xml;base64,' + base64.b64encode(data).decode()
template = (Path(__file__).parent / 'index.template.html').read_text()
output = root / 'outputs' / 'pennywood-interaction-lab.html'
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(template.replace('__ASSETS__', json.dumps(assets, ensure_ascii=False)))
print(f'Generated: {output.relative_to(root)} ({output.stat().st_size} bytes)')
