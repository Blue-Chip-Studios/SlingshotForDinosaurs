--!strict
--[[
    DinoConfig
    ----------
    Biomes, species, size and mutation tables. Species are listed per biome in
    rarity order (Common, Rare, Legendary). Archetype picks the model rig.
    Distances are displayed meters; CanyonMath maps them onto the world.
]]

export type Biome = {
    Id: string,
    Name: string,
    MinMeters: number,
    Color: Color3,
    Species: { string },
}

export type Species = {
    Id: string,
    Name: string,
    Biome: string,
    Rarity: string,
    Income: number, -- base cash per second
    Archetype: string, -- "Theropod" | "Quadruped" | "Sauropod" | "Ornithopod" | "Small" | "Flyer"
    Colors: { Body: Color3, Belly: Color3, Accent: Color3 },
    Height: number, -- studs at Normal size
}

-- Ten areas in one straight canyon. MinMeters are the distance gates (see Docs/DECISIONS.md #63):
-- tuned with a progression simulator so a first run reaches the Volcano in ~1h40 and Sky Islands in ~2h30.
local Biomes: { Biome } = {
    { Id = "Jungle", Name = "Jungle", MinMeters = 0, Color = Color3.fromHex("2FB344"), Species = { "Compy", "Velociraptor", "Parasaurolophus" } },
    { Id = "Swamp", Name = "Swamp", MinMeters = 600, Color = Color3.fromHex("6B8E23"), Species = { "Dilophosaurus", "Baryonyx", "Spinosaurus" } },
    { Id = "TarPits", Name = "Tar Pits", MinMeters = 3000, Color = Color3.fromHex("3A2F2A"), Species = { "Pachycephalosaurus", "Ankylosaurus", "Triceratops" } },
    { Id = "Badlands", Name = "Desert Badlands", MinMeters = 9000, Color = Color3.fromHex("E0A050"), Species = { "Protoceratops", "Gallimimus", "Stegosaurus" } },
    { Id = "CoralCoast", Name = "Coral Coast", MinMeters = 25000, Color = Color3.fromHex("2EC4D6"), Species = { "Iguanodon", "Corythosaurus", "Ouranosaurus" } },
    { Id = "IceAge", Name = "Ice Age", MinMeters = 70000, Color = Color3.fromHex("5EC8F2"), Species = { "Cryolophosaurus", "Therizinosaurus", "Brachiosaurus" } },
    { Id = "Redwood", Name = "Redwood Forest", MinMeters = 180000, Color = Color3.fromHex("3E7A3A"), Species = { "Allosaurus", "Styracosaurus", "Diplodocus" } },
    { Id = "CrystalCaves", Name = "Crystal Caves", MinMeters = 450000, Color = Color3.fromHex("B266FF"), Species = { "Microraptor", "Kentrosaurus", "Amargasaurus" } },
    { Id = "Volcano", Name = "Volcano", MinMeters = 1100000, Color = Color3.fromHex("FF6A1A"), Species = { "Carnotaurus", "Giganotosaurus", "TRex" } },
    { Id = "SkyIslands", Name = "Sky Islands", MinMeters = 2600000, Color = Color3.fromHex("9FD8FF"), Species = { "Pteranodon", "Archaeopteryx", "Quetzalcoatlus" } },
}

local MaxMeters = 6000000 -- deep into Sky Islands; distance past an area's gate adds catch luck

local RarityWeights = {
    Common = 70,
    Rare = 25,
    Legendary = 5,
}
local RarityOrder = { "Common", "Rare", "Legendary" }

local function c(hex: string): Color3
    return Color3.fromHex(hex)
end

-- Income per area (Common) grows x5 per area: 1, 5, 25, 120, 600, 3000, 15000, 75000, 400000, 2000000.
-- Rare = x3 and Legendary = x10 of their area's Common.
local function S(sId: string, sName: string, sBiome: string, sRarity: string, nIncome: number, sArch: string, nHeight: number, sBody: string, sBelly: string, sAccent: string): Species
    return { Id = sId, Name = sName, Biome = sBiome, Rarity = sRarity, Income = nIncome, Archetype = sArch, Height = nHeight,
        Colors = { Body = c(sBody), Belly = c(sBelly), Accent = c(sAccent) } }
end

local Species: { [string]: Species } = {
    Compy = S("Compy", "Compy", "Jungle", "Common", 1, "Small", 2.5, "7ED957", "E8F7C8", "3E8E2F"),
    Velociraptor = S("Velociraptor", "Velociraptor", "Jungle", "Rare", 3, "Theropod", 4, "D9893B", "F7E2C1", "7A3E12"),
    Parasaurolophus = S("Parasaurolophus", "Parasaurolophus", "Jungle", "Legendary", 10, "Ornithopod", 7, "4FB3A9", "E3F5EC", "E8542F"),

    Dilophosaurus = S("Dilophosaurus", "Dilophosaurus", "Swamp", "Common", 5, "Theropod", 5, "A3C14A", "F3F0C8", "E64A8B"),
    Baryonyx = S("Baryonyx", "Baryonyx", "Swamp", "Rare", 15, "Theropod", 6.5, "5E8C6A", "E6E1C5", "2F4A3A"),
    Spinosaurus = S("Spinosaurus", "Spinosaurus", "Swamp", "Legendary", 50, "Theropod", 9, "4A7D8C", "DDE9E0", "E8A33D"),

    Pachycephalosaurus = S("Pachycephalosaurus", "Pachycephalosaurus", "TarPits", "Common", 25, "Ornithopod", 5.5, "B07A4F", "EFD9BF", "5C3A22"),
    Ankylosaurus = S("Ankylosaurus", "Ankylosaurus", "TarPits", "Rare", 75, "Quadruped", 5, "8C7A5B", "D9CDB0", "3E3426"),
    Triceratops = S("Triceratops", "Triceratops", "TarPits", "Legendary", 250, "Quadruped", 7, "6A8FBF", "E0E8F2", "F2C14E"),

    Protoceratops = S("Protoceratops", "Protoceratops", "Badlands", "Common", 120, "Quadruped", 3.5, "D9A066", "F7E6CC", "8C4A2F"),
    Gallimimus = S("Gallimimus", "Gallimimus", "Badlands", "Rare", 360, "Theropod", 5, "E8C15A", "FFF5D6", "B5651D"),
    Stegosaurus = S("Stegosaurus", "Stegosaurus", "Badlands", "Legendary", 1200, "Quadruped", 7, "7FA35A", "E9F0D0", "E0663A"),

    Iguanodon = S("Iguanodon", "Iguanodon", "CoralCoast", "Common", 600, "Ornithopod", 6, "5BA3C9", "E6F4FA", "F2D65E"),
    Corythosaurus = S("Corythosaurus", "Corythosaurus", "CoralCoast", "Rare", 1800, "Ornithopod", 6.5, "F2856B", "FFE9DE", "3AC2B5"),
    Ouranosaurus = S("Ouranosaurus", "Ouranosaurus", "CoralCoast", "Legendary", 6000, "Ornithopod", 7, "2EB8A6", "E2FAF5", "FF7AB8"),

    Cryolophosaurus = S("Cryolophosaurus", "Cryolophosaurus", "IceAge", "Common", 3000, "Theropod", 6, "E8EEF5", "FFFFFF", "3F8FD9"),
    Therizinosaurus = S("Therizinosaurus", "Therizinosaurus", "IceAge", "Rare", 9000, "Theropod", 9, "C9B79C", "F5EEE2", "6E5A45"),
    Brachiosaurus = S("Brachiosaurus", "Brachiosaurus", "IceAge", "Legendary", 30000, "Sauropod", 16, "8FB8C9", "E6F2F7", "4A6E80"),

    Allosaurus = S("Allosaurus", "Allosaurus", "Redwood", "Common", 15000, "Theropod", 9, "A0522D", "F2D9C4", "3B2414"),
    Styracosaurus = S("Styracosaurus", "Styracosaurus", "Redwood", "Rare", 45000, "Quadruped", 7, "6B8E3A", "E8EFD2", "D94A2B"),
    Diplodocus = S("Diplodocus", "Diplodocus", "Redwood", "Legendary", 150000, "Sauropod", 14, "8A7B6A", "EDE4D6", "4F6B3A"),

    Microraptor = S("Microraptor", "Microraptor", "CrystalCaves", "Common", 75000, "Small", 2.8, "3A3F7A", "B9C2FF", "45E0FF"),
    Kentrosaurus = S("Kentrosaurus", "Kentrosaurus", "CrystalCaves", "Rare", 225000, "Quadruped", 5.5, "7A5CC9", "E6DEFF", "FF5ED1"),
    Amargasaurus = S("Amargasaurus", "Amargasaurus", "CrystalCaves", "Legendary", 750000, "Sauropod", 10, "4BA6A0", "DDF5F2", "C27BFF"),

    Carnotaurus = S("Carnotaurus", "Carnotaurus", "Volcano", "Common", 400000, "Theropod", 8, "B8402E", "F2C9A8", "2A1A16"),
    Giganotosaurus = S("Giganotosaurus", "Giganotosaurus", "Volcano", "Rare", 1200000, "Theropod", 11, "6B5A4E", "E0C9AE", "FF6A1A"),
    TRex = S("TRex", "T-Rex", "Volcano", "Legendary", 4000000, "Theropod", 12, "4E6B3A", "D8D2A8", "A83A1E"),

    Pteranodon = S("Pteranodon", "Pteranodon", "SkyIslands", "Common", 2000000, "Flyer", 5, "F2A65A", "FFF1E0", "D94F70"),
    Archaeopteryx = S("Archaeopteryx", "Archaeopteryx", "SkyIslands", "Rare", 6000000, "Flyer", 3.2, "3FA0E0", "F4FAFF", "F5C542"),
    Quetzalcoatlus = S("Quetzalcoatlus", "Quetzalcoatlus", "SkyIslands", "Legendary", 20000000, "Flyer", 10, "E8E2D0", "FFFFFF", "E0503A"),
}

-- Size roll. "Default" sizes share the leftover probability; luck only
-- improves the non-default (bigger) outcomes.
local Sizes = {
    { Id = "Tiny", Name = "Tiny", Chance = 0.35, Scale = 0.6, Cash = 0.5, Default = true },
    { Id = "Normal", Name = "Normal", Chance = 0.45, Scale = 1.0, Cash = 1, Default = true },
    { Id = "Big", Name = "Big", Chance = 0.14, Scale = 1.35, Cash = 2 },
    { Id = "Huge", Name = "Huge", Chance = 0.05, Scale = 1.75, Cash = 5 },
    { Id = "Colossal", Name = "Colossal", Chance = 0.01, Scale = 2.5, Cash = 15 },
}

local Mutations = {
    { Id = "Normal", Name = "Normal", Chance = 0.85, Cash = 1, Default = true, Color = c("FFFFFF") },
    { Id = "Golden", Name = "Golden", Chance = 0.08, Cash = 3, Color = c("FFC531") },
    { Id = "Frost", Name = "Frost", Chance = 0.04, Cash = 5, Color = c("9FE3FF") },
    { Id = "Magma", Name = "Magma", Chance = 0.02, Cash = 8, Color = c("FF4D1A") },
    { Id = "Toxic", Name = "Toxic", Chance = 0.009, Cash = 12, Color = c("9BE22D") },
    { Id = "Cosmic", Name = "Cosmic", Chance = 0.001, Cash = 25, Color = c("8E44FF") },
}

local function find(tList: { any }, sId: string): any
    for _, t in tList do
        if t.Id == sId then
            return t
        end
    end
    return nil
end

local function GetBiomeIndex(nMeters: number): number
    local iBiome = 1
    for i, tBiome in Biomes do
        if nMeters >= tBiome.MinMeters then
            iBiome = i
        end
    end
    return iBiome
end

return {
    Biomes = Biomes,
    MaxMeters = MaxMeters,
    Species = Species,
    RarityWeights = RarityWeights,
    RarityOrder = RarityOrder,
    Sizes = Sizes,
    Mutations = Mutations,
    GetSize = function(sId: string) return find(Sizes, sId) end,
    GetMutation = function(sId: string) return find(Mutations, sId) end,
    GetBiomeIndex = GetBiomeIndex,
    GetBiome = function(nMeters: number): Biome return Biomes[GetBiomeIndex(nMeters)] end,
    -- Cash per second for one dino entry (before passes).
    GetIncome = function(tDino: { Species: string, Size: string, Mutation: string }): number
        local tSpecies = Species[tDino.Species]
        local tSize = find(Sizes, tDino.Size)
        local tMut = find(Mutations, tDino.Mutation)
        if not (tSpecies and tSize and tMut) then
            return 0
        end
        return tSpecies.Income * tSize.Cash * tMut.Cash
    end,
}
