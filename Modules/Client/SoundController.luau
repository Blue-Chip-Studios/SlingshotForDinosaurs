--[[
    SoundController
    ---------------
    One place to play UI and gameplay sounds by name. Ids come from
    Config/AssetConfig.Sounds (ElevenLabs-generated, uploaded to the game's
    group). FALLBACK lists Roblox built-ins used only if a sound id is
    missing (e.g. still in moderation), so the game is never silent.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Module = require(ReplicatedStorage.Shared.Module)
local AssetConfig = require(ReplicatedStorage.Config.AssetConfig)

local SOUNDS = {
    Click = { Volume = 0.45 },
    Charge = { Volume = 0.4 },
    Launch = { Volume = 0.7 },
    Bounce = { Volume = 0.75 },
    Perfect = { Volume = 0.7 },
    Impact = { Volume = 0.6 },
    Reveal = { Volume = 0.7 },
    Coin = { Volume = 0.45 },
    Error = { Volume = 0.4 },
    Event = { Volume = 0.7 },
}

local FALLBACK = {
    Click = "rbxasset://sounds/electronicpingshort.wav",
    Bounce = "rbxasset://sounds/action_jump.mp3",
    Impact = "rbxasset://sounds/impact_water.mp3",
    Error = "rbxasset://sounds/uuhhh.mp3",
}

local tCache: { [string]: Sound } = {}

local mSound = Module()

function mSound.PreloadAsync(self)
    for sName, t in SOUNDS do
        local iId = AssetConfig.Sounds[sName]
        local sId = if iId then "rbxassetid://" .. iId else FALLBACK[sName]
        if sId then
            local o = Instance.new("Sound")
            o.Name = sName
            o.SoundId = sId
            o.Volume = t.Volume
            o.Parent = SoundService
            tCache[sName] = o
        end
    end
end

function mSound.StartAsync(self)
    -- Looping prehistoric ambience bed (stands in for music until a music track exists).
    local iId = AssetConfig.Sounds.Ambience
    if not iId then return end
    local o = Instance.new("Sound")
    o.Name = "Ambience"
    o.SoundId = "rbxassetid://" .. iId
    o.Looped = true
    o.Volume = 0.35
    o.Parent = SoundService
    o:Play()
end

-- Plays a named sound; nPitch optionally overrides playback speed (e.g. roar pitch by size).
function mSound.Play(self, sName: string, nPitch: number?)
    local o = tCache[sName]
    if not o then return end
    if nPitch then
        local oClone = o:Clone()
        oClone.PlaybackSpeed = nPitch
        oClone.Parent = SoundService
        oClone:Play()
        oClone.Ended:Once(function() oClone:Destroy() end)
        return
    end
    SoundService:PlayLocalSound(o)
end

return mSound
