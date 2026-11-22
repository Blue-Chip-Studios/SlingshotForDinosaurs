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
        Compy = 92842992229098, -- v2 (dino_v2.py): smooth body, separate legs
        Velociraptor = 84652737346204, -- v2
        Parasaurolophus = 76360723125219, -- v2
        Dilophosaurus = 71563285544183, -- v2
        Baryonyx = 140603822609337, -- v2
        Spinosaurus = 76363850440795, -- v2
        Pachycephalosaurus = 115124775792165, -- v2
        Ankylosaurus = 77953219734439, -- v2
        Triceratops = 121257269740875, -- v2
        Cryolophosaurus = 131966674438149, -- v2
        Therizinosaurus = 112972479793807, -- v2
        Brachiosaurus = 77244473319273, -- v2
        Carnotaurus = 135527739801781, -- v2
        Giganotosaurus = 73604210424398, -- v2
        TRex = 109273798018289, -- v2
        Protoceratops = 103452986132565, -- v2
        Gallimimus = 108308012612570, -- v2
        Stegosaurus = 112169800287147, -- v2
        Iguanodon = 125616515106313, -- v2
        Corythosaurus = 131846553188349, -- v2
        Ouranosaurus = 103346113048771, -- v2
        Allosaurus = 80395410943948, -- v2
        Styracosaurus = 79021982595781, -- v2
        Diplodocus = 89053821605031, -- v2
        Microraptor = 113084508877821, -- v2
        Kentrosaurus = 105056901181021, -- v2
        Amargasaurus = 138821328429098, -- v2
        Pteranodon = 78177604866271, -- v2
        Archaeopteryx = 133870457292316, -- v2
        Quetzalcoatlus = 74497940443790, -- v2
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
        Compy = 117633387552864,
        Velociraptor = 97944565576352,
        Parasaurolophus = 108660858358924,
        Dilophosaurus = 104029374020379,
        Baryonyx = 93737161770735,
        Spinosaurus = 75317220732458,
        Pachycephalosaurus = 125711589025988,
        Ankylosaurus = 70865695391659,
        Triceratops = 114265819575656,
        Cryolophosaurus = 128686093282725,
        Therizinosaurus = 103525720557858,
        Brachiosaurus = 132295296167805,
        Carnotaurus = 123558833694995,
        Giganotosaurus = 97272805454215,
        TRex = 115798599236582,
        Protoceratops = 112768364412263,
        Gallimimus = 111771167453534,
        Stegosaurus = 100997959794511,
        Iguanodon = 126864234050534,
        Corythosaurus = 120688726266770,
        Ouranosaurus = 78449346517676,
        Allosaurus = 122624025179677,
        Styracosaurus = 133213078257962,
        Diplodocus = 122296851277609,
        Microraptor = 111759511964826,
        Kentrosaurus = 135077094675129,
        Amargasaurus = 80925837149363,
        Pteranodon = 95845532217533,
        Archaeopteryx = 77844417774930,
        Quetzalcoatlus = 129312014886651,
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
