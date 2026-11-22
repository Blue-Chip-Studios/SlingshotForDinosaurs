# Art & audio tracker

Pipeline: Blender scripts (`Assets/Blender/scripts/`) → FBX/PNG in `Assets/Exports/` → `upload_asset.sh` (Open Cloud, owned by the game's group) → ids in `Config/AssetConfig.luau` → `AssetLoader` loads models at server start. Anything missing falls back to a `TEMP_` stand-in automatically.

## Done (real assets in game)

| Item | Source | Config |
|---|---|---|
| 15 dinosaurs (4 shared body plans, metaball bodies, named colour regions) | `dino_generator.py` | `AssetConfig.Dinos` |
| Trees (jungle, swamp), rocks, tar rock, ice block, lava rock | `world_props.py` | `AssetConfig.World` |
| Hero volcano, geyser vents, giant launch slingshot | `world_props.py` | `AssetConfig.World` |
| Pedestal items: slingshot (tinted per tier), 6 baits | `world_props.py` | `AssetConfig.World` |
| Dino portraits + shop item icons (transparent PNG renders) | Blender render pass | `AssetConfig.Images` |
| 10 SFX: launch, charge, bounce, perfect, impact, reveal roar, coin, click, error, event | ElevenLabs (`eleven_text_to_sound_v3`) | `AssetConfig.Sounds` |

## Still temporary

| Item | Where | Plan |
|---|---|---|
| Biome floors and canyon walls (flat parts) | `WorldBuilder.BuildCanyon` | Blender cliff-wall and floor kit per biome |
| Rim ground, cliff face, rails, plot fences, signs | `WorldBuilder.BuildRim/BuildPlots` | Blender rim kit (fence, signpost, cliff) |
| Training pads (neon slabs) | `WorldBuilder.BuildTraining` | Blender pads themed per tier |
| HUD icons (emoji) on side buttons | `Gui/HUD.luau` | Icon set rendered in Blender |
| Pass and product icons (Roblox default) | Creator Dashboard | Blender-rendered icons, then patch via Open Cloud |
| Music loop | none | Needs the full ElevenLabs connector (this connector has no music) |
| Dino animation (idle bob only) | `PlotController` | Rigged walk/idle cycles |
