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
    Archetype: string, -- "Theropod" | "Quadruped" | "Sauropod" | "Ornithopod" | "Small"
    Colors: { Body: Color3, Belly: Color3, Accent: Color3 },
    Height: number, -- studs at Normal size
}

local Biomes: { Biome } = {
    { Id = "Jungle", Name = "Jungle", MinMeters = 0, Color = Color3.fromHex("2FB344"), Species = { "Compy", "Velociraptor", "Parasaurolophus" } },
    { Id = "Swamp", Name = "Swamp", MinMeters = 150, Color = Color3.fromHex("6B8E23"), Species = { "Dilophosaurus", "Baryonyx", "Spinosaurus" } },
    { Id = "TarPits", Name = "Tar Pits", MinMeters = 1000, Color = Color3.fromHex("3A2F2A"), Species = { "Pachycephalosaurus", "Ankylosaurus", "Triceratops" } },
    { Id = "IceAge", Name = "Ice Age", MinMeters = 8000, Color = Color3.fromHex("5EC8F2"), Species = { "Cryolophosaurus", "Therizinosaurus", "Brachiosaurus" } },
    { Id = "Volcano", Name = "Volcano", MinMeters = 60000, Color = Color3.fromHex("FF6A1A"), Species = { "Carnotaurus", "Giganotosaurus", "TRex" } },
}

local MaxMeters = 500000

local RarityWeights = {
    Common = 70,
    Rare = 25,
    Legendary = 5,
}
local RarityOrder = { "Common", "Rare", "Legendary" }

local function c(hex: string): Color3
    return Color3.fromHex(hex)
end

local Species: { [string]: Species } = {
    Compy = { Id = "Compy", Name = "Compy", Biome = "Jungle", Rarity = "Common", Income = 1, Archetype = "Small", Height = 2.5,
        Colors = { Body = c("7ED957"), Belly = c("E8F7C8"), Accent = c("3E8E2F") } },
    Velociraptor = { Id = "Velociraptor", Name = "Velociraptor", Biome = "Jungle", Rarity = "Rare", Income = 3, Archetype = "Theropod", Height = 4,
        Colors = { Body = c("D9893B"), Belly = c("F7E2C1"), Accent = c("7A3E12") } },
    Parasaurolophus = { Id = "Parasaurolophus", Name = "Parasaurolophus", Biome = "Jungle", Rarity = "Legendary", Income = 10, Archetype = "Ornithopod", Height = 7,
        Colors = { Body = c("4FB3A9"), Belly = c("E3F5EC"), Accent = c("E8542F") } },

    Dilophosaurus = { Id = "Dilophosaurus", Name = "Dilophosaurus", Biome = "Swamp", Rarity = "Common", Income = 25, Archetype = "Theropod", Height = 5,
        Colors = { Body = c("A3C14A"), Belly = c("F3F0C8"), Accent = c("E64A8B") } },
    Baryonyx = { Id = "Baryonyx", Name = "Baryonyx", Biome = "Swamp", Rarity = "Rare", Income = 80, Archetype = "Theropod", Height = 6.5,
        Colors = { Body = c("5E8C6A"), Belly = c("E6E1C5"), Accent = c("2F4A3A") } },
    Spinosaurus = { Id = "Spinosaurus", Name = "Spinosaurus", Biome = "Swamp", Rarity = "Legendary", Income = 250, Archetype = "Theropod", Height = 9,
        Colors = { Body = c("4A7D8C"), Belly = c("DDE9E0"), Accent = c("E8A33D") } },

    Pachycephalosaurus = { Id = "Pachycephalosaurus", Name = "Pachycephalosaurus", Biome = "TarPits", Rarity = "Common", Income = 600, Archetype = "Ornithopod", Height = 5.5,
        Colors = { Body = c("B07A4F"), Belly = c("EFD9BF"), Accent = c("5C3A22") } },
    Ankylosaurus = { Id = "Ankylosaurus", Name = "Ankylosaurus", Biome = "TarPits", Rarity = "Rare", Income = 2000, Archetype = "Quadruped", Height = 5,
        Colors = { Body = c("8C7A5B"), Belly = c("D9CDB0"), Accent = c("3E3426") } },
    Triceratops = { Id = "Triceratops", Name = "Triceratops", Biome = "TarPits", Rarity = "Legendary", Income = 6000, Archetype = "Quadruped", Height = 7,
        Colors = { Body = c("6A8FBF"), Belly = c("E0E8F2"), Accent = c("F2C14E") } },

    Cryolophosaurus = { Id = "Cryolophosaurus", Name = "Cryolophosaurus", Biome = "IceAge", Rarity = "Common", Income = 15000, Archetype = "Theropod", Height = 6,
        Colors = { Body = c("E8EEF5"), Belly = c("FFFFFF"), Accent = c("3F8FD9") } },
    Therizinosaurus = { Id = "Therizinosaurus", Name = "Therizinosaurus", Biome = "IceAge", Rarity = "Rare", Income = 50000, Archetype = "Theropod", Height = 9,
        Colors = { Body = c("C9B79C"), Belly = c("F5EEE2"), Accent = c("6E5A45") } },
    Brachiosaurus = { Id = "Brachiosaurus", Name = "Brachiosaurus", Biome = "IceAge", Rarity = "Legendary", Income = 150000, Archetype = "Sauropod", Height = 16,
        Colors = { Body = c("8FB8C9"), Belly = c("E6F2F7"), Accent = c("4A6E80") } },

    Carnotaurus = { Id = "Carnotaurus", Name = "Carnotaurus", Biome = "Volcano", Rarity = "Common", Income = 400000, Archetype = "Theropod", Height = 8,
        Colors = { Body = c("B8402E"), Belly = c("F2C9A8"), Accent = c("2A1A16") } },
    Giganotosaurus = { Id = "Giganotosaurus", Name = "Giganotosaurus", Biome = "Volcano", Rarity = "Rare", Income = 1300000, Archetype = "Theropod", Height = 11,
        Colors = { Body = c("6B5A4E"), Belly = c("E0C9AE"), Accent = c("FF6A1A") } },
    TRex = { Id = "TRex", Name = "T-Rex", Biome = "Volcano", Rarity = "Legendary", Income = 4000000, Archetype = "Theropod", Height = 12,
        Colors = { Body = c("4E6B3A"), Belly = c("D8D2A8"), Accent = c("A83A1E") } },
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
