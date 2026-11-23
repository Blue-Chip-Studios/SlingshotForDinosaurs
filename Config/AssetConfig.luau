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
        Compy = 123206835468913, -- plush r2
        Velociraptor = 138620119120300, -- plush r2
        Parasaurolophus = 95083055492476, -- plush r2
        Dilophosaurus = 106940721961711, -- plush r2
        Baryonyx = 103418822118906, -- plush r2
        Spinosaurus = 130907035368001, -- plush r2
        Pachycephalosaurus = 128623443200143, -- plush r2
        Ankylosaurus = 96445736797625, -- plush r2
        Triceratops = 109907411392092, -- plush r2
        Cryolophosaurus = 88362714535086, -- plush r2
        Therizinosaurus = 136767771614615, -- plush r2
        Brachiosaurus = 96505991308240, -- plush r2
        Carnotaurus = 110090728963471, -- plush r2
        Giganotosaurus = 98956910259103, -- plush r2
        TRex = 111462761109397, -- plush r2
        Protoceratops = 86482998597490, -- plush r2
        Gallimimus = 79158093183311, -- plush r2
        Stegosaurus = 90239752283375, -- plush r2
        Iguanodon = 128326394595203, -- plush r2
        Corythosaurus = 124795688371995, -- plush r2
        Ouranosaurus = 118471787589572, -- plush r2
        Allosaurus = 90983560640028, -- plush r2
        Styracosaurus = 119524864877582, -- plush r2
        Diplodocus = 115187685388958, -- plush r2
        Microraptor = 99791479812714, -- plush r2
        Kentrosaurus = 96285161709960, -- plush r2
        Amargasaurus = 131493747364578, -- plush r2
        Pteranodon = 94994397236759, -- plush r2
        Archaeopteryx = 97641336750077, -- plush r2
        Quetzalcoatlus = 138489338744086, -- plush r2
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
        Compy = 119775186679836,
        Velociraptor = 71749359708485,
        Parasaurolophus = 130885786220736,
        Dilophosaurus = 70889648873275,
        Baryonyx = 83958666527032,
        Spinosaurus = 90046904754345,
        Pachycephalosaurus = 86498759767483,
        Ankylosaurus = 74436767637258,
        Triceratops = 118790345273174,
        Cryolophosaurus = 89193028221511,
        Therizinosaurus = 121518219252564,
        Brachiosaurus = 108791839936642,
        Carnotaurus = 131776345091404,
        Giganotosaurus = 108826736558728,
        TRex = 85623350479464,
        Protoceratops = 82856324913810,
        Gallimimus = 80847039072267,
        Stegosaurus = 80152208841021,
        Iguanodon = 102254397024648,
        Corythosaurus = 126789985399012,
        Ouranosaurus = 95647441271870,
        Allosaurus = 76261960120967,
        Styracosaurus = 82366207000488,
        Diplodocus = 85728916193480,
        Microraptor = 99774276718884,
        Kentrosaurus = 123526553738654,
        Amargasaurus = 75193690275350,
        Pteranodon = 103264561547993,
        Archaeopteryx = 71234751622046,
        Quetzalcoatlus = 100858333054384,
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
