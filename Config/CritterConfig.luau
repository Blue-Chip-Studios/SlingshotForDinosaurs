--!strict
--[[
    CritterConfig
    -------------
    Ambient wildlife on the canyon floor (WildlifeController, client-only and purely visual).

    Every area gets a few of its own catchable dinos wandering about: herbivores stop to graze,
    hunters sniff around and now and then rear up and roar, flyers circle overhead. Some areas
    also get themed non-dino critters (plush models from Assets/Blender/scripts/critters.py,
    AssetConfig.Critters), e.g. a herd of woolly mammoths plodding through the Ice Age.

    Critters:
        Height   studs (bounding box)
        Speed    walk speed, studs/s
        Grazes   stops to eat grass (head down, chewing)
        Flies    "Dart" (hover and zip about low) | nil
        Herd     members share one destination and walk together
        Water    may wander into water and swim (Coral Coast lagoon)
]]

local CritterConfig = {}

CritterConfig.Critters = {
    Mammoth = { Name = "Woolly Mammoth", Height = 10, Speed = 4.5, Grazes = true, Herd = true,
        Colors = { Body = Color3.fromHex("B88A63"), Belly = Color3.fromHex("EAD7BE"), Accent = Color3.fromHex("6E4A30") } },
    SabreTooth = { Name = "Sabre-Tooth Cat", Height = 4.6, Speed = 7,
        Colors = { Body = Color3.fromHex("E8B470"), Belly = Color3.fromHex("FFF2DC"), Accent = Color3.fromHex("A8683A") } },
    SeaTurtle = { Name = "Sea Turtle", Height = 2.6, Speed = 2.2, Grazes = true, Water = true,
        Colors = { Body = Color3.fromHex("8FD89A"), Belly = Color3.fromHex("F6E9B8"), Accent = Color3.fromHex("4FAE7A") } },
    Dragonfly = { Name = "Giant Dragonfly", Height = 1.6, Speed = 16, Flies = "Dart",
        Colors = { Body = Color3.fromHex("4DB5EE"), Belly = Color3.fromHex("E8F6FF"), Accent = Color3.fromHex("2A6FC0") } },
}

-- Per area (DinoConfig.Biomes Id): how many of the area's own dinos roam (spread over its three
-- species; big sauropods count double) and which critters join them.
CritterConfig.Areas = {
    Jungle = { Dinos = 11, Critters = { Dragonfly = 5 } },
    Swamp = { Dinos = 11, Critters = { Dragonfly = 7 } },
    TarPits = { Dinos = 11, Critters = { SabreTooth = 4 } },
    Badlands = { Dinos = 12 },
    CoralCoast = { Dinos = 10, Critters = { SeaTurtle = 6 } },
    IceAge = { Dinos = 9, Critters = { Mammoth = 5 } },
    Redwood = { Dinos = 11 },
    CrystalCaves = { Dinos = 11 },
    Volcano = { Dinos = 11 },
    SkyIslands = { Dinos = 10 },
}

-- Dino archetypes that graze (everything else hunts: sniffs about and roars now and then).
CritterConfig.GrazingArchetypes = { Quadruped = true, Sauropod = true, Ornithopod = true }
CritterConfig.GrazingSpecies = { Gallimimus = true, Therizinosaurus = true }

-- Wild animals are shown much bigger than park dinos so they read from the rim and during flights.
CritterConfig.DinoScale = 2.6
CritterConfig.MinDinoHeight = 14 -- small species (Compy, raptors) grow more so every wild dino reads from the rim
CritterConfig.CritterScale = 1.7

CritterConfig.ActiveRange = 380   -- an area wakes up when the camera is this close to it (studs)
CritterConfig.DetailRange = 240   -- beyond this, animals update at a quarter rate
CritterConfig.MutantChance = 0.03 -- the odd Golden / Frost / Cosmic wanderer, for players to spot

return CritterConfig
