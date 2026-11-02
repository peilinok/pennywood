# Pennywood Design System

Wish journal 0.3, 2026-11-01. iPhone / iPad. Native Flutter uses these semantic colors and six-page structure. See [native scope](../../docs/10-native-validation.md).

## Product and interaction

For children aged 7-10 and parents. Wishes guide children; concrete icons and short phrases describe real tasks. Parents share the brand while emphasizing ownership, amounts, and action state.

- First screen: what I want, how much is confirmed, what I can do today.
- Three child destinations: wishes, tasks, pocket money. Three parent destinations: review, children/wishes, agreements. Name the child on every monetary action.
- One balance contributes to one primary wish; queued wishes do not duplicate it. Borrowing/projections do not fill savings progress.
- Tap once to submit a quick task. Repeat taps show state. Withdraw before parent checking.
- Check and payment are separate. Require actual delivery/reserved-custody confirmation before enabling payment.
- No streak-loss punishment, timed reward claims, leaderboards, or full-screen fireworks.

## Visual direction

Chestnut, grass, and paper: paper cards, charcoal text, chestnut actions, green progress. Wheat yellow emphasizes actual payment only. Wish art uses a blue-gray night sky and grassy slope; purple stays within existing telescope art. Task illustrations keep their own colors without extra pastel tiles. The squirrel provides companionship without mandatory walking navigation.

Use subtle card borders, not colored floating shadows, heavy glass, plastic depth, or elaborate textures. Functional icons use existing 24 x 24 line assets with 1.7 stroke width and text color; illustrations retain soft original colors. Do not substitute emoji for icons.

## Semantic colors

| Token | Light | Dark | Purpose |
|---|---|---|---|
| paper | `#F8F7F2` | `#242620` | Page background |
| surface | `#FFFEFA` | `#2D3029` | Wish/task/form cards |
| surface-soft | `#EEEDE5` | `#35382F` | Navigation and terms |
| ink | `#302D27` | `#F1EFE3` | Primary text |
| muted | `#686357` | `#C1BFB1` | Supporting text |
| brand | `#7C472E` | `#DFB587` | Chestnut brand/actions |
| on-brand | `#FFFEFA` | `#30251D` | Primary button text |
| brand-soft | `#F0E5D8` | `#3A3027` | Secondary action background |
| accent | `#E2B95B` | `#E6BE63` | Payment action |
| on-accent | `#3F301B` | `#30271A` | Payment text |
| accent-soft | `#F3E9CF` | `#413A28` | Payment confirmation/tags |
| green / green-soft | `#3F6748 / #E8EDDF` | `#B5C8A0 / #2E392C` | Progress, selected navigation, completion |
| blue / blue-soft | `#3D5C65 / #EDF1EF` | `#B7C8D0 / #2D383D` | Waiting/information |
| danger / danger-soft | `#933F32 / #F6E6DF` | `#F0B4A2 / #472F27` | Errors |
| line | `#DCD9CE` | `#505349` | Decorative separators |
| control-line | `#858171` | `#989B8D` | Required control boundaries |
| night / night-ground | `#2B4349 / #4C6253` | `#202F34 / #384A3D` | Illustrated sky/slope |
| night-text / star | `#FFF3DE / #E8D19C` | `#FFF3DE / #E8D19C` | Sky labels/moon/stars |

Pair state colors with text; color alone never indicates posting. Dark UI uses charcoal/wood, while artwork retains its own sky colors without inverting SVG. Historical browser pairings measured minimum text contrast 5.09:1 light and 5.96:1 dark; those measurements do not audit all native controls.

## Typography, spacing, components

- Use iOS system Chinese and Latin fonts, with tabular amounts. Prototypes download no fonts, avoiding fallback, licensing, and offline dependencies.
- Titles roughly 24-28, wish title 24, amounts 38-48, actions 16, task names 15-16, supporting text 12-14. Flutter text scales; do not fit important text by shrinking it.
- Base rhythm 4/8. Page margins 16-20 phone, 24-28 iPad; card gaps 12-16; section gaps 24-28.
- Corner radii 12/16/20/28 do not reduce hit regions. Targets at least 44 x 44 pt, primary actions 52 pt high, whole task cards tappable, neighboring targets separated by at least 8 pt.
- Normal text contrast at least 4.5:1. Audit required field borders/focus separately from decorative separators.
- Highlight one next step per panel. Read-only content must not resemble a button. Explain unavailable actions.

## Motion and feedback

| Event | Treatment | Suggested duration |
|---|---|---|
| Press | Background/opacity response, no layout shift | Within 120 ms |
| Panel entry | Small upward motion/fade | 240 ms |
| Progress update | Confirmed value and transformed progress | 240 ms |
| Submission | Saved/waiting message with withdrawal | 8-second notice; persistent state page |
| Payment | Brief harvest feedback and updated progress | About 4 seconds |
| Reduced motion | Final state directly, complete text retained | No decorative animation |

HTML has no native haptics/sound. Production haptics should be optional and limited to significant confirmations, not every tap.

## Panels, forms, accessibility

- Centered iPad panels and bottom panels in narrow windows, with scrolling and 44 pt close targets. Support Escape, focus containment/return, and non-interactive background where applicable.
- Visible labels, guidance, local errors. Invalid submission preserves input; multiple errors should focus an error overview.
- Functional icons have labels; decorative icons are excluded from semantics. Progress reads confirmed amount and target; monetary updates use full sentences.
- Window/orientation changes preserve child, ledger, forms, and payment confirmation. No required hover or drag.
- Use SafeArea, LayoutBuilder, and Semantics. iPhone supports portrait/both landscapes; iPad all directions and windowing. Reflow by actual available dimensions, not device name. Validate system rotation and resizing separately.

## Implementation and research boundary

Prototypes describe interaction only. Retain Flutter / Flame, pure Dart, and Drift layering; move colors/components into Flutter Theme and money actions through the unified service. CloudKit, pairing, production credentials, and ledger are not implemented by an HTML prototype.

Earlier `ui-ux-pro-max` searches for `kids education playful` suggested Claymorphism. Retain rounding, press feedback, and hierarchy while reducing plastic depth and retaining picture-book assets. Do not use its marketing-page layout or Latin-only font suggestions. Touch-target and `adaptive navigation accessibility --stack flutter` results informed LayoutBuilder/Semantics principles, not a dependency upgrade; search metadata referenced newer Flutter versions than this project.

## Palette revision

Feedback on the earlier purple/multicolor palette led to paper cards and fewer broad accent colors. Chestnut comes from the squirrel/wood, green from leaves/grass, wheat from the coin. Concentrate saturation in artwork and necessary actions rather than giving every card a theme color.

Targeted `color`, `organic natural warm`, and `craft handmade` searches returned flower-shop, food, and winery palettes unsuitable for this picture-book app. The semantic palette was manually derived from existing art and measured in both themes; the search did not automatically replace this system or upgrade dependencies.

## Investment learning interactions

The native product classroom follows the existing paper/chestnut/green palette and squirrel assets. Use a solid labeled curve and a dotted labeled curve, inspectable values, a named time slider with step buttons, finite playback with pause/resume, and direct results for reduced motion. The compounding tree grows by scale; dividend allocation uses a short state transition. No game animation, curve replay, or classroom scenario changes accounting state or real dates. Keep the classroom's unbounded hypothetical journeys distinct from real 30-day investment boundaries. Family product settings are shared; budgets and permission remain visibly child-specific.
