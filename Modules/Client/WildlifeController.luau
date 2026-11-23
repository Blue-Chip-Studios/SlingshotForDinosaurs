--[[
    WildlifeController
    ------------------
    Ambient life on the canyon floor, so every area feels alive from the rim and during flights.
    Each area (DinoConfig.Biomes) gets a few of its own dinos plus themed critters
    (CritterConfig): herbivores wander and stop to graze, hunters sniff about and sometimes rear
    up and roar, mammoths plod along as a herd, turtles paddle in and out of the lagoon,
    dragonflies dart low over the swamp and pterosaurs circle the Sky Islands.

    Client-only and purely visual (anchored, no collisions or queries). An area wakes when the
    camera comes within CritterConfig.ActiveRange of it; sleeping areas keep their models
    parented to nil. Far animals update at a quarter rate.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Module = require(ReplicatedStorage.Shared.Module)
local DinoConfig = require(ReplicatedStorage.Config.DinoConfig)
local CritterConfig = require(ReplicatedStorage.Config.CritterConfig)
local CanyonMath = require(ReplicatedStorage.Shared.CanyonMath)
local DinoModels = require(ReplicatedStorage.ClientModules.DinoModels)

local HALF_X = 140              -- keep clear of the canyon walls
local EDGE_Z = 30               -- and of the area gates
local LAGOON_X = 70             -- Coral Coast water starts east of here
local MUTANTS = { "Golden", "Frost", "Cosmic" }

type Animal = {
    oModel: Model, sId: string, bCritter: boolean, tCfg: any,
    vPos: Vector3, vLook: Vector3, vTarget: Vector3,
    sState: string, nStateAt: number, nUntil: number,
    nSpeed: number, nPhase: number, nSeed: number, nHeight: number,
    bGrazer: boolean, sFly: string?, bWater: boolean,
    tIdle: any, tHerd: { vTarget: Vector3, nPicked: number }?, vHerdOffset: Vector3,
    nAlt: number, vCentre: Vector3, nRadius: number, nAngle: number,
    tWings: { { oPart: BasePart, cfRel: CFrame, nSide: number } }?, vWingJoint: Vector3?,
    nAccum: number,
}
type Area = { iIndex: number, sId: string, nZ0: number, nZ1: number, tAnimals: { Animal }, bBuilt: boolean, bAwake: boolean }

local tAreas: { Area } = {}
local oFolder: Folder
local oRandom = Random.new()
local oRayParams = RaycastParams.new()
oRayParams.FilterType = Enum.RaycastFilterType.Include

-- Ground under (x, z): height and whether it's water.
local function Ground(nX: number, nZ: number): (number, boolean)
    oRayParams.FilterDescendantsInstances = { Workspace.Terrain }
    local r = Workspace:Raycast(Vector3.new(nX, CanyonMath.RimY + 40, nZ), Vector3.new(0, -CanyonMath.RimY - 80, 0), oRayParams)
    if not r then return CanyonMath.FloorY, false end
    return r.Position.Y, r.Material == Enum.Material.Water
end

-- True when a canyon prop (rock, tree, bones, ice block...) stands on this spot, so nobody picks it as a goal.
local oPropParams = RaycastParams.new()
oPropParams.FilterType = Enum.RaycastFilterType.Include
local function Blocked(nX: number, nZ: number): boolean
    local oWorld = Workspace:FindFirstChild("World")
    local oCanyon = oWorld and oWorld:FindFirstChild("Canyon")
    if not oCanyon then return false end
    oPropParams.FilterDescendantsInstances = { oCanyon }
    return Workspace:Raycast(Vector3.new(nX, CanyonMath.RimY, nZ), Vector3.new(0, -CanyonMath.RimY - 20, 0), oPropParams) ~= nil
end

local function RandomPoint(tArea: Area, t: Animal): Vector3
    for _ = 1, 8 do
        local nMaxX = if tArea.sId == "CoralCoast" and not t.bWater then LAGOON_X - 6 else HALF_X
        local nMinX = if t.bWater then 30 else -HALF_X
        local nX = oRandom:NextNumber(nMinX, if t.bWater then 110 else nMaxX)
        local nZ = oRandom:NextNumber(tArea.nZ1 + EDGE_Z, tArea.nZ0 - EDGE_Z)
        local nY, bWet = Ground(nX, nZ)
        if (t.bWater or not bWet) and not Blocked(nX, nZ) then
            return Vector3.new(nX, nY, nZ)
        end
    end
    return t.vPos
end

-- Short stroll from where it is (keeps herds and grazers drifting rather than teleport-walking across the map).
local function NearbyPoint(tArea: Area, t: Animal, nRange: number): Vector3
    local v = t.vPos + Vector3.new(oRandom:NextNumber(-nRange, nRange), 0, oRandom:NextNumber(-nRange, nRange))
    local nMaxX = if tArea.sId == "CoralCoast" and not t.bWater then LAGOON_X - 6 else HALF_X
    local nX = math.clamp(v.X, if t.bWater then 30 else -HALF_X, if t.bWater then 110 else nMaxX)
    local nZ = math.clamp(v.Z, tArea.nZ1 + EDGE_Z, tArea.nZ0 - EDGE_Z)
    local nY, bWet = Ground(nX, nZ)
    if (bWet and not t.bWater) or Blocked(nX, nZ) then return RandomPoint(tArea, t) end
    return Vector3.new(nX, nY, nZ)
end

local function NewAnimal(tArea: Area, sId: string, bCritter: boolean): Animal?
    local tCfg, oModel
    if bCritter then
        tCfg = CritterConfig.Critters[sId]
        oModel = DinoModels.BuildCritter(sId, tCfg)
    else
        tCfg = DinoConfig.Species[sId]
        local sMutation = if oRandom:NextNumber() < CritterConfig.MutantChance then MUTANTS[oRandom:NextInteger(1, #MUTANTS)] else "Normal"
        local ok, o = pcall(DinoModels.Build, { Species = sId, Size = "Normal", Mutation = sMutation })
        oModel = ok and o or nil
    end
    if not oModel then return nil end
    oModel:ScaleTo(oModel:GetScale() * oRandom:NextNumber(0.85, 1.15))
    for _, o in oModel:GetDescendants() do
        if o:IsA("BillboardGui") then o:Destroy() end
    end
    oModel.Name = "Wild_" .. sId
    local nHeight = DinoModels.Height(oModel)
    local sFly = if bCritter then tCfg.Flies else (if tCfg.Archetype == "Flyer" then "Glide" else nil)
    local bGrazer = if bCritter then tCfg.Grazes == true
        else (CritterConfig.GrazingArchetypes[tCfg.Archetype] == true or CritterConfig.GrazingSpecies[sId] == true)
    local t: Animal = {
        oModel = oModel, sId = sId, bCritter = bCritter, tCfg = tCfg,
        vPos = Vector3.zero, vLook = Vector3.new(oRandom:NextNumber(-1, 1), 0, oRandom:NextNumber(-1, 1)), vTarget = Vector3.zero,
        sState = "Idle", nStateAt = 0, nUntil = 0,
        nSpeed = if bCritter then tCfg.Speed else math.clamp(2 + nHeight * 0.35, 2.5, 7),
        nPhase = oRandom:NextNumber(0, 6.28), nSeed = oRandom:NextNumber(0, 100), nHeight = nHeight,
        bGrazer = bGrazer, sFly = sFly, bWater = bCritter and tCfg.Water == true,
        tIdle = DinoModels.NewIdleState(), tHerd = nil, vHerdOffset = Vector3.zero,
        nAlt = 0, vCentre = Vector3.zero, nRadius = 30, nAngle = oRandom:NextNumber(0, 6.28),
        tWings = nil, vWingJoint = nil, nAccum = 0,
    }
    -- Dragonfly wings flap about the wing joint (model space), captured from the rest pose.
    local oJoint = oModel:FindFirstChild("Joint_Wings")
    if oJoint and oJoint:IsA("BasePart") then
        local cfPivot = oModel:GetPivot()
        t.vWingJoint = cfPivot:PointToObjectSpace(oJoint.Position)
        t.tWings = {}
        for _, o in oModel:GetChildren() do
            if o:IsA("BasePart") and o.Name:match("^Wing") then
                table.insert(t.tWings :: any, { oPart = o, cfRel = cfPivot:ToObjectSpace(o.CFrame), nSide = if o.Name == "WingL" then -1 else 1 })
            end
        end
    end
    t.vPos = RandomPoint(tArea, t)
    t.vTarget = t.vPos
    if sFly == "Glide" then
        t.nAlt = oRandom:NextNumber(16, 42)
        t.vCentre = t.vPos
        t.nRadius = oRandom:NextNumber(18, 45)
    elseif sFly == "Dart" then
        t.nAlt = oRandom:NextNumber(3, 8)
    end
    return t
end

local function BuildArea(tArea: Area)
    tArea.bBuilt = true
    local tBiome = DinoConfig.Biomes[tArea.iIndex]
    local tPlan = CritterConfig.Areas[tArea.sId] or { Dinos = 4 }
    -- Dinos: cycle through the area's three species (common first); sauropods count double.
    local nLeft, i = tPlan.Dinos or 0, 0
    while nLeft > 0 do
        local sSpecies = tBiome.Species[(i % #tBiome.Species) + 1]
        i += 1
        local tSpecies = DinoConfig.Species[sSpecies]
        nLeft -= if tSpecies and tSpecies.Archetype == "Sauropod" then 2 else 1
        local t = NewAnimal(tArea, sSpecies, false)
        if t then table.insert(tArea.tAnimals, t) end
    end
    for sCritter, nCount in tPlan.Critters or {} do
        local tCfg = CritterConfig.Critters[sCritter]
        local tHerd = if tCfg and tCfg.Herd then { vTarget = Vector3.zero, nPicked = 0 } else nil
        local tLeader: Animal? = nil
        for k = 1, nCount do
            local t = NewAnimal(tArea, sCritter, true)
            if t then
                if tHerd then
                    -- Herd: everyone starts and travels together, spaced out around a shared goal.
                    t.tHerd = tHerd
                    t.vHerdOffset = Vector3.new((k - 1) % 2 * 22 - 11, 0, math.floor((k - 1) / 2) * 19) + Vector3.new(oRandom:NextNumber(-2, 2), 0, oRandom:NextNumber(-2, 2))
                    if tLeader then
                        local vStart = tLeader.vPos + t.vHerdOffset
                        t.vPos = Vector3.new(vStart.X, Ground(vStart.X, vStart.Z), vStart.Z)
                    else
                        tLeader = t
                        tHerd.vTarget = t.vPos
                    end
                end
                table.insert(tArea.tAnimals, t)
            end
        end
    end
end

-- Next thing to do once a walk ends (or a rest is over).
local function NextState(tArea: Area, t: Animal, nNow: number)
    t.nStateAt = nNow
    if t.sState ~= "Walk" then
        t.sState = "Walk"
        if t.tHerd then
            -- The first herd member to finish resting picks the next spot for everyone.
            if nNow - t.tHerd.nPicked > 10 then
                t.tHerd.vTarget = NearbyPoint(tArea, t, 90)
                t.tHerd.nPicked = nNow
            end
            local v = t.tHerd.vTarget + t.vHerdOffset
            t.vTarget = Vector3.new(v.X, Ground(v.X, v.Z), v.Z)
        else
            t.vTarget = if oRandom:NextNumber() < 0.7 then NearbyPoint(tArea, t, 45) else RandomPoint(tArea, t)
        end
        t.nUntil = nNow + 40
        return
    end
    local r = oRandom:NextNumber()
    if t.bGrazer and r < 0.65 then
        t.sState, t.nUntil = "Graze", nNow + oRandom:NextNumber(5, 12)
    elseif not t.bGrazer and r < 0.12 then
        t.sState, t.nUntil = "Roar", nNow + 1.3
    else
        t.sState, t.nUntil = "Idle", nNow + oRandom:NextNumber(3, 8)
        t.tIdle = DinoModels.NewIdleState()
    end
end

local function FlapWings(t: Animal, nNow: number)
    if not (t.tWings and t.vWingJoint) then return end
    local cfPivot = t.oModel:GetPivot()
    local j = t.vWingJoint
    local nFlap = math.sin(nNow * 55 + t.nSeed) * 0.45
    for _, w in t.tWings do
        -- The model faces -Z, so flapping is a roll about Z.
        w.oPart.CFrame = cfPivot * CFrame.new(j) * CFrame.Angles(0, 0, w.nSide * -nFlap) * CFrame.new(-j) * w.cfRel
    end
end

local function UpdateGlider(t: Animal, nDt: number, nNow: number)
    t.nAngle += nDt * (t.nSpeed * 2.2) / t.nRadius
    if nNow > t.nUntil then
        -- Drift the circle somewhere new now and then.
        t.nUntil = nNow + oRandom:NextNumber(10, 20)
        t.vTarget = Vector3.new(t.vCentre.X + oRandom:NextNumber(-60, 60), 0, t.vCentre.Z + oRandom:NextNumber(-60, 60))
    end
    t.vCentre = t.vCentre:Lerp(Vector3.new(math.clamp(t.vTarget.X, -HALF_X, HALF_X), 0, t.vTarget.Z), math.min(1, nDt * 0.15))
    local vPos = Vector3.new(t.vCentre.X + math.cos(t.nAngle) * t.nRadius, CanyonMath.FloorY + t.nAlt + math.sin(nNow * 0.8 + t.nSeed) * 2,
        t.vCentre.Z + math.sin(t.nAngle) * t.nRadius)
    local vLook = Vector3.new(-math.sin(t.nAngle), 0, math.cos(t.nAngle))
    t.vPos, t.vLook = vPos, vLook
    DinoModels.PlaceAt(t.oModel, vPos, vLook)
    -- The plush flyers are built standing up: bank into the turn, then tip them forward (belly
    -- down, head first) so they glide instead of hanging upright, nose bobbing with each beat.
    t.oModel:PivotTo(t.oModel:GetPivot() * CFrame.Angles(0, 0, 0.32) * CFrame.Angles(-1.05 + math.sin(nNow * 2 + t.nSeed) * 0.06, 0, 0))
end

local function UpdateDarter(tArea: Area, t: Animal, nDt: number, nNow: number)
    if nNow > t.nUntil then
        if t.sState == "Hover" then
            t.sState = "Dart"
            local v = NearbyPoint(tArea, t, 35)
            t.vTarget = v
            t.nAlt = oRandom:NextNumber(3, 9)
            t.nUntil = nNow + 6
        else
            t.sState = "Hover"
            t.nUntil = nNow + oRandom:NextNumber(0.8, 3)
        end
    end
    local vFlat = Vector3.new(t.vTarget.X - t.vPos.X, 0, t.vTarget.Z - t.vPos.Z)
    if t.sState == "Dart" and vFlat.Magnitude > 1 then
        t.vPos += vFlat.Unit * math.min(vFlat.Magnitude, t.nSpeed * nDt)
        t.vLook = t.vLook:Lerp(vFlat.Unit, math.min(1, nDt * 10))
    elseif t.sState == "Dart" then
        t.nUntil = 0
    end
    local nY = Ground(t.vPos.X, t.vPos.Z) + t.nAlt + math.sin(nNow * 3 + t.nSeed) * 0.4
    DinoModels.PlaceAt(t.oModel, Vector3.new(t.vPos.X, nY, t.vPos.Z), t.vLook)
    FlapWings(t, nNow)
end

local function UpdateWalker(tArea: Area, t: Animal, nDt: number, nNow: number)
    if nNow >= t.nUntil and t.sState ~= "Walk" then
        NextState(tArea, t, nNow)
    end
    if t.sState == "Walk" then
        local vFlat = Vector3.new(t.vTarget.X - t.vPos.X, 0, t.vTarget.Z - t.vPos.Z)
        local nDist = vFlat.Magnitude
        if nDist < 1.2 or nNow >= t.nUntil then
            NextState(tArea, t, nNow)
        else
            local vDir = vFlat.Unit
            -- Turn first (on the spot when facing away), then walk.
            t.vLook = t.vLook:Lerp(vDir, math.min(1, nDt * 2.5))
            local nFacing = math.max(0, t.vLook.Unit:Dot(vDir))
            local nStep = t.nSpeed * nDt * nFacing
            local vNext = t.vPos + vDir * math.min(nDist, nStep)
            local nY, bWet = Ground(vNext.X, vNext.Z)
            if bWet and t.bWater then nY -= t.nHeight * 0.35 end   -- turtles swim low in the water
            t.vPos = Vector3.new(vNext.X, t.vPos.Y + (nY - t.vPos.Y) * math.min(1, nDt * 8), vNext.Z)
            t.nPhase += nStep / math.max(t.nHeight * 0.18, 0.4)
            local nBob = math.abs(math.sin(t.nPhase)) * t.nHeight * 0.025
            DinoModels.PlaceAt(t.oModel, t.vPos + Vector3.new(0, nBob, 0), t.vLook)
            DinoModels.Pose(t.oModel, t.nPhase, 0.45)
            DinoModels.WalkArticulate(t.oModel, t.nPhase)
            return
        end
    end
    DinoModels.PlaceAt(t.oModel, t.vPos, t.vLook)
    if t.sState == "Graze" then
        DinoModels.Graze(t.oModel, t.vPos, t.vLook, nNow - t.nStateAt, t.nSeed)
    elseif t.sState == "Roar" then
        -- Skip the catch-reveal pop out of the ground: straight to rearing up and roaring.
        DinoModels.Roar(t.oModel, t.vPos, t.vLook, 0.65 + (nNow - t.nStateAt))
    else
        DinoModels.Idle(t.oModel, t.vPos, t.vLook, t.tIdle)
    end
end

local function SetAwake(tArea: Area, bAwake: boolean)
    if tArea.bAwake == bAwake then return end
    tArea.bAwake = bAwake
    if bAwake and not tArea.bBuilt then BuildArea(tArea) end
    for _, t in tArea.tAnimals do
        t.oModel.Parent = if bAwake then oFolder else nil
    end
end

local mWildlife = Module()

function mWildlife.StartAsync(self)
    oFolder = Instance.new("Folder")
    oFolder.Name = "Wildlife"
    oFolder.Parent = Workspace
    for i, tBiome in DinoConfig.Biomes do
        local nZ0 = CanyonMath.CanyonStartZ - (i - 1) * CanyonMath.BiomeLength
        table.insert(tAreas, { iIndex = i, sId = tBiome.Id, nZ0 = nZ0, nZ1 = nZ0 - CanyonMath.BiomeLength, tAnimals = {}, bBuilt = false, bAwake = false })
    end
    -- Wait for the critter models (loaded by the server's AssetLoader) so areas aren't built without them.
    local oAssets = ReplicatedStorage:WaitForChild("Assets", 30)
    local oCritters = oAssets and oAssets:WaitForChild("Critters", 30)
    if oCritters then
        local nStart = os.clock()
        local nWant = 0
        for _ in CritterConfig.Critters do nWant += 1 end
        while #oCritters:GetChildren() < nWant and os.clock() - nStart < 15 do
            task.wait(0.5)
        end
    end
    local nLastWake = 0
    RunService.Heartbeat:Connect(function(nDt)
        local oCamera = Workspace.CurrentCamera
        if not oCamera then return end
        local vCam = oCamera.CFrame.Position
        local nNow = os.clock()
        if nNow - nLastWake > 0.5 then
            nLastWake = nNow
            for _, tArea in tAreas do
                local nDz = if vCam.Z > tArea.nZ0 then vCam.Z - tArea.nZ0 elseif vCam.Z < tArea.nZ1 then tArea.nZ1 - vCam.Z else 0
                SetAwake(tArea, nDz < CritterConfig.ActiveRange)
            end
        end
        for _, tArea in tAreas do
            if tArea.bAwake then
                for _, t in tArea.tAnimals do
                    -- Far animals: a quarter of the updates (they still move the same distance).
                    t.nAccum += nDt
                    local bNear = (t.vPos - vCam).Magnitude < CritterConfig.DetailRange
                    if bNear or t.nAccum >= 0.25 then
                        local nStep = t.nAccum
                        t.nAccum = 0
                        if t.sFly == "Glide" then
                            UpdateGlider(t, nStep, nNow)
                        elseif t.sFly == "Dart" then
                            UpdateDarter(tArea, t, nStep, nNow)
                        else
                            UpdateWalker(tArea, t, nStep, nNow)
                        end
                    end
                end
            end
        end
    end)
end

return mWildlife
