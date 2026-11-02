# Scene Assets and Reuse

This directory contains layered prototype SVGs, task icons, and the app icon reused by Flutter/Flame. Unreviewed source images and local screenshots are excluded. Read [scene guidance](../docs/04-art-and-scene.md) and [coordinates](scene-layout.json).

| Asset | Purpose |
|---|---|
| [town-world-reference.svg](svg/town-world-reference.svg) | Complete static reference: buildings, trees, character, decorations |
| [town-reference.svg](svg/town-reference.svg) | Earlier complete illustration showing original SVG composition |
| [ground.svg](svg/ground.svg) | 860 x 530 background, lawn, paths, flower beds, signs; buildings/trees/character/mailbox/walk hints removed |
| [house-savings.svg](svg/house-savings.svg) | Orange savings cottage; `savings` |
| [house-wish.svg](svg/house-wish.svg) | Purple wish workshop; `wish` |
| [house-tasks.svg](svg/house-tasks.svg) | Green task shop; `tasks` |
| [mascot.svg](svg/mascot.svg) | Complete static squirrel, original 140 x 150 drawing coordinates |
| [player-reference.svg](svg/player-reference.svg) | Scene character scale; production handles walking, direction, and scarf variants |
| `outdoor-tree-left.svg`, `outdoor-tree-middle.svg`, `outdoor-tree-right.svg` | Separate sortable occlusion objects |
| [mailbox.svg](svg/mailbox.svg) | Foreground clickable mailbox; `journal` |
| [tree-annual.svg](svg/tree-annual.svg), [tree-sprout.svg](svg/tree-sprout.svg) | Growth/sapling shapes; scale/stages in layout JSON |
| [book.svg](svg/book.svg), [telescope.svg](svg/telescope.svg) | Task/wish illustrations and decoration |
| `room-tasks.svg`, `room-savings.svg`, `room-wish.svg`, `room-growth.svg` | Four interiors; business text/inputs/buttons are Flutter widgets |
| [icons](svg/icons/) | 25 line icons, 24 x 24 coordinates, default `#667357` |
| [Quick task icons](svg/quick-tasks/) | Five project-drawn 64 x 64 SVGs: dishes, mop, toys, vegetables, learning; used by native quick submission |

All SVGs declare `xmlns` and `viewBox`, without external images, scripts, downloaded fonts, or styles. Chinese building signs intentionally remain product-facing text using system fonts. Production can overlay Flutter text to retain readability.

## Coordinates and anchors

XY values are already projected onto an 860 x 530 drawing plane, not tile indexes. Do not project them again. Explicitly transform hit coordinates with camera, scene scale, and safe areas.

Building files remove the original outer translation but retain internal paths. JSON `sourceTranslation`, entrances, obstacles, and depth reconstruct placement. For a viewBox with a negative origin: rectangle top-left = sourceTranslation + viewBox origin; dimensions = viewBox dimensions. Placing top-left at sourceTranslation alone causes an offset.

Trees/mailbox retain world-coordinate viewBox bounds. Place the rectangle at the viewBox origin at original scale. Tree foot depth uses `treeTrunkObstacles.y`. Anchor the player at its feet and account for negative reference bounds; a second child's scarf is a separate layer.

The sky in `ground.svg` is transparent; Flutter/Flame supplies its soft background. Render ground, houses, trees, character, and interactive objects separately, sorted by foot depth for actual walking and occlusion.

## Rendering boundary

Pre-rasterize suitable atlases or use a compatible load-time SVG parser. Never parse SVG per frame. Verify filter/font support in the chosen renderer: browser output is not Flame validation.

The character uses static art with lightweight motion, not skeletal animation or a complete frame set. The squirrel also generates the app icon. Record actual asset provenance; unreviewed original references are not release assets.

Layered assets correspond to `reference/prototype-source/art.js` and `game-art.js`. Keep extracted SVGs, layout, and relevant previews consistent after art changes.

## Native notes (2026-11-01)

Native ground, squirrel, trees, mailbox, room, and telescope assets explicitly set `fill="none"` on open strokes that otherwise rendered black on iOS. Original prototype source and whole-town references remain available. Flutter SVG does not fully implement all filters; evaluate native rendering on devices. See [native validation](../docs/10-native-validation.md). Generated app icons are in `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
