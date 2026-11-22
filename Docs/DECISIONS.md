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
23. **Procedural dino walk instead of rigged skeletal animation.** Dinos wander their plot with a waddle (bob + roll) and idle pauses, driven by client CFrames. This is cheap on mobile and works for all 15 species without rigs. Skeletal cycles can come later.
24. **Plot fences stay as simple planks.** Modelled fence segments around 8 plots would add about 130k triangles, too much for the low-end mobile budget.
25. **Bottom-right HUD widgets move up on touch devices**, so Roblox's jump button never covers the event timer.
26. **Paid rerolls never downgrade.** If the new mutation is worth less than the current one, the dino keeps its mutation and the player sees "No luck this time". Losing a Golden to a bought potion felt bad in QA, which matters for a 7-15 audience.
27. **Biome floors and the rim use Roblox Terrain** (one material and colour per biome, plus pools, tar, glacier and lava patches) rather than Blender floor meshes. Terrain textures large ground areas far more cheaply, and the Blender kit covers the vertical surfaces.
28. **QA admin tools (+3 rerolls, fill park) are Studio-only.** Both the client and the server refuse them in live servers.

## 2026-11-22: Pre-launch retention + monetisation

29. **Server size 8** set through the Places API.
30. **New monetisation:** 2x Luck pass (249 R$), Luck Potion (2x for 15 min, 39 R$) and Super Luck Potion (5x for 15 min, 99 R$), with private servers at 50 R$. Potion time stacks rather than wasting overlap.
31. **Retention systems** (`RetentionServer`, `Config/RetentionConfig`): a 7-day login streak (resets if a day is missed), 3 seeded daily quests plus a weekly quest, promo codes (LAUNCH, DINOPARK), Rebirth (+25% Power and distance each; keeps dinos, Index, slots and passes), a perfect-bounce streak (+5% luck per step, max +50%), and a +10% Premium income bonus. Every value is live-tunable.
32. **Global leaderboards** (Farthest Launch, Top Earners) are physical boards on the rim, backed by OrderedDataStores, written every 3 minutes and on leave, and refreshed every 90 seconds.
33. **Store page:** title "Slingshot For Dinosaurs", a description with feature bullets and codes, a Blender game icon, and 2 thumbnails in the reference style (chrome + pink 3D logo top-left, cheering avatars, giant Cosmic T-Rex, sunset sky). They're set via the Assets API and pending moderation.

## 2026-11-22: Gifting, exclusive rotation, notifications, voice chat

