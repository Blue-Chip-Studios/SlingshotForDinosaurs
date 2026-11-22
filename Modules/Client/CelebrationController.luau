--[[
    CelebrationController
    ---------------------
    Makes big catches feel big. The server tags each catch with a Tier:
      * "Epic"   (any rare): white flash, a spinning burst banner, confetti, a short camera shake, fanfare.
      * "Mythic" (Cosmic, or Colossal Legendary / top mutation): all of that, bigger and longer,
        with a roar, rainbow confetti and a gold banner. The server also blesses everyone with
        2x luck, and other players get a full-width banner (Announcement Kind "Mythic").
    Runs alongside the normal reveal card (it starts when Store.Values.Reveal shows the catch).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Module = require(ReplicatedStorage.Shared.Module)
local Remote = require(ReplicatedStorage.BCDKShared.Remote)
local Store = require(ReplicatedStorage.BCDKClient.LMGui.Store)
local Fusion = require(ReplicatedStorage.Packages.fusion)
local Theme = require(ReplicatedStorage.Shared.Theme)
local AssetConfig = require(ReplicatedStorage.Config.AssetConfig)
local SoundController = require(ReplicatedStorage.ClientModules.SoundController)

local oPlayer = Players.LocalPlayer
local oGui: ScreenGui
local nShakeUntil, nShakePower = 0, 0

local TIERS = {
    Epic = { Title = "EPIC CATCH!", Color = Color3.fromHex("B266FF"), Confetti = 90, Shake = 0.35, Hold = 1.6 },
    Mythic = { Title = "MYTHIC CATCH!!", Color = Color3.fromHex("FFD23F"), Confetti = 220, Shake = 0.7, Hold = 2.6 },
}

local function PlaySfx(sName: string, nVolume: number)
    local iId = AssetConfig.Sounds[sName]
    if not iId then return false end
    local o = Instance.new("Sound")
    o.SoundId = "rbxassetid://" .. iId
    o.Volume = nVolume
    o.Parent = SoundService
    SoundService:PlayLocalSound(o)
    task.delay(6, function() o:Destroy() end)
    return true
end

local function Flash(nAlpha: number)
    local o = Instance.new("Frame")
    o.Size = UDim2.fromScale(1, 1)
    o.BackgroundColor3 = Color3.new(1, 1, 1)
    o.BackgroundTransparency = 1 - nAlpha
    o.ZIndex = 50
    o.Parent = oGui
    TweenService:Create(o, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
    task.delay(0.7, function() o:Destroy() end)
end

local function Banner(tTier, bRainbow: boolean)
    local oHolder = Instance.new("Frame")
    oHolder.BackgroundTransparency = 1
    oHolder.AnchorPoint = Vector2.new(0.5, 0.5)
    oHolder.Position = UDim2.fromScale(0.5, 0.3)
    oHolder.Size = UDim2.fromOffset(900, 240)
    oHolder.ZIndex = 51
    local oScale = Instance.new("UIScale")
    oScale.Scale = 0.2
    oScale.Parent = oHolder
    -- Spinning sunburst behind the title.
    local oBurst = Instance.new("Frame")
    oBurst.AnchorPoint = Vector2.new(0.5, 0.5)
    oBurst.Position = UDim2.fromScale(0.5, 0.5)
    oBurst.Size = UDim2.fromOffset(300, 300)
    oBurst.BackgroundTransparency = 1
    oBurst.ZIndex = 51
    oBurst.Parent = oHolder
    for i = 0, 11 do
        local oRay = Instance.new("Frame")
        oRay.AnchorPoint = Vector2.new(0.5, 0.5)
        oRay.Position = UDim2.fromScale(0.5, 0.5)
        oRay.Size = UDim2.fromOffset(46, 620)
        oRay.Rotation = i * 15
        oRay.BackgroundColor3 = tTier.Color
        oRay.BackgroundTransparency = 0.45
        oRay.BorderSizePixel = 0
        oRay.ZIndex = 51
        local oGrad = Instance.new("UIGradient")
        oGrad.Rotation = 90
        oGrad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) })
        oGrad.Parent = oRay
        oRay.Parent = oBurst
    end
    local oTitle = Instance.new("TextLabel")
    oTitle.BackgroundTransparency = 1
    oTitle.Size = UDim2.fromScale(1, 1)
    oTitle.FontFace = Theme.Display
    oTitle.TextScaled = true
    oTitle.Text = tTier.Title
    oTitle.TextColor3 = Color3.new(1, 1, 1)
    oTitle.ZIndex = 52
    local oStroke = Instance.new("UIStroke")
    oStroke.Thickness = 7
    oStroke.Color = Theme.Ink
    oStroke.Parent = oTitle
    local oGrad = Instance.new("UIGradient")
    oGrad.Color = if bRainbow
        then ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHex("FF5EDB")), ColorSequenceKeypoint.new(0.5, Color3.fromHex("FFD23F")), ColorSequenceKeypoint.new(1, Color3.fromHex("45E0FF")) })
        else ColorSequence.new(Color3.new(1, 1, 1), tTier.Color)
    oGrad.Rotation = 90
    oGrad.Parent = oTitle
    oTitle.Parent = oHolder
    oHolder.Parent = oGui
    TweenService:Create(oScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
    local oSpin = RunService.RenderStepped:Connect(function(nDt)
        oBurst.Rotation += nDt * 40
    end)
    task.delay(tTier.Hold, function()
        TweenService:Create(oScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play()
        task.wait(0.35)
        oSpin:Disconnect()
        oHolder:Destroy()
    end)
end

-- Confetti in front of the camera (screen-space would need images; world particles look richer).
local function Confetti(nCount: number, bRainbow: boolean, cTint: Color3)
    local oCam = Workspace.CurrentCamera
    if not oCam then return end
    local oPart = Instance.new("Part")
    oPart.Anchored, oPart.CanCollide, oPart.CanQuery, oPart.CanTouch = true, false, false, false
    oPart.Transparency = 1
    oPart.Size = Vector3.new(16, 1, 1)
    oPart.CFrame = oCam.CFrame * CFrame.new(0, 6, -14)
    oPart.Parent = Workspace
    local oEmitter = Instance.new("ParticleEmitter")
    oEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    oEmitter.Color = if bRainbow
        then ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHex("FF5EDB")), ColorSequenceKeypoint.new(0.33, Color3.fromHex("FFD23F")), ColorSequenceKeypoint.new(0.66, Color3.fromHex("52E52F")), ColorSequenceKeypoint.new(1, Color3.fromHex("45E0FF")) })
        else ColorSequence.new(cTint, Color3.new(1, 1, 1))
    oEmitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.2) })
    oEmitter.Lifetime = NumberRange.new(1.5, 2.6)
    oEmitter.Speed = NumberRange.new(8, 18)
    oEmitter.SpreadAngle = Vector2.new(70, 70)
    oEmitter.Acceleration = Vector3.new(0, -14, 0)
    oEmitter.Rotation = NumberRange.new(0, 360)
    oEmitter.RotSpeed = NumberRange.new(-200, 200)
    oEmitter.LightEmission = 0.6
    oEmitter.EmissionDirection = Enum.NormalId.Top
    oEmitter.Rate = 0
    oEmitter.Parent = oPart
    oEmitter:Emit(nCount)
    task.delay(3.2, function() oPart:Destroy() end)
