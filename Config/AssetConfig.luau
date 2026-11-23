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
    -- Dinosaur models: MeshParts named Body / Belly / Accent / EyeWhite / Pupil / Leg*, facing -Z.
    -- v7+: moving pieces are "<Region>_Head", "_Jaw" or "_Tail", pivoting on hidden "Joint_<Group>" markers.
    Dinos = {
        Compy = 83187192406709, -- plush
        Velociraptor = 114046472923552, -- plush
        Parasaurolophus = 119774665130622, -- plush
        Dilophosaurus = 83250012960013, -- plush
        Baryonyx = 131690927916605, -- plush
        Spinosaurus = 113892827267653, -- plush
        Pachycephalosaurus = 92405059393277, -- plush
        Ankylosaurus = 83094193905815, -- plush
        Triceratops = 121744813158839, -- plush
        Cryolophosaurus = 119065592831361, -- plush
        Therizinosaurus = 94352574301912, -- plush
        Brachiosaurus = 90742822084842, -- plush
        Carnotaurus = 129495837560566, -- plush
        Giganotosaurus = 100809032206517, -- plush
        TRex = 93137924593236, -- plush
        Protoceratops = 87761979984180, -- plush
        Gallimimus = 134518392437478, -- plush
        Stegosaurus = 134776366426017, -- plush
        Iguanodon = 140182206191175, -- plush
        Corythosaurus = 127945117491761, -- plush
        Ouranosaurus = 133675566762046, -- plush
        Allosaurus = 109635027799795, -- plush
        Styracosaurus = 83118899860211, -- plush
        Diplodocus = 84509479369971, -- plush
        Microraptor = 121051767553570, -- plush
        Kentrosaurus = 138101074870636, -- plush
        Amargasaurus = 82171154076312, -- plush
        Pteranodon = 134314661354494, -- plush
        Archaeopteryx = 82982123498164, -- plush
        Quetzalcoatlus = 120288593798086, -- plush
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
        -- Dino portraits (reveal card, Index): plush studio renders (plush.py render_plush_portrait)
        Compy = 111615976559215,
        Velociraptor = 122687998364997,
        Parasaurolophus = 128710774822012,
        Dilophosaurus = 139562191655403,
        Baryonyx = 122029436104878,
        Spinosaurus = 110441870427937,
        Pachycephalosaurus = 98119360858557,
        Ankylosaurus = 114452830712856,
        Triceratops = 102543667198342,
        Cryolophosaurus = 78797436403900,
        Therizinosaurus = 123045228035257,
        Brachiosaurus = 139241056705040,
        Carnotaurus = 128804882462240,
        Giganotosaurus = 72228936262093,
        TRex = 108892326892120,
        Protoceratops = 78993676044466,
        Gallimimus = 134004184155788,
        Stegosaurus = 124449240264115,
        Iguanodon = 105290235906682,
        Corythosaurus = 92196771275469,
        Ouranosaurus = 138673412966572,
        Allosaurus = 70955134192621,
        Styracosaurus = 125399430801344,
        Diplodocus = 120238193020161,
        Microraptor = 114906963629009,
        Kentrosaurus = 71727240650395,
        Amargasaurus = 92773930856997,
        Pteranodon = 71140208874541,
        Archaeopteryx = 111204330999769,
        Quetzalcoatlus = 102237614007629,
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
