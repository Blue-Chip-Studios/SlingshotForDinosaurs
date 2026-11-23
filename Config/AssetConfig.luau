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
        Compy = 96176021548533, -- v7 (split head / jaw / tail)
        Velociraptor = 83849622134660, -- v7 (split head / jaw / tail)
        Parasaurolophus = 100323812443752, -- v7 (split head / jaw / tail)
        Dilophosaurus = 107792734637786, -- v7 (split head / jaw / tail)
        Baryonyx = 140110573545911, -- v7 (split head / jaw / tail)
        Spinosaurus = 74792799411980, -- v7 (split head / jaw / tail)
        Pachycephalosaurus = 87909488562632, -- v7 (split head / jaw / tail)
        Ankylosaurus = 124863246785583, -- v7 (split head / jaw / tail)
        Triceratops = 140298623344723, -- v7 (split head / jaw / tail)
        Cryolophosaurus = 115629973545362, -- v7 (split head / jaw / tail)
        Therizinosaurus = 81255598468027, -- v7 (split head / jaw / tail)
        Brachiosaurus = 132903634665251, -- v7 (split head / jaw / tail)
        Carnotaurus = 94760700922037, -- v7 (split head / jaw / tail)
        Giganotosaurus = 119121554642058, -- v7 (split head / jaw / tail)
        TRex = 138317218814010, -- v7 (split head / jaw / tail)
        Protoceratops = 83610015280670, -- v7 (split head / jaw / tail)
        Gallimimus = 88541733137652, -- v7 (split head / jaw / tail)
        Stegosaurus = 98923249239430, -- v7 (split head / jaw / tail)
        Iguanodon = 136887929318957, -- v7 (split head / jaw / tail)
        Corythosaurus = 113674981370038, -- v7 (split head / jaw / tail)
        Ouranosaurus = 113786379917731, -- v7 (split head / jaw / tail)
        Allosaurus = 87419287582717, -- v7 (split head / jaw / tail)
        Styracosaurus = 127220441381170, -- v7 (split head / jaw / tail)
        Diplodocus = 114304046969788, -- v7 (split head / jaw / tail)
        Microraptor = 123423459139230, -- v7 (split head / jaw / tail)
        Kentrosaurus = 74487861058264, -- v7 (split head / jaw / tail)
        Amargasaurus = 135045752290403, -- v7 (split head / jaw / tail)
        Pteranodon = 82112852904836, -- v7 (split head / jaw / tail)
        Archaeopteryx = 125046402839501, -- v7 (split head / jaw / tail)
        Quetzalcoatlus = 73372566089137, -- v7 (split head / jaw / tail)
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
        Compy = 128196018352921,
        Velociraptor = 88660681923433,
        Parasaurolophus = 73988936852385,
        Dilophosaurus = 75135177504733,
        Baryonyx = 134699871425686,
        Spinosaurus = 138244881667978,
        Pachycephalosaurus = 123501992441033,
        Ankylosaurus = 70865695391659,
        Triceratops = 114265819575656,
        Cryolophosaurus = 118627506599486,
        Therizinosaurus = 103821539356342,
        Brachiosaurus = 90673553482533,
        Carnotaurus = 96123925354784,
        Giganotosaurus = 135304581877576,
        TRex = 109788542590506,
        Protoceratops = 112768364412263,
        Gallimimus = 96301235494654,
        Stegosaurus = 100997959794511,
        Iguanodon = 76227710934203,
        Corythosaurus = 134067578059017,
        Ouranosaurus = 140159657085568,
        Allosaurus = 90965721875133,
        Styracosaurus = 133213078257962,
        Diplodocus = 113124469322735,
        Microraptor = 113931666018735,
        Kentrosaurus = 135077094675129,
        Amargasaurus = 122345651269010,
        Pteranodon = 138738360293701,
        Archaeopteryx = 77442181479513,
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
