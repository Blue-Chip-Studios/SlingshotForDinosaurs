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
        Compy = 71351312922196,
        Velociraptor = 118092507836783,
        Parasaurolophus = 124074268962687,
        Dilophosaurus = 75917254456602,
        Baryonyx = 117727284453994,
        Spinosaurus = 97925777024059,
        Pachycephalosaurus = 99220922747784,
        Ankylosaurus = 74087371517627,
        Triceratops = 80048859889830,
        Cryolophosaurus = 97659964731129,
        Therizinosaurus = 109355777925933,
        Brachiosaurus = 139698062396202,
        Carnotaurus = 83846600915891,
        Giganotosaurus = 115556602917589,
        TRex = 96481650609872,
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
        Compy = 134169444682833,
        Velociraptor = 126605374000454,
        Parasaurolophus = 108181033958707,
        Dilophosaurus = 118092053094630,
        Baryonyx = 100726847136467,
        Spinosaurus = 140016482712117,
        Pachycephalosaurus = 127521791130391,
        Ankylosaurus = 95493409847912,
        Triceratops = 93795548833941,
        Cryolophosaurus = 117724001183925,
        Therizinosaurus = 101136339215022,
        Brachiosaurus = 99376331130817,
        Carnotaurus = 130283684404995,
        Giganotosaurus = 110040162228560,
        TRex = 103587251575983,
        -- Shop items
        SlingshotItem = 99032474657018,
        Bait_Berries = 96598653687184,
        Bait_Fish = 84706401426083,
        Bait_Steak = 122289660973681,
        Bait_GoldenEgg = 140339826667206,
        Bait_AmberMosquito = 81487227930950,
        Bait_MeteorMeat = 97852309002124,
        -- HUD / pass / product icons (outlined toon renders, Assets/Blender/scripts/icons.py)
        Icon_Bag = 98602693971885,
        Icon_Book = 98278404588713,
        Icon_Cash = 121100110999666,
        Icon_Crown = 107846158388952,
        Icon_DoubleCash = 87923111761619,
        Icon_DoublePower = 79046801508353,
        Icon_Gear = 101171407989556,
        Icon_Gift = 119240055714099,
        Icon_Meteor = 111530885556560,
        Icon_Muscle = 78413149196094,
        Icon_Potion = 95608064290941,
        Icon_Power = 112028159200665,
        Icon_Star = 88844767322558,
        Icon_Target = 77218155705653,
        Icon_Vault = 139686365495000,
        Icon_Wrench = 106638791128750,
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
    },
}
