--!strict
--[[
    CanyonMath
    ----------
    Shared, deterministic maths for the canyon and launches. The server and
    client both use it, so a flight the server plans is the flight the client
    draws.

    World layout (studs):
        Rim plateau top at RimY, canyon floor at FloorY.
        The canyon runs along -Z from CanyonStartZ; each biome is BiomeLength long.
    Displayed meters map piecewise onto the canyon (DECISIONS #4):
        Jungle linear 0-150 m, then every later biome logarithmic between its
        MinMeters and the next biome's MinMeters.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DinoConfig = require(ReplicatedStorage.Config.DinoConfig)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)

local CanyonMath = {}

CanyonMath.RimY = 60
CanyonMath.FloorY = 0
CanyonMath.CanyonStartZ = -70
CanyonMath.BiomeLength = 400
CanyonMath.CanyonHalfWidth = 180
CanyonMath.BiomeCount = #DinoConfig.Biomes
CanyonMath.CanyonEndZ = CanyonMath.CanyonStartZ - CanyonMath.BiomeLength * CanyonMath.BiomeCount

-- Distance along the canyon (studs from CanyonStartZ) for a meter value.
function CanyonMath.MetersToStuds(nMeters: number): number
    local tBiomes = DinoConfig.Biomes
    nMeters = math.clamp(nMeters, 0, DinoConfig.MaxMeters)
    local iBiome = DinoConfig.GetBiomeIndex(nMeters)
    local nLow = tBiomes[iBiome].MinMeters
    local nHigh = if iBiome < #tBiomes then tBiomes[iBiome + 1].MinMeters else DinoConfig.MaxMeters
    local nFraction
    if nLow <= 0 then
        nFraction = nMeters / nHigh
    else
        nFraction = math.log(nMeters / nLow) / math.log(nHigh / nLow)
    end
    nFraction = math.clamp(nFraction, 0, 0.999)
    return ((iBiome - 1) + nFraction) * CanyonMath.BiomeLength
end

-- Z coordinate where a launch of nMeters lands.
function CanyonMath.MetersToZ(nMeters: number): number
    return CanyonMath.CanyonStartZ - CanyonMath.MetersToStuds(nMeters)
end

-- Inverse: which displayed meter value sits at a given Z (used for the live distance readout).
function CanyonMath.ZToMeters(nZ: number): number
    local nStuds = math.max(0, CanyonMath.CanyonStartZ - nZ)
    local tBiomes = DinoConfig.Biomes
    local iBiome = math.clamp(math.floor(nStuds / CanyonMath.BiomeLength) + 1, 1, #tBiomes)
    local nFraction = math.clamp((nStuds - (iBiome - 1) * CanyonMath.BiomeLength) / CanyonMath.BiomeLength, 0, 1)
    local nLow = tBiomes[iBiome].MinMeters
    local nHigh = if iBiome < #tBiomes then tBiomes[iBiome + 1].MinMeters else DinoConfig.MaxMeters
    if nLow <= 0 then
        return nFraction * nHigh
    end
    return nLow * (nHigh / nLow) ^ nFraction
end

-- Landing position for a launch from vOrigin (aim offsets X, clamped inside the canyon walls).
function CanyonMath.LandingPoint(vOrigin: Vector3, nMeters: number, nAim: number): Vector3
    local nX = math.clamp(vOrigin.X * 0.6 + nAim * 60, -CanyonMath.CanyonHalfWidth + 20, CanyonMath.CanyonHalfWidth - 20)
    return Vector3.new(nX, CanyonMath.FloorY + 1.5, CanyonMath.MetersToZ(nMeters))
end

function CanyonMath.FlightTime(vFrom: Vector3, vTo: Vector3): number
    local nStuds = (vTo - vFrom).Magnitude
    return math.min(math.max(GameConfig.FlightBaseTime + nStuds * GameConfig.FlightTimePerStud,
        -- Three-geyser flights stretch a little (a floatier arc) so all three taps fit, readably spaced.
        if nStuds >= GameConfig.Bounce.ThreeBounceStuds then GameConfig.Bounce.ThreeBounceMinTime else 0), GameConfig.FlightMaxTime)
end

-- Parabolic arc from A to B, lifted nHeight above the straight line at its midpoint.
function CanyonMath.ArcPoint(vA: Vector3, vB: Vector3, nHeight: number, nAlpha: number): Vector3
    local vFlat = vA:Lerp(vB, nAlpha)
    return vFlat + Vector3.new(0, 4 * nHeight * nAlpha * (1 - nAlpha), 0)
end

function CanyonMath.ArcHeight(vA: Vector3, vB: Vector3): number
    return 25 + (vB - vA).Magnitude * 0.12
end

-- Deterministic bounce windows (seconds from launch) for a flight of nDuration.
function CanyonMath.BounceWindows(nSeed: number, nStuds: number, nDuration: number): { number }
    local oRandom = Random.new(nSeed)
    local nCount = if nStuds < 180 then 1 elseif nStuds < GameConfig.Bounce.ThreeBounceStuds then 2 else 3
    local nMaxFraction = GameConfig.Bounce.MaxWindowFraction
    -- Never squeeze geysers closer than MinGap: short flights get fewer of them instead.
    local nUsable = (nMaxFraction - 0.25) * nDuration
    nCount = math.max(1, math.min(nCount, math.floor(nUsable / GameConfig.Bounce.MinGap) + 1))
    -- Spread them out: MinGap between each, and the spare time shared randomly before, between and
    -- after them, so every geyser always fits inside the flight.
    local nGap = GameConfig.Bounce.MinGap
    local nFree = math.max(0, nUsable - (nCount - 1) * nGap)
    local tWeights, nSum = {}, 0
    for i = 1, nCount + 1 do
        tWeights[i] = oRandom:NextNumber(0.4, 1)
        nSum += tWeights[i]
    end
    local tWindows = {}
    local nT = 0.25 * nDuration
    for i = 1, nCount do
        nT += (if i > 1 then nGap else 0) + nFree * tWeights[i] / nSum
        table.insert(tWindows, nT)
    end
    return tWindows
end

-- Quality of a bounce tap given its error from the window time (seconds), or nil if missed.
function CanyonMath.BounceQuality(nError: number): string?
    local tBounce = GameConfig.Bounce
    local nAbs = math.abs(nError)
    if nAbs <= tBounce.Perfect.Window then
        return "Perfect"
    elseif nAbs <= tBounce.Good.Window then
        return "Good"
    elseif nAbs <= tBounce.OK.Window then
        return "OK"
    end
    return nil
end

return CanyonMath
