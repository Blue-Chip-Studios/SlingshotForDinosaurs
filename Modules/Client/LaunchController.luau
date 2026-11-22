--[[
    LaunchController
    ----------------
    The core interaction: hold to charge, release to fire, follow-cam flight,
    tap-to-bounce at geysers, landing impact and the catch reveal.

    The server owns the outcome (LaunchServer). This module asks for a plan,
    animates it, forwards one tap per window, and presents the result.

    Input (actions, not hardcoded per device):
        Charge/release: LAUNCH button (touch/click), Space, gamepad R2, or
                        holding the left mouse button on the world.
        Bounce:         tap anywhere / click / Space / R2 / A while flying.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Module = require(ReplicatedStorage.Shared.Module)
local Remote = require(ReplicatedStorage.BCDKShared.Remote)
local Store = require(ReplicatedStorage.BCDKClient.LMGui.Store)
local peek = require(ReplicatedStorage.Packages.fusion).peek
local CanyonMath = require(ReplicatedStorage.Shared.CanyonMath)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local DinoConfig = require(ReplicatedStorage.Config.DinoConfig)
local DinoModels = require(ReplicatedStorage.ClientModules.DinoModels)
local SoundController = require(ReplicatedStorage.ClientModules.SoundController)
local DataClient = require(ReplicatedStorage.ClientModules.DataClient)

local oPlayer = Players.LocalPlayer
local oRequestLaunch, oBounce, oBounceResult, oCatchResult, oFlightBroadcast

type Segment = { vFrom: Vector3, vTo: Vector3, nHeight: number, nStart: number, nDuration: number }
type Flight = {
    Id: number,
    StartedAt: number,
    Segment: Segment,
    Windows: { number },
    Bounces: number,
    WindowState: { string },
    oBait: BasePart,
    Landed: boolean,
    Result: any?,
    Tutorial: boolean,
}

local tFlight: Flight? = nil
local nChargeStart: number? = nil
local bBusy = false -- requesting / presenting
local oCameraConnection: RBXScriptConnection? = nil
local cfCamera: CFrame? = nil

local function Root(): BasePart?
    local oCharacter = oPlayer.Character
    return oCharacter and oCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function SetControls(bEnabled: boolean)
    local bOk, oControls = pcall(function()
        return require(oPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
    end)
    if bOk and oControls then
        if bEnabled then oControls:Enable() else oControls:Disable() end
    end
end

local function CanLaunch(): boolean
    local oRoot = Root()
    return oRoot ~= nil and not tFlight and not bBusy and peek(Store.Values.Modal) == ""
        and peek(Store.Values.Reveal) == false and peek(Store.Values.Full) == false
        and WorldLayout.IsOnRim(oRoot.Position) and peek(Store.Values.DataLoaded) == true
end

local function SegmentPoint(tSeg: Segment, nT: number): (Vector3, number)
    local nAlpha = math.clamp((nT - tSeg.nStart) / tSeg.nDuration, 0, 1)
    return CanyonMath.ArcPoint(tSeg.vFrom, tSeg.vTo, tSeg.nHeight, nAlpha), nAlpha
end

local function WindowTime(tF: Flight, i: number): number
    -- Server shifts later windows by BounceExtraTime per successful bounce.
    return tF.Windows[i] + GameConfig.BounceExtraTime * tF.Bounces
end

-- ===== VFX helpers (client-only, short-lived) =====

local function Burst(vPos: Vector3, cColor: Color3, nCount: number, nSize: number)
    local oAnchor = Instance.new("Part")
    oAnchor.Anchored = true
    oAnchor.CanCollide = false
    oAnchor.CanQuery = false
    oAnchor.Transparency = 1
    oAnchor.Size = Vector3.one
    oAnchor.Position = vPos
    local oEmitter = Instance.new("ParticleEmitter")
    oEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    oEmitter.Color = ColorSequence.new(cColor)
    oEmitter.LightEmission = 0.8
    oEmitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, nSize), NumberSequenceKeypoint.new(1, 0) })
    oEmitter.Speed = NumberRange.new(10, 28)
    oEmitter.SpreadAngle = Vector2.new(180, 180)
    oEmitter.Lifetime = NumberRange.new(0.5, 1.0)
    oEmitter.Rate = 0
    oEmitter.Parent = oAnchor
    oAnchor.Parent = Workspace
    oEmitter:Emit(nCount)
    task.delay(1.5, function() oAnchor:Destroy() end)
