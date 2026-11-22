--[[
    MusicController
    ---------------
    Shuffled background playlist (Config/MusicConfig), crossfading to the
    Storm track while a weather event runs. Respects the MusicOff setting.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Module = require(ReplicatedStorage.Shared.Module)
local MusicConfig = require(ReplicatedStorage.Config.MusicConfig)
local DataClient = require(ReplicatedStorage.ClientModules.DataClient)

local oMain: Sound, oStorm: Sound
local bMuted = false
local tOrder: { number } = {}
local iIndex = 0

local function Fade(o: Sound, nTarget: number)
    if nTarget > 0 and not o.IsPlaying then o:Play() end
    local oTween = TweenService:Create(o, TweenInfo.new(MusicConfig.FadeSeconds), { Volume = nTarget })
    oTween:Play()
    if nTarget == 0 then
        oTween.Completed:Once(function()
            if o.Volume == 0 then o:Pause() end
        end)
    end
end

local function NextTrack()
    iIndex += 1
    if iIndex > #tOrder then
        tOrder = table.clone(MusicConfig.Main)
        for i = #tOrder, 2, -1 do
            local j = math.random(i)
            tOrder[i], tOrder[j] = tOrder[j], tOrder[i]
        end
        iIndex = 1
    end
    oMain.SoundId = "rbxassetid://" .. tOrder[iIndex]
    oMain.TimePosition = 0
end

local function Refresh()
    local bStorm = (Workspace:GetAttribute("Weather") or "Clear") ~= "Clear"
    if bMuted then
        Fade(oMain, 0)
        Fade(oStorm, 0)
    elseif bStorm then
        Fade(oMain, 0)
        Fade(oStorm, MusicConfig.Volume)
    else
        Fade(oStorm, 0)
        Fade(oMain, MusicConfig.Volume)
    end
end

local mMusic = Module()

function mMusic.StartAsync(self)
    local oGroup = Instance.new("SoundGroup")
    oGroup.Name = "Music"
    oGroup.Parent = SoundService

    oMain = Instance.new("Sound")
    oMain.Name = "MusicMain"
    oMain.Volume = 0
    oMain.SoundGroup = oGroup
    oMain.Parent = SoundService
    oMain.Ended:Connect(function()
        NextTrack()
        if not bMuted then oMain:Play() end
    end)

    oStorm = Instance.new("Sound")
    oStorm.Name = "MusicStorm"
    oStorm.SoundId = "rbxassetid://" .. MusicConfig.Storm
    oStorm.Looped = true
    oStorm.Volume = 0
    oStorm.SoundGroup = oGroup
    oStorm.Parent = SoundService

    NextTrack()
    local function ReadSetting(t)
        bMuted = typeof(t) == "table" and t.MusicOff == true
        Refresh()
    end
    DataClient:Changed("Settings", ReadSetting)
    ReadSetting(DataClient:Get("Settings"))
    Workspace:GetAttributeChangedSignal("Weather"):Connect(Refresh)
end

return mMusic
