# Decision log

Significant autonomous (BCDK Recommended) decisions, newest last. Each entry: what, why.

## 2026-11-22: Pre-production

1. **Art style: Stylized** (Developer Requested). The brief names it explicitly; the UI references are chunky, outlined simulator UI, which suits a stylized simulator.
2. **UI references live in `Docs/UI/References/`**, not `Docs/UI-refs/` as the brief says. Same content; the folder was created earlier in this repo.
3. **Blender 5.3 accepted** in place of 5.2. It is the running, MCP-connected Blender (Microsoft Store build); the pre-flight script only searches for 5.2 in the standard install path.
4. **Displayed distance is decoupled from world size.** Distance is a growing number (meters, up to 500,000 m), but the canyon is a fixed ~2,000-stud world: each biome is a 400-stud segment, and meters map piecewise onto it. Why: simulator numbers need exponential growth, but a physically 500 km canyon is impossible to render or stream on low-end mobile. Every biome stays visible from the rim (a must-keep).
5. **Server-authoritative launches.** The server computes the base distance, the bounce windows and every catch roll (species, size, mutation) from a server seed. The client only animates the flight and sends one bounce tap, validated against the server's window. Why: distance and rolls drive the whole economy, so they can't be trusted to the client.
6. **Training: auto-train while standing on a pad, plus tap-to-boost.** The brief says "train on pads"; pure standing is passive, and pure clicking is tiring on mobile. Standing gives steady gains (mobile-friendly, zero menus); tapping adds up to 5 trains/sec.
7. **Offline earnings at 50% of online rate, capped at 8h (12h with VIP).** An uncapped 100% rate breaks pacing and makes active play feel pointless. The cap is a retention hook (come back every day).
8. **Full enclosure → choice popup.** Replace the weakest dino, or sell the new one for 60 s of its income. "Auto-replace weaker" is a toggle. Why: catches never feel wasted, and there's no inventory screen to manage (the brief asks for zero tiny menus).
9. **Limited Exclusive Dino capped at one per player** and computed from the best *other* dino's base income. Why: without the cap, buying several would compound exponentially and break the economy.
10. **Mutation Reroll potions show their odds before purchase.** Roblox policy requires disclosure for paid random items, and the audience is 7-15. No fake "was" prices or pressure copy, even though one UI reference uses them.
11. **Weather cycle: 15 min clear + 5 min event, alternating Meteor Storm and Ice Age.** This fits the brief's "20-minute world events" while keeping clear-sky play the norm.
12. **Bait raises luck; slingshots raise distance.** Each upgrade track has one job, so players always know why they're buying.

## 2026-11-22: Core loop production

13. **No slow-mo during bounce windows** (GDD 8 mentioned 0.4x slow-mo on mobile). The server's clock judges the windows, so slowing the client's flight would desync timing. A shrinking TAP! ring with a geyser that erupts 0.6 s early gives the same readability.
14. **Early taps lose that window.** Tapping before a window (outside the OK range) marks it missed. Without this, tap-spamming would hit every window.
15. **Plot assignment is lazy** (`PlotServer.EnsurePlot`). BCDK runs `SMProfile.PlayerAdded` (which yields until the profile loads, then fires profile-ready) before project modules' `PlayerAdded`, so either path may assign the plot first.
16. **Cash writes bypass `SMCurrency:Add`** (`PlayerDataServer.AddCash/SpendCash`). They use the same `CurrencyReplica`, so LMCurrency still mirrors them. SMCurrency prints on every call, which would flood the Output window at one income tick per second.
17. **World is generated at server start** (`WorldBuilder`) because Rojo doesn't sync Workspace. Blender assets drop into `ReplicatedStorage.Assets.World/Dinos` and replace the stand-ins automatically.
18. **Robux items with Id 0 are simulated in Studio only.** Passes and products aren't created on Roblox yet. Studio grants them directly so the grant paths can be tested; live servers hide those buttons.

## 2026-11-22: Monetisation live + asset pipeline

19. **4 passes and 19 developer products created on Roblox** (on sale at the brief's prices), with IDs in `MonetizationConfig`. Earlier messages said 22 products; the config only ever had 19.
20. **Assets load by ID at runtime** (`AssetLoader`, in parallel, with a 6 s cap) rather than living in the place file. They stay version-controlled through config, and the world falls back to stand-ins if Roblox is slow.
21. **Dinos are untextured meshes with named colour regions** (Body, Belly, Accent, EyeWhite, Pupil). The game colours them from `DinoConfig` and recolours them for mutations, so 15 species x 6 mutations need no texture variants.
22. **No music loop yet.** The connected ElevenLabs connector only offers SFX and voice. Music needs the full ElevenLabs connector.