end

local function ImpactRing(vPos: Vector3, cColor: Color3)
    local oRing = Instance.new("Part")
    oRing.Shape = Enum.PartType.Cylinder
    oRing.Anchored = true
    oRing.CanCollide = false
    oRing.CanQuery = false
    oRing.Material = Enum.Material.Neon
    oRing.Color = cColor
    oRing.Size = Vector3.new(0.3, 2, 2)
    oRing.CFrame = CFrame.new(vPos) * CFrame.Angles(0, 0, math.rad(90))
    oRing.Transparency = 0.2
    oRing.Parent = Workspace
    TweenService:Create(oRing, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.3, 40, 40), Transparency = 1 }):Play()
    task.delay(0.7, function() oRing:Destroy() end)
end

local function Geyser(vGround: Vector3, nTopY: number)
    local oColumn = Instance.new("Part")
    oColumn.Anchored = true
    oColumn.CanCollide = false
    oColumn.CanQuery = false
    oColumn.Material = Enum.Material.Neon
    oColumn.Color = Color3.fromHex("5EC8F2")
    oColumn.Transparency = 0.35
    oColumn.Shape = Enum.PartType.Cylinder
    local nHeight = math.max(4, nTopY - vGround.Y)
    oColumn.Size = Vector3.new(1, 7, 7)
    oColumn.CFrame = CFrame.new(vGround) * CFrame.Angles(0, 0, math.rad(90))
    oColumn.Parent = Workspace
    TweenService:Create(oColumn, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = Vector3.new(nHeight, 7, 7),
        CFrame = CFrame.new(vGround + Vector3.new(0, nHeight / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
    }):Play()
    task.delay(1.4, function()
        TweenService:Create(oColumn, TweenInfo.new(0.4), { Transparency = 1 }):Play()
        task.delay(0.45, function() oColumn:Destroy() end)
    end)
end

local function MakeBait(cColor: Color3): BasePart
    local oBait = Instance.new("Part")
    oBait.Name = "Bait"
    oBait.Shape = Enum.PartType.Ball
    oBait.Size = Vector3.one * 2.2
    oBait.Color = cColor
    oBait.Material = Enum.Material.SmoothPlastic
    oBait.Anchored = true
    oBait.CanCollide = false
    oBait.CanQuery = false
    local a0 = Instance.new("Attachment")
    a0.Position = Vector3.new(0, 0.8, 0)
    a0.Parent = oBait
    local a1 = Instance.new("Attachment")
    a1.Position = Vector3.new(0, -0.8, 0)
    a1.Parent = oBait
    local oTrail = Instance.new("Trail")
    oTrail.Attachment0 = a0
    oTrail.Attachment1 = a1
    oTrail.Color = ColorSequence.new(cColor, Color3.new(1, 1, 1))
    oTrail.Transparency = NumberSequence.new(0, 1)
    oTrail.Lifetime = 0.6
    oTrail.LightEmission = 0.6
    oTrail.Parent = oBait
    oBait.Parent = Workspace
    return oBait
end

-- ===== Camera =====

local function StartFollowCam()
    local oCamera = Workspace.CurrentCamera
    oCamera.CameraType = Enum.CameraType.Scriptable
    cfCamera = oCamera.CFrame
    if oCameraConnection then oCameraConnection:Disconnect() end
    oCameraConnection = RunService.RenderStepped:Connect(function(nDt)
        local tF = tFlight
        if not tF then return end
        local vBait = tF.oBait.Position
        local vVel = (tF.Segment.vTo - tF.Segment.vFrom)
        local vDir = Vector3.new(vVel.X, 0, vVel.Z)
        vDir = if vDir.Magnitude > 1 then vDir.Unit else Vector3.new(0, 0, -1)
        local vGoal = vBait - vDir * 28 + Vector3.new(0, 12, 0)
        local cfGoal = CFrame.lookAt(vGoal, vBait + vDir * 18)
        cfCamera = (cfCamera :: CFrame):Lerp(cfGoal, 1 - math.exp(-nDt * 6))
        oCamera.CFrame = cfCamera :: CFrame
        local nSpeed = (tF.Segment.vTo - tF.Segment.vFrom).Magnitude / tF.Segment.nDuration
        oCamera.FieldOfView = oCamera.FieldOfView + ((70 + math.clamp(nSpeed / 30, 0, 18)) - oCamera.FieldOfView) * math.min(1, nDt * 4)
    end)
end

local function StopFollowCam()
    if oCameraConnection then
        oCameraConnection:Disconnect()
        oCameraConnection = nil
    end
    local oCamera = Workspace.CurrentCamera
    oCamera.FieldOfView = 70
    oCamera.CameraType = Enum.CameraType.Custom
end

-- ===== Flight =====

local mLaunch = Module()

local function EndFlight()
    local tF = tFlight
    tFlight = nil
    if tF and tF.oBait then tF.oBait:Destroy() end
    Store.Values.Flying:set(false)
    Store.Values.BounceWindowOpen:set(false)
    StopFollowCam()
    SetControls(true)
    bBusy = false
end

local function PresentCatch(tF: Flight, tResult)
    -- Dino pops out at the landing point; camera frames it while the reveal card shows.
    local vLand = tF.Segment.vTo
    local tDino = tResult.Dino
    local oModel = DinoModels.Build(tDino)
    DinoModels.PlaceAt(oModel, vLand, Workspace.CurrentCamera.CFrame.Position - vLand)
    oModel.Parent = Workspace
    local tMut = DinoConfig.GetMutation(tDino.Mutation)
    Burst(vLand + Vector3.new(0, 3, 0), if tMut.Default then Color3.new(1, 1, 1) else tMut.Color, 60, 1.6)
    -- Roar pitch by size: bigger dinos roar deeper (GDD 19).
    local tSize = DinoConfig.GetSize(tDino.Size)
    SoundController:Play("Reveal", math.clamp(1.25 - (tSize.Scale - 1) * 0.3, 0.7, 1.35))
    if not tMut.Default then
        task.delay(0.35, function() SoundController:Play("Perfect") end)
    end
    local nHeight = DinoModels.Height(oModel)
    local oCamera = Workspace.CurrentCamera
    local vLook = vLand + Vector3.new(0, nHeight * 0.5, 0)
    local vFrom = vLook + (oCamera.CFrame.Position - vLook).Unit * (nHeight * 2.2 + 10) + Vector3.new(0, 2, 0)
    if oCameraConnection then oCameraConnection:Disconnect() oCameraConnection = nil end
    TweenService:Create(oCamera, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.lookAt(vFrom, vLook) }):Play()

    Store.Values.Reveal:set(tResult)
    -- Wait until the player closes the reveal card (or 6s).
    local nWaitUntil = os.clock() + 6
    while peek(Store.Values.Reveal) ~= false and os.clock() < nWaitUntil do
        task.wait()
    end
    Store.Values.Reveal:set(false)
    -- Shrink away (it reappears on the plot via PlotController).
    Burst(vLook, Color3.fromHex("FFE14D"), 30, 1)
    oModel:Destroy()
    if tResult.Placement and (tResult.Placement.Status == "Placed" or tResult.Placement.Status == "Replaced") then
        local iPlot = oPlayer:GetAttribute("PlotIndex")
        if iPlot then
            Burst(WorldLayout.Plot(iPlot).Center + Vector3.new(0, 4, 0), Color3.fromHex("FFE14D"), 40, 1.2)
            SoundController:Play("Coin")
        end
    end
