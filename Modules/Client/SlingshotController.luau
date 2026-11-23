--[[
    SlingshotController
    -------------------
    Game feel for the player's own launch slingshot (the giant Blender slingshot on their plot):
    while they charge, the pouch is drawn back and down and the two rubber bands stretch from the
    prong tips to it, thinning as they stretch; on release the pouch snaps forward past the frame
    and wobbles to rest on a damped spring.

    The model ships hidden markers (TipL, TipR, PouchMark) for the band anchors and the pouch
    centre. The static Band mesh is hidden and replaced by two cylinder parts this module poses
    every frame. Client-side only; other players' slingshots stay at rest.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Module = require(ReplicatedStorage.Shared.Module)
local Store = require(ReplicatedStorage.BCDKClient.LMGui.Store)
local peek = require(ReplicatedStorage.Packages.fusion).peek

local PULL_BACK = 3.4      -- studs at full charge (scaled with the model)
local PULL_DOWN = 0.7
local SNAP_FREQ = 19       -- release wobble (rad/s) and damping
local SNAP_DAMP = 5.5

type Rig = {
    oModel: Model, oTipL: BasePart, oTipR: BasePart, oPouch: BasePart, cfPouchRel: CFrame,
    vPouchRest: Vector3, nScale: number, oBandL: Part, oBandR: Part, nThick: number,
}

local tRig: Rig? = nil
local nPulled = 0          -- current pull (0..1) and the pull at the moment of release
local nReleaseAt: number? = nil
local nReleasePull = 0

local function NewBand(oModel: Model, oLike: BasePart, nThick: number): Part
    local o = Instance.new("Part")
    o.Name = "BandLive"
    o.Shape = Enum.PartType.Cylinder
    o.Color = oLike.Color
    o.Material = Enum.Material.SmoothPlastic
    o.Anchored = true
    o.CanCollide = false
    o.CanQuery = false
    o.CanTouch = false
    o.CastShadow = false
    o.Size = Vector3.new(1, nThick, nThick)
    o.Parent = oModel
    return o
end

local function FindRig(): Rig?
    local iPlot = Players.LocalPlayer:GetAttribute("PlotIndex")
    local oWorld = Workspace:FindFirstChild("World")
    local oPlots = oWorld and oWorld:FindFirstChild("Plots")
    local oPlot = iPlot and oPlots and oPlots:FindFirstChild("Plot" .. iPlot)
    local oModel = oPlot and oPlot:FindFirstChild("LaunchSlingshot")
    if not (oModel and oModel:IsA("Model")) then return nil end
    local oTipL, oTipR = oModel:FindFirstChild("TipL"), oModel:FindFirstChild("TipR")
    local oMark, oPouch, oBand = oModel:FindFirstChild("PouchMark"), oModel:FindFirstChild("Pouch"), oModel:FindFirstChild("Band")
    if not (oTipL and oTipR and oMark and oPouch and oBand) then return nil end
    local nScale = oModel:GetScale()
    ;(oBand :: BasePart).Transparency = 1
    local nThick = 0.3 * nScale
    local vRest = (oMark :: BasePart).Position
    return {
        oModel = oModel, oTipL = oTipL :: BasePart, oTipR = oTipR :: BasePart, oPouch = oPouch :: BasePart,
        cfPouchRel = CFrame.new(vRest):ToObjectSpace((oPouch :: BasePart).CFrame), vPouchRest = vRest, nScale = nScale,
        oBandL = NewBand(oModel, oBand :: BasePart, nThick), oBandR = NewBand(oModel, oBand :: BasePart, nThick), nThick = nThick,
    }
end

-- Stretches a cylinder band from A to B; it thins as it lengthens (rubber keeps its volume, roughly).
local function PoseBand(o: Part, vA: Vector3, vB: Vector3, nThick: number, nRestLen: number)
    local nLen = math.max((vB - vA).Magnitude, 0.05)
    local nT = nThick * math.clamp(math.sqrt(nRestLen / nLen), 0.55, 1.1)
    o.Size = Vector3.new(nLen, nT, nT)
    o.CFrame = CFrame.lookAt((vA + vB) / 2, vB) * CFrame.Angles(0, math.pi / 2, 0)
end

local function Update()
    local t = tRig
    if not t or not t.oModel.Parent then
        tRig = FindRig()
        return
    end
    local nNow = os.clock()
    local bCharging = peek(Store.Values.Charging)
    local nPull = 0
    if bCharging then
        nPull = peek(Store.Values.Charge)
        nPulled, nReleaseAt = nPull, nil
    elseif nReleaseAt then
        -- Snap forward through the rest position and wobble out.
        local u = nNow - nReleaseAt
        nPull = nReleasePull * math.cos(u * SNAP_FREQ) * math.exp(-u * SNAP_DAMP)
        if u > 1.2 then nReleaseAt, nPull = nil, 0 end
    elseif nPulled > 0.02 then
        -- Just let go: remember how far it was drawn and start the snap.
        nReleaseAt, nReleasePull, nPull, nPulled = nNow, nPulled, nPulled, 0
    end
    -- Back = away from the canyon (the model faces -Z, the pouch hangs behind the prongs).
    local cfModel = t.oModel:GetPivot()
    local vBack = -cfModel.LookVector
    local vPouch = t.vPouchRest + (vBack * PULL_BACK + Vector3.new(0, -PULL_DOWN * math.max(nPull, 0), 0)) * nPull * t.nScale
    t.oPouch.CFrame = CFrame.new(vPouch) * t.cfPouchRel
    local vSide = cfModel.RightVector * 0.5 * t.nScale
    local nRest = (t.oTipL.Position - (t.vPouchRest - vSide)).Magnitude
    PoseBand(t.oBandL, t.oTipL.Position, vPouch - vSide, t.nThick, nRest)
    PoseBand(t.oBandR, t.oTipR.Position, vPouch + vSide, t.nThick, nRest)
end

local mSlingshot = Module()

function mSlingshot.StartAsync(self)
    RunService.RenderStepped:Connect(Update)
end

return mSlingshot
