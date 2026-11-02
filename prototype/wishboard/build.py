"""Build the offline wish-journal prototype without connecting to production storage."""
from pathlib import Path
import base64
import json
root = Path(__file__).resolve().parents[2]
assets = {name: 'data:image/svg+xml;base64,' + base64.b64encode((root/'assets/svg'/f'{name}.svg').read_bytes()).decode() for name in ('mascot', 'telescope', 'tree-sprout', 'book')}
for name in ('dishes', 'mop', 'toys', 'vegetables', 'study'):
    assets[f'quick-{name}'] = 'data:image/svg+xml;base64,' + base64.b64encode((root/'assets/svg/quick-tasks'/f'{name}.svg').read_bytes()).decode()
for file in (root/'assets/svg/icons').glob('*.svg'):
    assets[f'icon-{file.stem}'] = 'data:image/svg+xml;base64,' + base64.b64encode(file.read_bytes()).decode()
source_dir = Path(__file__).parent
source = (source_dir/'index.template.html').read_text()
output = root/'outputs/pennywood-wishboard.html'
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(source.replace('__STYLES__', (source_dir/'styles.css').read_text())
                  .replace('__SCRIPT__', (source_dir/'app.js').read_text())
                  .replace('__ASSETS__', json.dumps(assets, ensure_ascii=False)))
print(f'Generated: {output.relative_to(root)}')
