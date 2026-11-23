--!strict
--[[
    AssetConfig
    -----------
    Roblox asset ids for content made in the Blender / ElevenLabs pipeline
    (uploaded with Assets/Blender/scripts/upload_asset.sh, owned by the
    game's group). AssetLoader (server) loads the models into
    ReplicatedStorage.Assets at startup; anything missing falls back to the
    TEMP_ stand-ins.
]]

return {
    -- Dinosaur models: MeshParts named Body / Belly / Accent / EyeWhite / Pupil, facing -Z.
    Dinos = {
        Compy = 140096562609507, -- v4 (review loop)
        Velociraptor = 128447994244101, -- v4 (review loop)
        Parasaurolophus = 90715890340302, -- v4 (review loop)
        Dilophosaurus = 135629141769487, -- v4 (review loop)
        Baryonyx = 92098735741734, -- v4 (review loop)
        Spinosaurus = 97917055756977, -- v4 (review loop)
        Pachycephalosaurus = 74826019195727, -- v4 (review loop)
        Ankylosaurus = 77953219734439, -- v2
        Triceratops = 121257269740875, -- v2
        Cryolophosaurus = 130787204723420, -- v5 (predator silhouettes)
        Therizinosaurus = 136596167082083, -- v4 (review loop)
        Brachiosaurus = 71628132987784, -- v4 (review loop)
        Carnotaurus = 110466577490577, -- v5 (predator silhouettes)
        Giganotosaurus = 111371701237174, -- v5 (predator silhouettes)
        TRex = 80838018752271, -- v5 (predator silhouettes)
        Protoceratops = 103452986132565, -- v2
        Gallimimus = 70573403836657, -- v4 (review loop)
        Stegosaurus = 112169800287147, -- v2
        Iguanodon = 79229269037039, -- v4 (review loop)
        Corythosaurus = 106551758625444, -- v4 (review loop)
        Ouranosaurus = 85594130083561, -- v4 (review loop)
        Allosaurus = 109177964894011, -- v5 (predator silhouettes)
        Styracosaurus = 79021982595781, -- v2
        Diplodocus = 71814338898788, -- v4 (review loop)
        Microraptor = 87002879631362, -- v4 (review loop)
        Kentrosaurus = 105056901181021, -- v2
        Amargasaurus = 96542990756791, -- v4 (review loop)
        Pteranodon = 93632854399722, -- v4 (review loop)
        Archaeopteryx = 108876757577352, -- v4 (review loop)
        Quetzalcoatlus = 112969036373880, -- v4 (review loop)
    },

    -- World props (Model assets), keyed by the names WorldBuilder.PlaceProp asks for.
    World = {
        JungleTree = 80688192266520,
        SwampTree = 91506467692473,
        Rock = 88085453805990,
        TarRock = 93555051233468,
        IceBlock = 135156522704300,
        LavaRock = 130677280936772,
        Volcano = 135708295927818,
        GeyserVent = 92857209851695,
        Cactus = 113313071890140,
        Mesa = 106414003297015,
        PalmTree = 85171795645659,
        Coral = 90014554608859,
        Redwood = 116600328271715,
        CrystalCluster = 89825398164630,
        SkyIsland = 90782611166780,
        Cloud = 76483736936847,
        VolcanoBig = 103299850582351,
        LaunchSlingshot = 99721449867774,
        SlingshotItem = 118343737652140,
        Bait_Berries = 139213804648851,
        Bait_Fish = 100215674017841,
        Bait_Steak = 93890753615551,
        Bait_GoldenEgg = 139274410998847,
        Bait_AmberMosquito = 104951567041903,
        Bait_MeteorMeat = 128989995866679,
        CliffWall = 138097440252146,
        FenceSegment = 139284654638072,
        Signpost = 128995671270016,
        TrainingPad = 110135813692547,
        GrassClump = 81031363976889,
        Bones = 115852318422328,
        Crystal = 127805842040289,
    },

    -- Images (rbxassetid) for UI icons / portraits.
    Images = {
        -- Dino portraits (reveal card, Index)
        Compy = 93749157217366,
        Velociraptor = 125561155036491,
        Parasaurolophus = 85334600177714,
        Dilophosaurus = 137066793765850,
        Baryonyx = 108750444124494,
        Spinosaurus = 82613386472462,
        Pachycephalosaurus = 112825643836735,
        Ankylosaurus = 70865695391659,
        Triceratops = 114265819575656,
        Cryolophosaurus = 118627506599486,
        Therizinosaurus = 119113307486636,
        Brachiosaurus = 71601964136367,
        Carnotaurus = 96123925354784,
        Giganotosaurus = 135304581877576,
        TRex = 109788542590506,
        Protoceratops = 112768364412263,
        Gallimimus = 110897144413503,
        Stegosaurus = 100997959794511,
        Iguanodon = 97328589302116,
        Corythosaurus = 86942494355680,
        Ouranosaurus = 124219876683842,
        Allosaurus = 90965721875133,
        Styracosaurus = 133213078257962,
        Diplodocus = 140405072736570,
        Microraptor = 83972989255844,
        Kentrosaurus = 135077094675129,
        Amargasaurus = 104258349698180,
        Pteranodon = 138738360293701,
        Archaeopteryx = 116342215788036,
        Quetzalcoatlus = 117997148410318,
        -- Shop items
        SlingshotItem = 99032474657018,
        Bait_Berries = 96598653687184,
        Bait_Fish = 84706401426083,
        Bait_Steak = 122289660973681,
        Bait_GoldenEgg = 140339826667206,
        Bait_AmberMosquito = 81487227930950,
        Bait_MeteorMeat = 97852309002124,
        -- HUD / pass / product icons (outlined toon renders, Assets/Blender/scripts/icons.py)
        Icon_Bag = 128006754112758,
        Icon_Book = 108826882497453,
        Icon_Cash = 84102090721361,
        Icon_Crown = 85550489389171,
        Icon_DoubleCash = 82260075122915,
        Icon_DoublePower = 110062923382559,
        Icon_Gear = 96674620702454,
        Icon_Gift = 96613586098184,
        Icon_Meteor = 126913879394980,
        Icon_Muscle = 102679189623491,
        Icon_Potion = 110536541498183,
        Icon_Power = 70713605133785,
        Icon_Star = 111021003107050,
        Icon_Target = 82230488634213,
        Icon_Vault = 135875098785893,
        Icon_Wrench = 139649092164224,
        -- Shop: one slingshot per tier (ShopConfig.Slingshots Id) and the park-slots tab
        Sling_Twig = 133911825178042,
        Sling_Bamboo = 122397234807451,
        Sling_Bone = 93186687518247,
        Sling_TarRubber = 106533721339327,
        Sling_MammothTusk = 104883648884293,
        Sling_Obsidian = 129839138715805,
        Sling_Meteorite = 114117888526333,
        Sling_Crystal = 108676606921566,
        Sling_Celestial = 109375242842889,
        Icon_Park = 107898141125354,
    },

    -- Sounds (rbxassetid) keyed by SoundController names.
    Sounds = {
        Launch = 86400273776083,
        Charge = 74016606023909,
        Bounce = 105105157209278,
        Perfect = 83842964434961,
        Impact = 96690035989640,
        Reveal = 99556875150161,
        Coin = 123599546494514,
        Click = 128874029466854,
        Error = 100156454441026,
        Event = 75349777382519,
        Ambience = 109438410222145, -- looping jungle soundscape (ElevenLabs)
        Fanfare = 116569728192023, -- celebration (Epic/Mythic catches)
        Roar = 117194036391090, -- Mythic catch roar
    },
}
