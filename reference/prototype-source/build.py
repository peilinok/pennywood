from pathlib import Path

project = Path(__file__).resolve().parent
destination = project.parent.parent / 'prototype' / 'Pennywood-prototype.html'
page = (project / 'index.html').read_text()
page = page.replace('<!-- PROTOTYPE_STYLE -->', '<style>\n' + (project / 'style.css').read_text() + '\n' + (project / 'game.css').read_text() + '\n</style>')
sources = ['art.js', 'state.js', 'app.js', 'pages.js', 'family.js', 'game-art.js', 'game.js', 'interactions.js']
script = '\n'.join((project / source).read_text() for source in sources)
page = page.replace('<!-- PROTOTYPE_SCRIPTS -->', '<script>\n' + script + '\n</script>')
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(page)
print(destination)
print('Rebuilt the offline browser reference prototype.')
