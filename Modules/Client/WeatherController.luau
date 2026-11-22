--[[
    WeatherController
    -----------------
    Client-side look of the world cycle: the Stylized lighting preset for
    clear skies, plus Meteor Storm (red sky, falling meteors) and Ice Age
    (cyan haze, snow). Purely cosmetic: reads Workspace.Weather.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Module = require(ReplicatedStorage.Shared.Module)
local CanyonMath = require(ReplicatedStorage.Shared.CanyonMath)

local PRESETS = {
    Clear = {
        Lighting = { ClockTime = 14.2, Brightness = 2.6, OutdoorAmbient = Color3.fromRGB(150, 140, 130), Ambient = Color3.fromRGB(90, 90, 100) },
        Atmosphere = { Density = 0.28, Haze = 1.2, Color = Color3.fromRGB(199, 225, 255), Decay = Color3.fromRGB(120, 170, 220), Glare = 0.2 },
        Color = { Saturation = 0.18, Contrast = 0.06, TintColor = Color3.fromRGB(255, 250, 240), Brightness = 0.02 },
    },
    MeteorStorm = {
        Lighting = { ClockTime = 17.6, Brightness = 2.0, OutdoorAmbient = Color3.fromRGB(150, 80, 60), Ambient = Color3.fromRGB(90, 50, 40) },
        Atmosphere = { Density = 0.38, Haze = 2.2, Color = Color3.fromRGB(255, 140, 100), Decay = Color3.fromRGB(120, 30, 20), Glare = 0.6 },
        Color = { Saturation = 0.25, Contrast = 0.12, TintColor = Color3.fromRGB(255, 205, 180), Brightness = 0 },
    },
    IceAge = {
        Lighting = { ClockTime = 12.5, Brightness = 2.4, OutdoorAmbient = Color3.fromRGB(150, 180, 210), Ambient = Color3.fromRGB(110, 130, 160) },
        Atmosphere = { Density = 0.45, Haze = 2.6, Color = Color3.fromRGB(220, 240, 255), Decay = Color3.fromRGB(170, 210, 240), Glare = 0.1 },
        Color = { Saturation = -0.05, Contrast = 0.04, TintColor = Color3.fromRGB(225, 240, 255), Brightness = 0.04 },
    },
}

local oAtmosphere: Atmosphere
local oColor: ColorCorrectionEffect
local oSnow: ParticleEmitter
local sCurrent = ""
local bMeteors = false

local function Ensure(sClass: string, sName: string): Instance
    local o = Lighting:FindFirstChild(sName)
    if not o then
        o = Instance.new(sClass)
        o.Name = sName
        o.Parent = Lighting
    end
    return o
end

local function Apply(sWeather: string)
    if sWeather == sCurrent then return end
    sCurrent = sWeather
    local t = PRESETS[sWeather] or PRESETS.Clear
    local tInfo = TweenInfo.new(3, Enum.EasingStyle.Sine)
    TweenService:Create(Lighting, tInfo, t.Lighting):Play()
    TweenService:Create(oAtmosphere, tInfo, t.Atmosphere):Play()
    TweenService:Create(oColor, tInfo, t.Color):Play()
    oSnow.Enabled = sWeather == "IceAge"
    bMeteors = sWeather == "MeteorStorm"
end

local function Meteor()
    local oCamera = Workspace.CurrentCamera
    local vBase = oCamera.CFrame.Position
    local vTarget = Vector3.new(math.random(-170, 170), CanyonMath.FloorY, vBase.Z - math.random(80, 600))
    local vStart = vTarget + Vector3.new(math.random(-60, 60), 260, 140)
    local oRock = Instance.new("Part")
    oRock.Shape = Enum.PartType.Ball
    oRock.Size = Vector3.one * math.random(4, 8)
    oRock.Material = Enum.Material.Neon
    oRock.Color = Color3.fromHex("FF6A1A")
    oRock.Anchored = true
    oRock.CanCollide = false
    oRock.CanQuery = false
    oRock.Position = vStart
    local a0 = Instance.new("Attachment", oRock)
    a0.Position = Vector3.new(0, 1, 0)
    local a1 = Instance.new("Attachment", oRock)
    a1.Position = Vector3.new(0, -1, 0)
    local oTrail = Instance.new("Trail")
    oTrail.Attachment0, oTrail.Attachment1 = a0, a1
    oTrail.Color = ColorSequence.new(Color3.fromHex("FFC531"), Color3.fromHex("FF4D1A"))
    oTrail.Lifetime = 0.5
    oTrail.LightEmission = 1
    oTrail.WidthScale = NumberSequence.new(3, 0)
    oTrail.Parent = oRock
    oRock.Parent = Workspace
    local oTween = TweenService:Create(oRock, TweenInfo.new(1.4, Enum.EasingStyle.Linear), { Position = vTarget })
    oTween:Play()
    oTween.Completed:Once(function()
        oRock.Transparency = 1
        local oFlash = Instance.new("PointLight", oRock)
        oFlash.Color = Color3.fromHex("FF6A1A")
        oFlash.Range = 40
        oFlash.Brightness = 6
        task.delay(0.4, function() oRock:Destroy() end)
    end)
end

local mWeather = Module()

function mWeather.PreloadAsync(self)
    oAtmosphere = Ensure("Atmosphere", "SFD_Atmosphere") :: Atmosphere
    oColor = Ensure("ColorCorrectionEffect", "SFD_Color") :: ColorCorrectionEffect
    local oBloom = Ensure("BloomEffect", "SFD_Bloom") :: BloomEffect
    oBloom.Intensity = 0.6
    oBloom.Size = 28
    oBloom.Threshold = 1.6
    local oSunRays = Ensure("SunRaysEffect", "SFD_SunRays") :: SunRaysEffect
    oSunRays.Intensity = 0.06
    Lighting.EnvironmentDiffuseScale = 0.6
    Lighting.EnvironmentSpecularScale = 0.4
    Lighting.ShadowSoftness = 0.6
    Lighting.GlobalShadows = true
    -- Dynamic clouds for a fuller stylised sky.
    local oTerrain = Workspace:FindFirstChildOfClass("Terrain")
    if oTerrain and not oTerrain:FindFirstChildOfClass("Clouds") then
        local oClouds = Instance.new("Clouds")
        oClouds.Cover = 0.55
        oClouds.Density = 0.6
        oClouds.Color = Color3.fromRGB(255, 255, 255)
        oClouds.Parent = oTerrain
    end

    -- Snow follows the camera.
    local oSnowAnchor = Instance.new("Part")
    oSnowAnchor.Name = "SFD_SnowAnchor"
    oSnowAnchor.Anchored = true
    oSnowAnchor.CanCollide = false
    oSnowAnchor.CanQuery = false
    oSnowAnchor.Transparency = 1
    oSnowAnchor.Size = Vector3.new(160, 1, 160)
    oSnowAnchor.Parent = Workspace
    oSnow = Instance.new("ParticleEmitter")
    oSnow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    oSnow.Color = ColorSequence.new(Color3.new(1, 1, 1))
    oSnow.Size = NumberSequence.new(0.5)
    oSnow.Rate = 160
    oSnow.Lifetime = NumberRange.new(5, 7)
    oSnow.Speed = NumberRange.new(8, 12)
    oSnow.EmissionDirection = Enum.NormalId.Bottom
    oSnow.Enabled = false
    oSnow.Parent = oSnowAnchor
    RunService.RenderStepped:Connect(function()
        local oCamera = Workspace.CurrentCamera
        if oCamera then
            oSnowAnchor.Position = oCamera.CFrame.Position + Vector3.new(0, 50, -30)
        end
    end)
end

function mWeather.StartAsync(self)
    Apply(Workspace:GetAttribute("Weather") or "Clear")
    Workspace:GetAttributeChangedSignal("Weather"):Connect(function()
        Apply(Workspace:GetAttribute("Weather") or "Clear")
    end)
    while true do
        task.wait(0.35)
        if bMeteors then
            Meteor()
        end
    end
end

return mWeather
