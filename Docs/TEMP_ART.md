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
| Biome floors (flat parts with materials) | `WorldBuilder.BuildCanyon` | Blender floor tiles per biome (walls are done) |
| Rim ground, cliff face, rails, plot fences | `WorldBuilder.BuildRim/BuildPlots` | Fences kept as parts for performance (a modelled fence would add ~130k triangles); rim cliff next |
| Music loop | none | Needs the full ElevenLabs connector (this connector has no music) |
| Dino animation (procedural wander + waddle) | `PlotController` | Rigged skeletal cycles if wanted later |

## Added in the second art pass

| Item | Source | Config |
|---|---|---|
| Canyon cliff walls (stylised strata, tinted per biome, randomised) | `world_props.py` CliffWall | `AssetConfig.World` |
| Training pads (stone ring + glowing centre tinted per tier) | `world_props.py` TrainingPad | `AssetConfig.World` |
| Biome decoration: grass clumps, bones, ice crystals | `world_props.py` | `AssetConfig.World` |
| 16 outlined toon icons (HUD buttons, pills, pass/offer cards) | `icons.py` | `AssetConfig.Images` |
| Pass and developer product icons on Roblox | `set_monetization_icons.sh` | Open Cloud PATCH |