end

local function OnLanded(tF: Flight)
    tF.Landed = true
    local vLand = tF.Segment.vTo
    local tBiome = DinoConfig.GetBiome(CanyonMath.ZToMeters(vLand.Z))
    ImpactRing(vLand + Vector3.new(0, 0.3, 0), tBiome.Color)
    Burst(vLand, Color3.fromHex("D7CCC8"), 25, 1.4)
    SoundController:Play("Impact")
    tF.oBait.Transparency = 1
    -- Wait for the server's catch (normally already here, or within a fraction of a second).
    local nTimeout = os.clock() + 4
    while not tF.Result and os.clock() < nTimeout do
        task.wait()
    end
    if tF.Result then
        PresentCatch(tF, tF.Result)
    end
    EndFlight()
end

local function Fly(tPlan)
    local tF: Flight = {
        Id = tPlan.FlightId,
        StartedAt = os.clock(),
        Segment = { vFrom = tPlan.Origin, vTo = tPlan.Landing, nHeight = CanyonMath.ArcHeight(tPlan.Origin, tPlan.Landing), nStart = 0, nDuration = tPlan.Duration },
        Windows = tPlan.Windows,
        Bounces = 0,
        WindowState = {},
        oBait = MakeBait(tPlan.BaitColor or Color3.new(1, 0.3, 0.5)),
        Landed = false,
        Result = nil,
        Tutorial = tPlan.Tutorial == true,
    }
    for i in tF.Windows do
        tF.WindowState[i] = "Pending"
    end
    tFlight = tF
    Store.Values.Flying:set(true)
    Store.Values.BounceFeedback:set("")
    SoundController:Play("Launch")
    StartFollowCam()

    local oStep
    oStep = RunService.Heartbeat:Connect(function()
        if tFlight ~= tF then
            oStep:Disconnect()
            return
        end
        local nT = os.clock() - tF.StartedAt
        local vPos, nAlpha = SegmentPoint(tF.Segment, nT)
        tF.oBait.Position = vPos
        Store.Values.LiveMeters:set(CanyonMath.ZToMeters(vPos.Z))
        -- Bounce windows: spawn the geyser just before, open the prompt around it.
        local bOpen = false
        for i in tF.Windows do
            local nW = WindowTime(tF, i)
            local sState = tF.WindowState[i]
            if sState == "Pending" and nT >= nW - 0.6 then
                tF.WindowState[i] = "Shown"
                local vAt = SegmentPoint(tF.Segment, nW)
                Geyser(Vector3.new(vAt.X, CanyonMath.FloorY, vAt.Z), vAt.Y)
            end
            if (sState == "Shown" or sState == "Pending") and math.abs(nT - nW) <= GameConfig.Bounce.OK.Window + 0.05 then
                bOpen = true
            end
            if sState == "Shown" and nT > nW + GameConfig.Bounce.OK.Window then
                tF.WindowState[i] = "Gone"
            end
        end
        Store.Values.BounceWindowOpen:set(bOpen)
        if nAlpha >= 1 and not tF.Landed then
            oStep:Disconnect()
            task.spawn(OnLanded, tF)
        end
    end)
