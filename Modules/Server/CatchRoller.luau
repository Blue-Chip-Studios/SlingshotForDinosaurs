--!strict
--[[
    CatchRoller
    -----------
    Pure server-side rolls for species, size and mutation. Not a lifecycle
    module (the Loader skips it because it has no hooks).

    Luck: every non-default outcome's chance becomes p' = 1 - (1 - p)^luck,
    so luck scales rare outcomes smoothly and never exceeds 100%. Defaults
    (Common species, Tiny/Normal size, Normal mutation) share what is left.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DinoConfig = require(ReplicatedStorage.Config.DinoConfig)

local CatchRoller = {}

local oRandom = Random.new()

local function Lucky(p: number, nLuck: number): number
    return 1 - (1 - math.clamp(p, 0, 1)) ^ math.max(nLuck, 0)
end

-- tOptions: { Id, Chance, Default? }[]. Returns the chosen Id.
local function Pick(tOptions: { any }, nLuck: number, tMultipliers: { [string]: number }?): string
    local tLucky = {}
    local nLuckyTotal = 0
    local nDefaultBase = 0
    for _, t in tOptions do
        if t.Default then
            nDefaultBase += t.Chance
        else
            local p = Lucky(t.Chance * ((tMultipliers and tMultipliers[t.Id]) or 1), nLuck)
            tLucky[t.Id] = p
            nLuckyTotal += p
        end
    end
    -- If luck pushes rares past 100%, normalise them and leave no room for defaults.
    local nScale = if nLuckyTotal > 1 then 1 / nLuckyTotal else 1
    local nDefaultShare = math.max(0, 1 - nLuckyTotal * nScale)
    local nRoll = oRandom:NextNumber()
    -- Rarest first so ties favour the exciting outcome.
    for i = #tOptions, 1, -1 do
        local t = tOptions[i]
        local p = if t.Default then nDefaultShare * (t.Chance / nDefaultBase) else tLucky[t.Id] * nScale
        if nRoll < p then
            return t.Id
        end
        nRoll -= p
    end
    for _, t in tOptions do
        if t.Default then
            return t.Id
        end
    end
    return tOptions[1].Id
end

function CatchRoller.RollSpecies(sBiomeId: string, nLuck: number, bForceLegendary: boolean?): string
    local tBiome
    for _, t in DinoConfig.Biomes do
        if t.Id == sBiomeId then
            tBiome = t
        end
    end
    assert(tBiome, "unknown biome " .. sBiomeId)
    if bForceLegendary then
        return tBiome.Species[3]
    end
    local tOptions = {
        { Id = tBiome.Species[1], Chance = DinoConfig.RarityWeights.Common / 100, Default = true },
        { Id = tBiome.Species[2], Chance = DinoConfig.RarityWeights.Rare / 100 },
        { Id = tBiome.Species[3], Chance = DinoConfig.RarityWeights.Legendary / 100 },
    }
    return Pick(tOptions, nLuck)
end

function CatchRoller.RollSize(nLuck: number): string
    return Pick(DinoConfig.Sizes, nLuck)
end

function CatchRoller.RollMutation(nLuck: number, tEventMultipliers: { [string]: number }?): string
    return Pick(DinoConfig.Mutations, nLuck, tEventMultipliers)
end

-- Odds table for display (reroll potion disclosure). Returns { {Id, Chance} } at the given luck.
function CatchRoller.MutationOdds(nLuck: number, tEventMultipliers: { [string]: number }?): { { Id: string, Chance: number } }
    local tOut = {}
    local nTotal = 0
    local nDefault = 0
    for _, t in DinoConfig.Mutations do
        if not t.Default then
            local p = Lucky(t.Chance * ((tEventMultipliers and tEventMultipliers[t.Id]) or 1), nLuck)
            nTotal += p
            table.insert(tOut, { Id = t.Id, Chance = p })
        end
    end
    local nScale = if nTotal > 1 then 1 / nTotal else 1
    for _, t in tOut do
        t.Chance *= nScale
    end
    nDefault = math.max(0, 1 - nTotal * nScale)
    table.insert(tOut, 1, { Id = "Normal", Chance = nDefault })
    return tOut
end

return CatchRoller