34. **Exclusive dino rotation** (`MonetizationConfig.ExclusiveRotation`, `Shared/ExclusiveRotation`): 5 limited dinos (Celestial Raptor, Magma King Rex, Frost Brachio, Toxic Spino, Golden Trike) rotate every 14 days, deterministic from a fixed anchor so every server agrees with no DataStore. Players keep every one they buy. Income: the first owned exclusive earns 1000% of the best regular dino, and each extra one adds +100%. Stacking 10x per exclusive would have broken the economy. The old one-off exclusive flag migrates to Celestial Raptor. An owned exclusive can't be bought again, and owned offer cards hide entirely.
35. **Pass gifting:** 5 "Gift: <pass>" developer products at pass price. The buyer picks a player in the server from the GIFT button on each pass card. The server validates the recipient (present, not the buyer, doesn't own the pass) and records the target for 5 minutes. If the recipient left mid-purchase, the gift is delivered by ProfileStore message on their next join. If the recipient already owns the pass, they get 3 rerolls instead. Gifted passes live in the profile (`GiftedPasses`) and merge with real ownership.
36. **Voice chat disabled** via the Open Cloud universe API (`voiceChatEnabled = false`). Note: the age rating comes from the maturity questionnaire, not the voice setting.
37. **Experience notifications:** the opt-in prompt appears once, after 10 launches (13+ eligible users only, per Roblox). `NotificationServer` sends through Open Cloud with a key held in a Roblox Secret (`NotificationsKey`). It's a no-op until that secret and the message ids in `Config/NotificationConfig` exist. First use: "GiftReceived" for recipients who were offline.
38. **QA helpers `QA_Exclusive` and `QA_Gift`** join the Studio-only admin actions.

## 2026-11-22: Social, badges, music, analytics

39. **Badges** (`BadgeConfig`, `BadgeServer`): 10 badges (first catch, first mutation, 4 biome badges, Legendary, Colossal, Cosmic, first rebirth). Creating them through the API needs the `legacy-badges` key permission. `create_badges.sh` uses only the free daily quota (`expectedCost=0`), so it never spends group Robux. Ids of 0 are skipped in game until then.
40. **Friends:** an Invite button (SocialService), plus +10% luck per friend in the server (max 3), shown as a HUD chip. Co-op play is the cheapest growth loop.
41. **Community group:** Roblox has no API to create a group (it costs Robux and is web-only), so the existing owner group "Blue Chip Games" is the community. Members earn +10% income, and there's one automatic join prompt after 15 launches plus a HUD button for non-members.
42. **Music:** Roblox-licensed APM tracks (free, no licensing risk): a shuffled upbeat playlist with a storm track that crossfades in during weather events, and a "Mute Music" toggle. The ElevenLabs connector has no music generation.
43. **Favourite prompt:** shown once, on the first mutated catch after 8 launches (a happy moment). Asking on join hurts conversion.
44. **Session and acquisition analytics:** SessionStart/SessionEnd custom events carry the join source (launchData `src:<source>:<campaign>`, notification, invite, teleport or Roblox) and a length bucket. `Tools/AnalyticsReport.ps1` pulls KPIs, funnels, custom events and sponsored ad spend from the Open Cloud Analytics Query API. `Docs/UPDATE_PLAN.md` holds the targets, decision rules and roadmap.
45. **Asset 203785492 warning** comes from the Rojo Studio plugin's sound player (a "Pop Close Sound" loaded as the wrong type), not the game. It doesn't occur in live servers. While tracking it, the guide beam's missing built-in texture was replaced with a Blender chevron.

## 2026-11-22: Launch hardening

46. **Soft shutdown** (`SoftShutdownServer` / `SoftShutdownController`): when public servers close for an update, players see an "updating" screen, are moved to a temporary reserved server, and are sent straight back to a fresh server on the new version. ProfileStore session locking carries their progress over. This is skipped in Studio and in player-owned private servers.
47. **Analytics alerts** (`Tools/create_alerts.sh`): 7 alerts covering client crash rate, server FPS, phone FPS, and week-over-week drops in DAU, peak CCU, revenue and D1 retention. Roblox refused them for now ("not enrolled in PerformanceMonitoringV2", which needs live traffic) and the key needs `universe.analytics.alert:write`. Run the script after launch.
48. **Dev save reset:** a Studio-only `QA_ResetSave` admin action (also a button in the admin panel) backs up the profile to `Backup_P_<userId>_<utc time>` in the profile DataStore, resets every key to the template (keeping PurchaseIds), clears global leaderboard entries and kicks the player. Used on the owner account on 2026-11-22; backups are `Backup_P_11712429117_202611221652` (full save) and `_202611221654` (cash).
49. **Store description** now lists the limited dino, friends/gifting, badges and the group perk (via the Places API).

## 2026-11-22: Pre-launch QA pass

50. **Device testing** with the Studio Device Simulator: Galaxy A06 (smallest common phone, 705x338), iPhone 17 Pro, iPad 6th gen (4:3), Xbox One (1080p TV) and desktop. Fixes: the left menu is top-anchored with 54px rows (it ran into the cash pills at the 0.5 minimum scale), and on touch screens the event timer sits left of the right-hand column and above the jump button.
51. **Console/controller:** D-pad Left/Right jumps into the left menu or right column (Roblox's own UI-select is hidden on console), D-pad Down leaves. Prompts switch to controller wording ("HOLD R2", "PRESS A!") while a controller is the last input. Consoles get a 4% overscan-safe margin around the HUD.
52. **Code review fixes:**
    - The gift recipient is saved in the buyer's profile (`PendingGifts`) and cleared only after delivery, so a crash or leave mid-purchase can no longer hand the pass to the buyer.
    - The MessageAsync result is checked.
    - A per-receipt lock prevents double grants.
    - RefreshPasses merges instead of overwriting: it re-reads gifts after its yields, keeps a pass when the ownership lookup fails, and keeps passes bought this session.
    - The rotation and daily quests use the server-synced clock on clients.
    - SocialAction is rate-limited, with one group recheck at a time.
    - Per-player tables are cleaned up even when a player leaves mid-load.
    - The friend scan no longer blocks other join logic.
    - The soft-shutdown holding server retries the teleport and then asks the player to rejoin.
    - The Quests window rebuilds at UTC midnight.
    - Gifting to someone who owns the pass now explains why it was refused.
    - A failed invite prompt no longer leaves a listener behind.
53. **Stress test:** 4,800 junk remote calls in 0.1 s (wrong types, NaN, 5,000-character strings) caused no errors, granted nothing, and the server held 59 Hz. PromptPurchase is now limited to 1 per second per player (it previously opened a prompt and logged a funnel event per call).
54. **Performance (Studio, this PC):** client 59–60 fps with a full park (worst frame 19 ms); server 59 Hz (worst 32 ms); about 1,590 workspace instances and 836 parts. A real low-end phone test is still needed.

## 2026-11-22: Playtest feedback fixes

55. **Dinos sank into the park.** The rim terrain was filled to RimY, but Roblox's 4-stud terrain voxels put the grass surface about 2 studs higher, so dinos (and the launch pads) placed at RimY sat inside the ground and small dinos vanished. The rim is now filled to RimY − 2, so the surface lands at RimY, and park dinos are also snapped onto the terrain by raycast at their home spot and wander targets.
56. **Clicking the world started the slingshot.** Holding the left mouse button anywhere began charging, which blocked camera control. Charging now starts only from the HOLD button, Space or R2. A click or tap anywhere still bounces mid-flight. Letting go anywhere fires (so sliding off the button can't leave a charge stuck), and the launcher ignores input while the Welcome Back popup is up (a tap on Collect used to fall through to HOLD).
57. **UI restyle** to match the references (see the note at the top of Docs/UI/DesignSystem.md): squarer flat buttons on a same-hue base, breakout menu icons, distinct colours per button, bare outlined currency and timer, dark-framed windows, no emoji.
58. **Icon refresh.** The whole Blender icon set rendered pastel: palette values were fed to materials as linear (not sRGB), and strong sky light plus emission clipped colours toward white. `icons.py` now gamma-converts the palette and uses toon lighting (dim ambient, softer sun, emission 0.75) during icon renders only. All 16 HUD icons were re-rendered.
    - New: one slingshot icon per tier (twig, bamboo, bone, tar-rubber, mammoth tusk, obsidian, meteorite) and a park icon for Park Slots, replacing a single grey slingshot and an emoji.
    - The same icons are set on every pass and developer product through Open Cloud: 31 items, including per-tier slingshot products, the luck potions and the gift products.
