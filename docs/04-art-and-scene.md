# Retained Town Art and Internal Scene

The selected direction is a soft picture-book palette, isometric diamond lawn, separate buildings, and a squirrel. Pennywood is the current brand; older names in reference artwork are historical.

Use the [complete SVG reference](../assets/svg/town-world-reference.svg) and [layered assets](../assets/README.md). The wish journal is the only production business entry. ADR 0003 retires the standalone walk and duplicated business panels. Keep existing scene rows, archive compatibility, assets and internal navigation/lifecycle tests; no schema conversion or scene reset is needed. The descriptions below document the retained scene harness and historical art, not a second production workflow. Unreviewed original images and old device screenshots are not public assets.

| Place | Appearance | Function |
|---|---|---|
| Savings cottage | Orange roof, left | Terms, dividends, deposits, holdings, classroom |
| Wish workshop | Tall purple-roofed building, upper area | Wishes, withdrawals, advance terms, installments |
| Task shop | Green roof, right | Real-work agreements, requirements, submissions |
| Time tree | Small foreground tree | Growth journal and reinvestment projections |
| Mailbox / pocket | Foreground mailbox and action entry | Cash, ledger, withdrawal and repayment records |

## Retained interactions

- Tap ground to walk; tap a building to walk to its entrance before opening. Paths avoid buildings and trunks.
- Sort character/buildings by ground or foot position; split foreground/background layers where needed.
- A new destination cancels the previous arrival action. Stop walking when opening identity or business panels.
- Support camera drag, zoom, and reset. Cards must not cover important entrances.
- Use shopkeeper dialogue and brief feedback. Afternoon/dusk is selectable; sound is opt-in and off by default.
- Today's story reflects real task state. Each child retains a separate position and footprints at four principal places.
- Show monetary feedback only after successful posting. Tree growth follows settled yields. Exploration never pays money.

## Reuse and coordinates

The [asset guide](../assets/README.md) documents extracted SVGs for buildings, characters, plants, task icons, and interiors. Rasterize to suitable atlases or parse compatible SVGs at load time, never every frame.

[scene-layout.json](../assets/scene-layout.json) defines the 860 x 530 logical drawing plane, entrances, depth, walkable polygon, and trunk obstacles. XY values are already projected drawing coordinates, not isometric tile indices. Flame must explicitly map render and hit-test coordinates.

The whole-town SVG is a visual reference. Runtime buildings, character, clickable places, shadows, paths, occlusion, and animations are separate objects. Interiors retain the isometric room and shopkeeper. Build business text, inputs, and buttons with Flutter, keeping readable picture-book panels and clear parent amounts, ownership, and approval states.

## Adaptive presentation

Render the town in current available space. Keep the camera separate from fixed HUD; scene scaling must preserve text readability and touch targets. Respect safe areas, keyboard, phone/iPad aspect ratios, and window resizing rather than scaling a desktop screenshot wholesale.

Device testing should check entrance recognition, dialogue readability, unobstructed paths, and understanding of repayments/dividend choices. Browser screenshots cannot establish child appeal or retention.
