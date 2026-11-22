# SlingshotForDinosaurs UI design system

Derived from `Docs/UI/References/` (01-06) and the Stylized art direction. These are the exact tokens implemented in `Modules/Shared/Theme.luau` and the `Gui/Components/` library. If a screen needs something not listed here, add it here first.

## Direction

Bright, chunky, toy-like and instantly readable at phone size: thick dark outlines, white display text with a dark stroke, colour-coded buttons, playful badges and stickers (refs 01, 03, 04, 06). Ref 02 (the sleek, flat style) is **not** the direction; we only borrow its quest-strip layout idea for future quests. Ref 05's "worth X / struck-through price" pressure styling is deliberately **not** used (audience 7-15, see DECISIONS #10).

## Colour

| Token | Hex | Use |
|---|---|---|
| `Ink` | `#1E1B2E` | All outlines, text strokes, shadows |
| `White` | `#FFFFFF` | Display text, icons on colour |
| `Panel` | `#F4F1EA` | Card / modal body |
| `PanelDeep` | `#E4DDCF` | Card inner well, disabled |
| `Green` | `#3DDC4E` → `#1FA82F` | Shop, Buy (Cash), Collect, positive |
| `Blue` | `#3FB8FF` → `#1C86E0` | Index, info, secondary |
| `Gold` | `#FFD23F` → `#F5A200` | Passes, VIP, rewards |
| `Orange` | `#FFA62B` → `#F07800` | Affordable price, primary call to action in cards |
| `Red` | `#FF4B4B` → `#D11A1A` | Close (X), unaffordable, danger |
| `Purple` | `#B266FF` → `#7C2BE0` | Robux / premium buttons |
| `Grey` | `#8A8797` → `#5E5B6B` | Equipped / owned / disabled state |
| `Cash` | `#5CFF5C` | Cash numbers |
| `Power` | `#FFE14D` | Power numbers |

Buttons use a vertical `UIGradient` from the light to the dark value of their colour. Mutation accents: Golden `#FFC531`, Frost `#9FE3FF`, Magma `#FF4D1A`, Toxic `#9BE22D`, Cosmic `#8E44FF` (with a pink `#FF5EDB` gradient). Biome accents follow the GDD palette.

## Typography

| Role | Font | Size (at 1.0 UIScale) | Treatment |
|---|---|---|---|
| Display / titles | Fredoka One | 40-56 | White, `UIStroke` Ink 3-4 px |
| Button label | Fredoka One | 26-32 | White, stroke Ink 2.5 px |
| Big numbers (cash, power, $/s) | Fredoka One | 32-44 | Token colour, stroke Ink 3 px |
| Body / sub-labels | Builder Sans Bold | 18-22 | Ink on Panel; white + stroke on colour |

All text uses `TextScaled = false` with explicit sizes driven by `UIScale`, so sizes stay consistent. Numbers are abbreviated (`1.2K`, `3.4M`, `5.6B`).

## Shape language

- **Corner radius:** buttons 14 px, cards 16 px, modals 20 px, chips and badges are fully round.
- **Outline:** `UIStroke` Ink, 3 px (buttons and cards), 4 px (modals); `ApplyStrokeMode = Border`.
- **Lip / drop:** every button sits on a 5 px Ink "lip" (a duplicate frame offset down) for a chunky 3D feel. Pressing moves the face down 3 px.
- **Stickers:** "NEW!" (orange, rotated −8°, ref 03); notification "!" (red circle with white "!", ref 01/06).

## Components (`Gui/Components/`)

| Component | Spec |
|---|---|
| `Button` | Colour variant, icon (left), label, optional badge. Min 64×64 touch target. States: idle, hover (+4% scale, brighter), pressed (face −3 px, 0.96 scale), disabled (Grey, 60% icon). Controller focus: white 3 px outer ring and a scale pulse. |
| `SideButton` | HUD left stack (Shop / Index / Passes, ref 01/06): 210×72, icon + label, each a different colour, optional "!" badge. |
| `IconButton` | Square 84×84 HUD right-column icon (ref 01) with optional timer label beneath it. |
| `Panel` / `Modal` | Coloured header bar (title left, red X right), Panel body, Ink 4 px stroke, 20 px radius (ref 04). Opens with a scale 0.85 → 1 back-out tween over 0.18 s and a dim backdrop at 45%. |
| `ItemCard` | ref 04: name (display), rarity sub-label, viewport/icon, tier chip, price button (Equipped Grey / affordable Orange / unaffordable Red / Robux Purple). Selected card: 4 px Green outline. |
| `CurrencyPill` | Icon + big number, bottom-left stack (ref 01/06). Cash has a "+" Purple mini-button that opens cash packs. The number pops (1.15 scale) on gain. |
| `Chip` | Rounded label for Size / Mutation / Rarity, coloured by token. |
| `TimerWidget` | Bottom-right event countdown (ref 01): icon + "Meteor Storm in 4m 12s", italic display font. |
| `Toast` / `Announcement` | Top-centre banner for rare catches and events. |

## Layout (HUD)

```
┌──────────────────────────────────────────────────────────┐
│ [Roblox]            BIOME · 1,234 m (best)      [Leader] │
│                                                [Pass]    │
│ [Shop  !]                                      [Offer]   │
│ [Index  ]            (clear launch area)       [Storm]   │
│ [Passes ]                                                │
│                                                          │
│ $ 12.4K  +                      [TAP! / TRAIN]   ☄ 4m12s │
│ ⚡ 1,050                                                  │
└──────────────────────────────────────────────────────────┘
```

- Respect `ScreenInsets = CoreUISafeInsets`; leave a 16 px margin.
- The centre third stays clear at all times (the launch/aim area). Contextual buttons appear bottom-centre (TRAIN on pads, TAP! during bounce windows); TAP! is full-screen tappable.
- UIScale: phones 0.62-0.75, tablets 0.85, desktop 1.0, console 1.1 (10-foot), chosen from viewport size.

## Motion

- Buttons: 0.08 s press, 0.12 s release back-out.
- Reward numbers fly from the source to the CurrencyPill (6-10 coin sprites).
- Reveal card: card drops in (0.25 s back-out), "NEW!" sticker slams with a slight rotation, and the chips stagger in at 0.06 s each; Cosmic adds a rainbow gradient rotation.
- Never animate more than one modal at once; never block input for longer than 0.3 s.

## Accessibility & input

- Minimum touch target 64×64 px (after UIScale); primary actions 88 px+.
- Every screen is controller-navigable (`Selectable`, `NextSelection*`, auto-select the primary button on open, B closes).
- Text contrast: white + Ink stroke on any colour; Ink on Panel.
- No information is shown by colour alone: rarity and mutation are always also written as text.