end

function mLaunch.BeginCharge(self)
    if not CanLaunch() or nChargeStart then return end
    nChargeStart = os.clock()
    Store.Values.Charging:set(true)
    SoundController:Play("Charge")
    task.spawn(function()
        while nChargeStart do
            Store.Values.Charge:set(math.clamp((os.clock() - nChargeStart) / GameConfig.ChargeTime, 0, 1))
            task.wait()
        end
    end)
end

function mLaunch.Release(self)
    if not nChargeStart then return end
    local nCharge = math.clamp((os.clock() - nChargeStart) / GameConfig.ChargeTime, 0, 1)
    nChargeStart = nil
    Store.Values.Charging:set(false)
    Store.Values.Charge:set(0)
    if not CanLaunch() then return end
    bBusy = true
    -- Aim from the camera's horizontal look direction (left/right across the canyon).
    local vLook = Workspace.CurrentCamera.CFrame.LookVector
    local nAim = math.clamp(vLook.X * 1.5, -1, 1)
    SetControls(false)
    local bOk, tPlan = pcall(function()
        return oRequestLaunch:InvokeServer({ Charge = nCharge, Aim = nAim })
    end)
    if not bOk or not tPlan or not tPlan.Ok then
        SetControls(true)
        bBusy = false
        if tPlan and tPlan.Reason == "NotOnRim" then
            Store.Values.Toast:set("Go back to the launch rim!")
        end
        return
    end
    Fly(tPlan)
end

function mLaunch.Tap(self)
    local tF = tFlight
    if not tF or tF.Landed then return end
    oBounce:FireServer({ FlightId = tF.Id, T = os.clock() - tF.StartedAt })
end

function mLaunch.IsFlying(self): boolean
    return tFlight ~= nil
end

