--[[
    PlotController
    --------------
    Renders every plot's dinosaurs from the public "Plot" replicas. Models are
    client-only (the server holds data, not instances), are rebuilt only for
    dinos that changed, and idle-animate only when the camera is near.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Module = require(ReplicatedStorage.Shared.Module)
local ReplicaClient = require(ReplicatedStorage.External.Replica.ReplicaClient)
local DinoConfig = require(ReplicatedStorage.Config.DinoConfig)
local MonetizationConfig = require(ReplicatedStorage.Config.MonetizationConfig)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local ExclusiveRotation = require(ReplicatedStorage.Shared.ExclusiveRotation)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local Format = require(ReplicatedStorage.Shared.Format)
local Theme = require(ReplicatedStorage.Shared.Theme)
local DinoModels = require(ReplicatedStorage.ClientModules.DinoModels)

type Rendered = { oModel: Model, sKey: string, vHome: Vector3, nPhase: number, vLook: Vector3 }

local tPlots: { [number]: { [number]: Rendered } } = {} -- [plotIndex][dinoId]
local ANIMATE_DISTANCE = 220

local function Key(t): string
    return `{t.Species}:{t.Size}:{t.Mutation}`
end

local function AddLabel(oModel: Model, tDino, nIncome: number)
    local oRoot = oModel:FindFirstChild("Body") or oModel:FindFirstChildWhichIsA("BasePart", true)
    if not oRoot then return end
    local oBillboard = Instance.new("BillboardGui")
    oBillboard.Name = "Label"
    oBillboard.Size = UDim2.fromOffset(160, 46)
    oBillboard.StudsOffsetWorldSpace = Vector3.new(0, DinoModels.Height(oModel) * 0.6 + 1.5, 0)
    oBillboard.MaxDistance = 70
    oBillboard.LightInfluence = 0
    local function Line(sText: string, cColor: Color3, nY: number, nH: number)
        local o = Instance.new("TextLabel")
        o.BackgroundTransparency = 1
        o.Size = UDim2.new(1, 0, nH, 0)
        o.Position = UDim2.fromScale(0, nY)
        o.FontFace = Theme.Display
        o.TextScaled = true
        o.TextColor3 = cColor
        o.Text = sText
        local s = Instance.new("UIStroke")
        s.Color = Theme.Ink
        s.Thickness = 2
        s.Parent = o
        o.Parent = oBillboard
    end
    local tSize = DinoConfig.GetSize(tDino.Size)
    local tMut = DinoConfig.GetMutation(tDino.Mutation)
    local sName = (if tSize.Default then "" else tSize.Name .. " ") .. (if tMut.Default then "" else tMut.Name .. " ") .. DinoConfig.Species[tDino.Species].Name
    Line(sName, if tMut.Default then Theme.White else Theme.Mutation[tDino.Mutation], 0, 0.55)
    Line(Format.Cash(nIncome) .. "/s", Theme.Cash, 0.55, 0.45)
    oBillboard.Parent = oRoot
end

local function PlotFolder(iPlot: number): Instance?
    local oWorld = Workspace:FindFirstChild("World")
    local oPlot = oWorld and oWorld:FindFirstChild("Plots") and oWorld.Plots:FindFirstChild("Plot" .. iPlot)
    return oPlot and oPlot:FindFirstChild("Dinos")
end

local function Render(iPlot: number, tData)
    local oFolder = PlotFolder(iPlot)
    if not oFolder then return end
    tPlots[iPlot] = tPlots[iPlot] or {}
    local tRendered = tPlots[iPlot]
    local tList = table.clone(tData.Dinos or {})
    -- Owned rotation exclusives get negative ids so they never clash with regular dinos.
    for i, sId in tData.Exclusives or {} do
        local tEx = ExclusiveRotation.Get(sId)
        if tEx then
            table.insert(tList, { Id = -i, Species = tEx.Species, Size = tEx.Size, Mutation = tEx.Mutation, Exclusive = true, ExName = tEx.Name, Best = i == 1 })
        end
    end
    local tSeen = {}
    -- Best other income, for the exclusive dinos' labels.
    local nBest = 0
    for _, t in tData.Dinos or {} do
        nBest = math.max(nBest, DinoConfig.GetIncome(t))
    end
    for i, tDino in tList do
        tSeen[tDino.Id] = true
        local tExisting = tRendered[tDino.Id]
        local vHome = WorldLayout.DinoSpot(iPlot, i, math.max(#tList, 6))
        if tExisting and tExisting.sKey == Key(tDino) then
            tExisting.vHome = vHome
        else
            if tExisting then tExisting.oModel:Destroy() end
            local oModel = DinoModels.Build(tDino)
            oModel.Name = "Dino_" .. tDino.Id
            local vLook = Vector3.new(math.random() - 0.5, 0, -1)
            DinoModels.PlaceAt(oModel, vHome, vLook)
            local tRot = MonetizationConfig.ExclusiveRotation
            local nIncome = if tDino.Exclusive then nBest * (if tDino.Best then tRot.Multiplier else tRot.ExtraEachMultiplier) else DinoConfig.GetIncome(tDino)
            AddLabel(oModel, tDino, nIncome)
            if tDino.Exclusive then
                local oLabel = oModel:FindFirstChild("Label", true)
                if oLabel then
                    (oLabel :: any):FindFirstChildWhichIsA("TextLabel").Text = tDino.ExName
                end
            end
            oModel.Parent = oFolder
            tRendered[tDino.Id] = { oModel = oModel, sKey = Key(tDino), vHome = vHome, nPhase = math.random() * 6.28, vLook = vLook }
        end
    end
    for iId, t in tRendered do
        if not tSeen[iId] then
            t.oModel:Destroy()
            tRendered[iId] = nil
        end
    end
    -- VIP: golden fence
    local oPlot = oFolder.Parent
    for _, o in oPlot:GetChildren() do
        if o.Name == "Fence" and o:IsA("BasePart") then
            o.Color = if tData.VIP then Color3.fromHex("FFC531") else Color3.fromHex("8B5A2B")
            o.Material = if tData.VIP then Enum.Material.Foil else Enum.Material.Wood
        end
    end
end

local function Clear(iPlot: number)
    for _, t in tPlots[iPlot] or {} do
        t.oModel:Destroy()
    end
    tPlots[iPlot] = nil
end

local mPlot = Module()

function mPlot.PreloadAsync(self)
    ReplicaClient.OnNew("Plot", function(oReplica)
        local iPlot = oReplica.Data.PlotIndex
        Workspace:WaitForChild("World"):WaitForChild("Plots")
        Render(iPlot, oReplica.Data)
        oReplica:OnChange(function()
            Render(iPlot, oReplica.Data)
        end)
        -- Replica destroyed when the owner leaves.
        task.spawn(function()
            while oReplica:IsActive() do
                task.wait(1)
            end
            Clear(iPlot)
        end)
    end)
end

function mPlot.StartAsync(self)
    -- Procedural wander: each nearby dino idles, then waddles to a random spot inside its
    -- plot (bob + side-to-side roll while walking). CFrame only, no physics or rigs.
    local oRandom = Random.new()
    RunService.Heartbeat:Connect(function(nDt)
        local oCamera = Workspace.CurrentCamera
        if not oCamera then return end
        local vCam = oCamera.CFrame.Position
        local nT = os.clock()
        for iPlot, tPlot in tPlots do
            local tLayout = WorldLayout.Plot(iPlot)
            for _, t in tPlot do
                local tw = t :: any
                tw.vPos = tw.vPos or t.vHome
                if (tw.vPos - vCam).Magnitude < ANIMATE_DISTANCE and t.oModel.Parent then
                    tw.nNextMove = tw.nNextMove or (nT + oRandom:NextNumber(0.5, 4))
                    if not tw.vTarget and nT >= tw.nNextMove then
                        local vHalf = tLayout.Size / 2 - Vector3.new(5, 0, 6)
                        tw.vTarget = tLayout.Center + Vector3.new(oRandom:NextNumber(-vHalf.X, vHalf.X), 0, oRandom:NextNumber(-vHalf.Z, vHalf.Z))
                    end
                    local nBob, nRoll = math.abs(math.sin(nT * 2 + t.nPhase)) * 0.12, 0
                    if tw.vTarget then
                        local vTo = tw.vTarget - tw.vPos
                        local nDist = Vector3.new(vTo.X, 0, vTo.Z).Magnitude
                        local nSpeed = 4 * math.clamp(t.oModel:GetScale(), 0.6, 2)
                        if nDist < 0.5 then
                            tw.vTarget = nil
                            tw.nNextMove = nT + oRandom:NextNumber(2, 6)
                        else
                            local vDir = Vector3.new(vTo.X, 0, vTo.Z).Unit
                            tw.vPos += vDir * math.min(nDist, nSpeed * nDt)
                            -- Turn smoothly toward the walk direction.
                            t.vLook = t.vLook:Lerp(vDir, math.min(1, nDt * 5))
                            local nStep = nT * 9 + t.nPhase
                            nBob = math.abs(math.sin(nStep)) * 0.35
                            nRoll = math.sin(nStep) * 0.07
                        end
                    end
                    DinoModels.PlaceAt(t.oModel, tw.vPos + Vector3.new(0, nBob, 0), t.vLook)
                    if nRoll ~= 0 then
                        t.oModel:PivotTo(t.oModel:GetPivot() * CFrame.Angles(0, 0, nRoll))
                    end
                end
            end
        end
    end)
end

-- World position of a dino on a plot (for the catch fly-in).
function mPlot.GetDinoModel(self, iPlot: number, iDinoId: number): Model?
    local t = tPlots[iPlot] and tPlots[iPlot][iDinoId]
    return t and t.oModel
end

return mPlot