end

local function Celebrate(sTier: string)
    local tTier = TIERS[sTier]
    if not tTier then return end
    local bMythic = sTier == "Mythic"
    Flash(if bMythic then 0.85 else 0.55)
    Banner(tTier, bMythic)
    Confetti(tTier.Confetti, bMythic, tTier.Color)
    nShakeUntil, nShakePower = os.clock() + tTier.Shake, if bMythic then 0.9 else 0.45
    if not PlaySfx("Fanfare", if bMythic then 0.9 else 0.7) then SoundController:Play("Perfect") end
    if bMythic then
        task.delay(0.35, function() PlaySfx("Roar", 0.9) end)
        task.delay(1.1, function() Confetti(tTier.Confetti, true, tTier.Color) end)
    end
end

local mCelebration = Module()

function mCelebration.PreloadAsync(self)
    oGui = Instance.new("ScreenGui")
    oGui.Name = "Celebration"
    oGui.IgnoreGuiInset = true
    oGui.DisplayOrder = 40
    oGui.ResetOnSpawn = false
    oGui.Parent = oPlayer:WaitForChild("PlayerGui")
end

function mCelebration.StartAsync(self)
    -- Our own catches: celebrate as the reveal card appears.
    local scope = Fusion.scoped(Fusion)
    local tLast = nil
    scope:Observer(Store.Values.Reveal):onChange(function()
        local t = Fusion.peek(Store.Values.Reveal)
        if typeof(t) == "table" and t ~= tLast and t.Tier then
            tLast = t
            Celebrate(t.Tier)
        end
    end)
    -- Someone else's Mythic: a smaller flash + confetti so the whole server feels it.
    Remote:GetEvent("Announcement"):OnClientEvent(function(t)
        if typeof(t) == "table" and t.Kind == "Mythic" and t.UserId ~= oPlayer.UserId then
            Flash(0.4)
            Confetti(80, true, TIERS.Mythic.Color)
            PlaySfx("Fanfare", 0.5)
        end
    end)
    -- Camera shake (applied after the camera scripts each frame).
    RunService:BindToRenderStep("SFD_CelebrationShake", Enum.RenderPriority.Camera.Value + 2, function()
        local nLeft = nShakeUntil - os.clock()
        if nLeft <= 0 then return end
        local oCam = Workspace.CurrentCamera
        local n = nShakePower * math.min(1, nLeft * 3)
        oCam.CFrame *= CFrame.Angles(math.rad((math.random() - 0.5) * 2 * n), math.rad((math.random() - 0.5) * 2 * n), 0)
    end)
end

return mCelebration