function mLaunch.PreloadAsync(self)
    oRequestLaunch = Remote:GetFunction("RequestLaunch")
    oBounce = Remote:GetEvent("Bounce")
    oBounceResult = Remote:GetEvent("BounceResult")
    oCatchResult = Remote:GetEvent("CatchResult")
    oFlightBroadcast = Remote:GetEvent("FlightBroadcast")

    oBounceResult:OnClientEvent(function(tResult)
        local tF = tFlight
        if not tF or tResult.FlightId ~= tF.Id then return end
        Store.Values.BounceFeedback:set(tResult.Quality)
        task.delay(0.9, function()
            if peek(Store.Values.BounceFeedback) == tResult.Quality then
                Store.Values.BounceFeedback:set("")
            end
        end)
        tF.WindowState[tResult.Window] = "Gone"
        if tResult.Quality == "Miss" then
            SoundController:Play("Error")
            return
        end
        -- Re-plan the rest of the flight from the bait's current position to the new landing.
        tF.Bounces += 1
        local nT = os.clock() - tF.StartedAt
        local vNow = tF.oBait.Position
        tF.Segment = { vFrom = vNow, vTo = tResult.Landing, nHeight = 20 + (tResult.Landing - vNow).Magnitude * 0.08, nStart = nT, nDuration = math.max(0.3, tResult.EndsIn) }
        Burst(vNow, Color3.fromHex("5EC8F2"), 30, 1.2)
        SoundController:Play(if tResult.Quality == "Perfect" then "Perfect" else "Bounce")
    end)

    oCatchResult:OnClientEvent(function(tResult)
        local tF = tFlight
        if tF and tResult.FlightId == tF.Id then
            tF.Result = tResult
        end
    end)

    -- Other players' launches: a light local arc, no camera.
    oFlightBroadcast:OnClientEvent(function(t)
        if t.UserId == oPlayer.UserId then return end
        local oBait = MakeBait(Color3.fromHex("FFE14D"))
        local nStart = os.clock()
        local nHeight = CanyonMath.ArcHeight(t.Origin, t.Landing)
        local oConn
        oConn = RunService.Heartbeat:Connect(function()
            local nAlpha = (os.clock() - nStart) / t.Duration
            if nAlpha >= 1 then
                oConn:Disconnect()
                oBait:Destroy()
                return
            end
            oBait.Position = CanyonMath.ArcPoint(t.Origin, t.Landing, nHeight, nAlpha)
        end)
    end)
end

function mLaunch.StartAsync(self)
    -- Keyboard / gamepad: hold to charge, release to fire; tap to bounce while flying.
    ContextActionService:BindAction("SFD_Launch", function(_, eState)
        if tFlight then
            if eState == Enum.UserInputState.Begin then self:Tap() end
            return Enum.ContextActionResult.Sink
        end
        if eState == Enum.UserInputState.Begin then
            self:BeginCharge()
        elseif eState == Enum.UserInputState.End then
            self:Release()
        end
        return Enum.ContextActionResult.Pass
    end, false, Enum.KeyCode.Space, Enum.KeyCode.ButtonR2)
    ContextActionService:BindAction("SFD_Bounce", function(_, eState)
        if tFlight and eState == Enum.UserInputState.Begin then
            self:Tap()
            return Enum.ContextActionResult.Sink
        end
        return Enum.ContextActionResult.Pass
    end, false, Enum.KeyCode.ButtonA)

    -- Mouse: hold LMB on the world (not on UI) to charge.
    UserInputService.InputBegan:Connect(function(oInput, bProcessed)
        if bProcessed then return end
        if oInput.UserInputType == Enum.UserInputType.MouseButton1 then
            if tFlight then self:Tap() else self:BeginCharge() end
        end
    end)
    UserInputService.InputEnded:Connect(function(oInput)
        if oInput.UserInputType == Enum.UserInputType.MouseButton1 then
            self:Release()
        end
    end)

    -- Auto-Launch pass: fire at full charge whenever idle on the rim, bounce "Good".
    task.spawn(function()
        while true do
            task.wait(1.5)
            local tSettings = DataClient:Get("Settings") or {}
            local tPasses = DataClient:Get("Passes") or {}
            if tSettings.AutoLaunch and tPasses.AutoLaunch and CanLaunch() and not nChargeStart then
                self:BeginCharge()
                task.wait(GameConfig.ChargeTime + 0.05)
                self:Release()
            end
            local tF = tFlight
            if tF and not (tF :: any).AutoScheduled and tSettings.AutoLaunch and tPasses.AutoLaunch then
                (tF :: any).AutoScheduled = true
                -- Tap shortly after each window centre for a "Good" (window times shift after each bounce).
                task.spawn(function()
                    for i in tF.Windows do
                        while tFlight == tF and (os.clock() - tF.StartedAt) < WindowTime(tF, i) + 0.18 do
                            task.wait()
                        end
                        if tFlight ~= tF then return end
                        self:Tap()
                        task.wait(0.2)
                    end
                end)
            end
        end
    end)

    -- Respawn safety: never leave controls disabled.
    oPlayer.CharacterAdded:Connect(function()
        if tFlight then EndFlight() end
        nChargeStart = nil
        Store.Values.Charging:set(false)
    end)
end

return mLaunch
