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
    if tData.Exclusive then
        local tEx = MonetizationConfig.ExclusiveDino
        table.insert(tList, { Id = -1, Species = tEx.Species, Size = tEx.Size, Mutation = tEx.Mutation, Exclusive = true })
    end
    local tSeen = {}
    -- Best other income, for the exclusive dino's label (10x best other).
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
            local nIncome = if tDino.Exclusive then nBest * GameConfig.ExclusiveDinoMultiplier else DinoConfig.GetIncome(tDino)
            AddLabel(oModel, tDino, nIncome)
            if tDino.Exclusive then
                local oLabel = oModel:FindFirstChild("Label", true)
                if oLabel then
                    (oLabel :: any):FindFirstChildWhichIsA("TextLabel").Text = MonetizationConfig.ExclusiveDino.Name
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
    -- Gentle idle bob + look-around for nearby dinos (cheap: CFrame only, no physics).
    RunService.Heartbeat:Connect(function()
        local oCamera = Workspace.CurrentCamera
        if not oCamera then return end
        local vCam = oCamera.CFrame.Position
        local nT = os.clock()
        for _, tPlot in tPlots do
            for _, t in tPlot do
                if (t.vHome - vCam).Magnitude < ANIMATE_DISTANCE and t.oModel.Parent then
                    local nBob = math.abs(math.sin(nT * 2 + t.nPhase)) * 0.25
                    local nYaw = math.sin(nT * 0.5 + t.nPhase) * 0.5
                    local vLook = (CFrame.Angles(0, nYaw, 0) * CFrame.new(t.vLook)).Position
                    DinoModels.PlaceAt(t.oModel, t.vHome + Vector3.new(0, nBob, 0), vLook)
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
