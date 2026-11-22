--[[
    WorldBuilder
    ------------
    Builds the launch rim, the five-biome canyon, plots, training pads and
    shop pedestals from WorldLayout/CanyonMath at server start, so the world
    is version-controlled with the code (Rojo does not sync Workspace).

    TEMPORARY ART: every generated prop is a primitive stand-in named with a
    TEMP_ prefix and tracked in Docs/TEMP_ART.md. The Blender kit replaces
    them by dropping models into ReplicatedStorage.Assets.World.<Name>;
    PlaceProp() prefers a real asset over the stand-in.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Module = require(ReplicatedStorage.Shared.Module)
local CanyonMath = require(ReplicatedStorage.Shared.CanyonMath)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local DinoConfig = require(ReplicatedStorage.Config.DinoConfig)
local ShopConfig = require(ReplicatedStorage.Config.ShopConfig)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Format = require(ReplicatedStorage.Shared.Format)

local INK = Color3.fromHex("1E1B2E")

local oWorld: Folder
local oRandom = Random.new(20261122)

local function Part(tProps: { [string]: any }): BasePart
    local sClass = tProps.ClassName or "Part"
    local oPart = Instance.new(sClass) :: BasePart
    oPart.Anchored = true
    oPart.TopSurface = Enum.SurfaceType.Smooth
    oPart.BottomSurface = Enum.SurfaceType.Smooth
    oPart.Material = Enum.Material.SmoothPlastic
    for k, v in tProps do
        if k ~= "ClassName" and k ~= "Parent" then
            (oPart :: any)[k] = v
        end
    end
    oPart.Parent = tProps.Parent or oWorld
    return oPart
end

local function Folder(sName: string, oParent: Instance): Folder
    local o = Instance.new("Folder")
    o.Name = sName
    o.Parent = oParent
    return o
end

local function Label(oParent: BasePart, sText: string, nSize: number, cColor: Color3?, vOffset: Vector3?): BillboardGui
    local oBillboard = Instance.new("BillboardGui")
    oBillboard.Size = UDim2.fromOffset(nSize * 9, nSize * 2.2)
    oBillboard.StudsOffsetWorldSpace = vOffset or Vector3.new(0, 6, 0)
    oBillboard.AlwaysOnTop = false
    oBillboard.MaxDistance = 260
    oBillboard.LightInfluence = 0
    local oText = Instance.new("TextLabel")
    oText.BackgroundTransparency = 1
    oText.Size = UDim2.fromScale(1, 1)
    oText.Font = Enum.Font.FredokaOne
    oText.TextScaled = true
    oText.TextColor3 = cColor or Color3.new(1, 1, 1)
    oText.Text = sText
    oText.Name = "Text"
    local oStroke = Instance.new("UIStroke")
    oStroke.Color = INK
    oStroke.Thickness = 3
    oStroke.Parent = oText
    oText.Parent = oBillboard
    oBillboard.Parent = oParent
    return oBillboard
end

-- Colour + material per mesh role name exported by Assets/Blender/scripts/world_props.py.
local PROP_ROLES = {
    Trunk = { Color3.fromHex("8B5A2B"), Enum.Material.SmoothPlastic },
    Leaves = { Color3.fromHex("2FB344"), Enum.Material.SmoothPlastic },
    Leaves2 = { Color3.fromHex("7CC63A"), Enum.Material.SmoothPlastic },
    Rock = { Color3.fromHex("A38B76"), Enum.Material.SmoothPlastic },
    RockDark = { Color3.fromHex("3B2E2A"), Enum.Material.SmoothPlastic },
    Ice = { Color3.fromHex("A8DDF5"), Enum.Material.Glass },
    Snow = { Color3.fromHex("F7FBFF"), Enum.Material.SmoothPlastic },
    Lava = { Color3.fromHex("FF6A1A"), Enum.Material.Neon },
    Glow = { Color3.fromHex("5EC8F2"), Enum.Material.Neon },
    Water = { Color3.fromHex("4FB8E8"), Enum.Material.Glass },
    Wood = { Color3.fromHex("A0703F"), Enum.Material.SmoothPlastic },
    Band = { Color3.fromHex("E53950"), Enum.Material.SmoothPlastic },
    Stone = { Color3.fromHex("F4F1EA"), Enum.Material.SmoothPlastic },
    Gold = { Color3.fromHex("FFC531"), Enum.Material.SmoothPlastic },
    Bait = { Color3.fromHex("D81B60"), Enum.Material.SmoothPlastic },
    BaitAccent = { Color3.fromHex("43A047"), Enum.Material.SmoothPlastic },
}

-- Applies role colours; tOverrides[role] = Color3 recolours a role (e.g. slingshot tiers, biome leaves).
local function ColourProp(oModel: Model, tOverrides: { [string]: Color3 }?)
    for _, o in oModel:GetDescendants() do
        if o:IsA("BasePart") then
            local tRole = PROP_ROLES[o.Name]
            if tRole then
                o.Color = (tOverrides and tOverrides[o.Name]) or tRole[1]
                o.Material = tRole[2]
                if o.Name == "Ice" or o.Name == "Water" then
                    o.Transparency = 0.25
                end
            end
            o.TopSurface = Enum.SurfaceType.Smooth
            o.BottomSurface = Enum.SurfaceType.Smooth
        end
    end
end

-- Places a real asset from ReplicatedStorage.Assets.World if present; otherwise builds the TEMP stand-in.
local function PlaceProp(sAsset: string, cf: CFrame, nScale: number, fnTemp: (Model) -> (), tOverrides: { [string]: Color3 }?): Model
    local oAssets = ReplicatedStorage:FindFirstChild("Assets")
    local oWorldAssets = oAssets and oAssets:FindFirstChild("World")
    local oTemplate = oWorldAssets and oWorldAssets:FindFirstChild(sAsset)
    local oModel: Model
    if oTemplate and oTemplate:IsA("Model") then
        oModel = oTemplate:Clone()
        ColourProp(oModel, tOverrides)
        oModel:ScaleTo(nScale)
        oModel:PivotTo(cf)
    else
        oModel = Instance.new("Model")
        oModel.Name = "TEMP_" .. sAsset
        fnTemp(oModel)
        oModel:ScaleTo(nScale)
        oModel:PivotTo(cf)
    end
    oModel.Parent = oWorld
    return oModel
end

local function TempTree(cTrunk: Color3, cLeaves: Color3, nHeight: number)
    return function(oModel: Model)
        local oTrunk = Part({ Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(nHeight, 2.2, 2.2), CFrame = CFrame.new(0, nHeight / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = cTrunk, Parent = oModel })
        Part({ Name = "Canopy", Shape = Enum.PartType.Ball, Size = Vector3.one * (nHeight * 0.8), CFrame = CFrame.new(0, nHeight + nHeight * 0.2, 0), Color = cLeaves, Parent = oModel })
        oModel.PrimaryPart = oTrunk
    end
end

local function TempRock(cColor: Color3)
    return function(oModel: Model)
        local o = Part({ Name = "Rock", Size = Vector3.new(6, 4, 5), CFrame = CFrame.Angles(0, oRandom:NextNumber(0, 6), 0.2), Color = cColor, Material = Enum.Material.Slate, Parent = oModel })
        oModel.PrimaryPart = o
    end
end

local function BuildRim()
    local oRim = Folder("Rim", oWorld)
    local nY = CanyonMath.RimY
    local vMin = Vector3.new(WorldLayout.RimMinX, 0, WorldLayout.RimMinZ)
    local vMax = Vector3.new(WorldLayout.RimMaxX, nY, WorldLayout.RimMaxZ)
    Part({ Name = "TEMP_RimGround", Size = vMax - vMin, Position = (vMin + vMax) / 2, Color = Color3.fromHex("8BD650"), Material = Enum.Material.Grass, Parent = oRim })
    -- Cliff face down into the canyon
    Part({ Name = "TEMP_RimCliff", Size = Vector3.new(vMax.X - vMin.X, nY, 4), Position = Vector3.new(0, nY / 2, vMin.Z - 2), Color = Color3.fromHex("A0703F"), Material = Enum.Material.Sandstone, Parent = oRim })
    -- Low safety rail along the edge, with gaps in front of each launch stand
    for i = 1, GameConfig.PlotCount + 1 do
        local nX = -176 + (i - 1) * WorldLayout.PlotSpacing - WorldLayout.PlotSpacing / 2
        Part({ Name = "TEMP_Rail", Size = Vector3.new(22, 2.5, 1.5), Position = Vector3.new(nX, nY + 1.25, vMin.Z + 1), Color = Color3.fromHex("8B5A2B"), Material = Enum.Material.Wood, Parent = oRim })
    end
    -- Back decoration
    for _ = 1, 18 do
        local vPos = Vector3.new(oRandom:NextNumber(-195, 195), nY, oRandom:NextNumber(125, 148))
        PlaceProp("JungleTree", CFrame.new(vPos), oRandom:NextNumber(0.9, 1.4), TempTree(Color3.fromHex("8B5A2B"), Color3.fromHex("2FB344"), 14))
    end
end

local tBiomeLook = {
    Jungle = { Floor = "4CC14A", Wall = "7A5230", Prop = "JungleTree", Trunk = "8B5A2B", Leaves = "1FA82F", Material = Enum.Material.Grass },
    Swamp = { Floor = "5C7A2E", Wall = "4F5A2A", Prop = "SwampTree", Trunk = "4E3B24", Leaves = "6B8E23", Material = Enum.Material.Mud },
    TarPits = { Floor = "4A3B33", Wall = "3A2F2A", Prop = "TarRock", Trunk = "2A211D", Leaves = "5A4A40", Material = Enum.Material.Ground },
    IceAge = { Floor = "E8F6FF", Wall = "A9DDF5", Prop = "IceBlock", Trunk = "BFE9FF", Leaves = "FFFFFF", Material = Enum.Material.Snow },
    Volcano = { Floor = "5A2A1E", Wall = "3B1A14", Prop = "LavaRock", Trunk = "2A140F", Leaves = "FF6A1A", Material = Enum.Material.Basalt },
}

local function BuildCanyon()
    local oCanyon = Folder("Canyon", oWorld)
    local nHalf = CanyonMath.CanyonHalfWidth
    local nLen = CanyonMath.BiomeLength
    for i, tBiome in DinoConfig.Biomes do
        local tLook = tBiomeLook[tBiome.Id]
        local oBiome = Folder(tBiome.Id, oCanyon)
        local nZ0 = CanyonMath.CanyonStartZ - (i - 1) * nLen
        local nMidZ = nZ0 - nLen / 2
        Part({ Name = "TEMP_Floor", Size = Vector3.new(nHalf * 2, 4, nLen), Position = Vector3.new(0, CanyonMath.FloorY - 2, nMidZ), Color = Color3.fromHex(tLook.Floor), Material = tLook.Material, Parent = oBiome })
        local nWallHeight = 110 + i * 12
        for _, nSide in { -1, 1 } do
            Part({ Name = "TEMP_Wall", Size = Vector3.new(24, nWallHeight, nLen), Position = Vector3.new(nSide * (nHalf + 12), nWallHeight / 2 - 4, nMidZ), Color = Color3.fromHex(tLook.Wall), Material = Enum.Material.Rock, Parent = oBiome })
        end
        -- Biome gate: an arch of two pillars + a floating sign readable from the rim
        if i > 1 then
            for _, nSide in { -1, 1 } do
                Part({ Name = "TEMP_GatePillar", Size = Vector3.new(10, 70, 10), Position = Vector3.new(nSide * (nHalf - 10), 35, nZ0), Color = tBiome.Color, Material = Enum.Material.Neon, Parent = oBiome })
            end
            local oSign = Part({ Name = "GateSign", Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false, Position = Vector3.new(0, 70, nZ0), Parent = oBiome })
            local oBillboard = Label(oSign, `{tBiome.Name}\n{Format.Meters(tBiome.MinMeters)}`, 36, Color3.new(1, 1, 1), Vector3.zero)
            -- Sized in studs (scale) so distant gates shrink naturally but stay readable from the rim.
            oBillboard.MaxDistance = 3000
            oBillboard.Size = UDim2.fromScale(110, 50)
        end
        -- Props
        for _ = 1, 26 do
            local vPos = Vector3.new(oRandom:NextNumber(-nHalf + 15, nHalf - 15), CanyonMath.FloorY, nZ0 - oRandom:NextNumber(20, nLen - 20))
            if math.abs(vPos.X) > 25 then
                local cfProp = CFrame.new(vPos) * CFrame.Angles(0, oRandom:NextNumber(0, 6.28), 0)
                if tBiome.Id == "Jungle" or tBiome.Id == "Swamp" then
                    PlaceProp(tLook.Prop, cfProp, oRandom:NextNumber(1.6, 3), TempTree(Color3.fromHex(tLook.Trunk), Color3.fromHex(tLook.Leaves), 16)).Parent = oBiome
                else
                    PlaceProp(tLook.Prop, cfProp, oRandom:NextNumber(2.5, 6), TempRock(Color3.fromHex(tLook.Leaves))).Parent = oBiome
                end
            end
        end
        -- Geysers: visual bounce vents along the floor (the actual bounce timing is server-planned)
        for _ = 1, 6 do
            local vPos = Vector3.new(oRandom:NextNumber(-nHalf + 30, nHalf - 30), CanyonMath.FloorY, nZ0 - oRandom:NextNumber(30, nLen - 30))
            PlaceProp("GeyserVent", CFrame.new(vPos), 2.2, function(oModel)
                Part({ Name = "Glow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 10, 10), CFrame = CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromHex("5EC8F2"), Material = Enum.Material.Neon, Parent = oModel })
            end).Parent = oBiome
        end
    end
    -- Hero volcano at the far end, with a glowing crater and lava streams visible from the rim.
    local nEndZ = CanyonMath.CanyonEndZ
    local oVolcano = PlaceProp("Volcano", CFrame.new(0, CanyonMath.FloorY, nEndZ - 150), 3.4, function(oModel)
        for iLayer = 0, 7 do
            local nRadius = 200 - iLayer * 22
            Part({ Name = "RockDark", Shape = Enum.PartType.Cylinder, Size = Vector3.new(22, nRadius * 2, nRadius * 2), CFrame = CFrame.new(0, iLayer * 22 + 11, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromHex("3B1A14"), Material = Enum.Material.Basalt, Parent = oModel })
        end
        Part({ Name = "Lava", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 50, 50), CFrame = CFrame.new(0, 177, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromHex("FF6A1A"), Material = Enum.Material.Neon, Parent = oModel })
    end)
    oVolcano.Parent = oCanyon
    local _, vVolcanoSize = oVolcano:GetBoundingBox()
    local oGlow = Part({ Name = "CraterGlow", Size = Vector3.one, Transparency = 1, CanCollide = false, Position = oVolcano:GetPivot().Position + Vector3.new(0, vVolcanoSize.Y + 10, 0), Parent = oCanyon })
    local oLight = Instance.new("PointLight")
    oLight.Range = 60
    oLight.Brightness = 5
    oLight.Color = Color3.fromHex("FF6A1A")
    oLight.Parent = oGlow
end

local function BuildPlots()
    local oPlots = Folder("Plots", oWorld)
    for i = 1, GameConfig.PlotCount do
        local tPlot = WorldLayout.Plot(i)
        local oPlot = Instance.new("Model")
        oPlot.Name = "Plot" .. i
        oPlot:SetAttribute("PlotIndex", i)
        local vSize = tPlot.Size
        local oFloor = Part({ Name = "Floor", Size = Vector3.new(vSize.X, 1, vSize.Z), Position = tPlot.Center + Vector3.new(0, 0.5, 0), Color = Color3.fromHex("C8E86A"), Material = Enum.Material.Grass, Parent = oPlot })
        oPlot.PrimaryPart = oFloor
        -- Fence
        local cFence = Color3.fromHex("8B5A2B")
        for _, t in {
            { Vector3.new(vSize.X, 3, 1), Vector3.new(0, 2, vSize.Z / 2) },
            { Vector3.new(1, 3, vSize.Z), Vector3.new(-vSize.X / 2, 2, 0) },
            { Vector3.new(1, 3, vSize.Z), Vector3.new(vSize.X / 2, 2, 0) },
            { Vector3.new(vSize.X / 2 - 6, 3, 1), Vector3.new(-vSize.X / 4 - 3, 2, -vSize.Z / 2) },
            { Vector3.new(vSize.X / 2 - 6, 3, 1), Vector3.new(vSize.X / 4 + 3, 2, -vSize.Z / 2) },
        } do
            Part({ Name = "Fence", Size = t[1], Position = tPlot.Center + t[2], Color = cFence, Material = Enum.Material.Wood, CanCollide = true, Parent = oPlot })
        end
        -- Launch stand: the giant slingshot (Blender), set to one side so the player stands in front of it.
        local vStand = tPlot.LaunchStand
        Part({ Name = "LaunchPad", Size = Vector3.new(10, 1, 8), Position = vStand + Vector3.new(0, 0.5, 0), Color = Color3.fromHex("FFC531"), Material = Enum.Material.SmoothPlastic, Parent = oPlot })
        PlaceProp("LaunchSlingshot", CFrame.new(vStand + Vector3.new(0, 1, 3.5)), 0.9, function(oModel)
            Part({ Name = "Wood", Size = Vector3.new(1.2, 6, 1.2), CFrame = CFrame.new(0, 3, 0), Parent = oModel })
        end).Parent = oPlot
        local oSign = Part({ Name = "OwnerSign", Size = Vector3.new(14, 4, 1), Position = tPlot.Center + Vector3.new(0, 6, vSize.Z / 2 + 1), Color = INK, Parent = oPlot })
        local oSurface = Instance.new("SurfaceGui")
        oSurface.Face = Enum.NormalId.Back
        oSurface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
        oSurface.PixelsPerStud = 30
        oSurface.LightInfluence = 0
        local oText = Instance.new("TextLabel")
        oText.Name = "Text"
        oText.Size = UDim2.fromScale(1, 1)
        oText.BackgroundTransparency = 1
        oText.Font = Enum.Font.FredokaOne
        oText.TextScaled = true
        oText.TextColor3 = Color3.new(1, 1, 1)
        oText.Text = "Empty Plot"
        oText.Parent = oSurface
        oSurface.Parent = oSign
        local oDinos = Instance.new("Folder")
        oDinos.Name = "Dinos" -- clients render dino models here
        oDinos.Parent = oPlot
        oPlot.Parent = oPlots
    end
end

local function BuildTraining()
    local oTraining = Folder("Training", oWorld)
    for i, tPad in ShopConfig.Pads do
        local vPos = WorldLayout.Pad(i)
        local oPad = Part({ Name = "Pad" .. i, Size = WorldLayout.PadSize, Position = vPos + Vector3.new(0, 0.5, 0), Color = tPad.Color, Material = Enum.Material.Neon, Parent = oTraining })
        oPad:SetAttribute("PadIndex", i)
        local sReq = if tPad.RequiredPower > 0 then `\nNeeds {Format.Number(tPad.RequiredPower)} Power` else ""
        Label(oPad, `{tPad.Name}\n+{Format.Number(tPad.PowerPerTick)} Power/s{sReq}`, 22, Color3.fromHex("FFE14D"), Vector3.new(0, 7, 0))
    end
    local oSign = Part({ Name = "TrainingSign", Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false, Position = WorldLayout.TrainingSign + Vector3.new(0, 14, 0), Parent = oTraining })
    Label(oSign, "TRAINING", 40, Color3.fromHex("FFE14D"), Vector3.zero)
end

local function BuildPedestals()
    local oShop = Folder("Shop", oWorld)
    local function Pedestal(sKind: string, i: number, tItem, vPos: Vector3, cColor: Color3)
        local oModel = Instance.new("Model")
        oModel.Name = `{sKind}_{tItem.Id}`
        oModel:SetAttribute("Kind", sKind)
        oModel:SetAttribute("ItemId", tItem.Id)
        oModel:SetAttribute("Tier", i)
        local oBase = Part({ Name = "Base", Size = Vector3.new(10, 4, 10), Position = vPos + Vector3.new(0, 2, 0), Color = Color3.fromHex("F4F1EA"), Material = Enum.Material.SmoothPlastic, Parent = oModel })
        oModel.PrimaryPart = oBase
        -- Display item (Blender): slingshots share one model recoloured per tier; each bait has its own model.
        local sAsset = if sKind == "Bait" then "Bait_" .. tItem.Id else "SlingshotItem"
        local tTint = if sKind == "Slingshot" then { Wood = cColor } else nil
        local oItem = PlaceProp(sAsset, CFrame.new(vPos + Vector3.new(0, 4.5, 0)), if sKind == "Bait" then 2 else 1.6, function(oTemp)
            Part({ Name = "Bait", Shape = if sKind == "Bait" then Enum.PartType.Ball else Enum.PartType.Block, Size = if sKind == "Bait" then Vector3.one * 3.5 else Vector3.new(1.2, 5, 3.5),
                CFrame = CFrame.new(0, 2, 0), Color = cColor, Parent = oTemp })
        end, tTint)
        for _, o in oItem:GetDescendants() do
            if o:IsA("BasePart") then o.CanCollide = false end
        end
        oItem.Name = "Item"
        oItem:SetAttribute("Spin", true)
        oItem.Parent = oModel
        local oPrompt = Instance.new("ProximityPrompt")
        oPrompt.ActionText = "View"
        oPrompt.ObjectText = tItem.Name
        oPrompt.KeyboardKeyCode = Enum.KeyCode.E
        oPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
        oPrompt.HoldDuration = 0
        oPrompt.MaxActivationDistance = 12
        oPrompt.RequiresLineOfSight = false
        oPrompt.Style = Enum.ProximityPromptStyle.Default
        oPrompt.Parent = oBase
        local sPrice = if tItem.Price > 0 then Format.Cash(tItem.Price) else "FREE"
        local sStat = if sKind == "Bait" then `{tItem.Luck}x Luck` else `{tItem.Multiplier}x Distance`
        local oLabel = Label(oBase, `{tItem.Name}\n{sStat}\n{sPrice}`, 20, Color3.new(1, 1, 1), Vector3.new(0, 12, 0))
        -- Sized in studs (not pixels) so neighbouring pedestal signs never overlap at a distance.
        oLabel.Size = UDim2.fromScale(15, 6.5)
        oLabel.MaxDistance = 90
        oModel.Parent = oShop
    end
    local tSlingColors = { "8B5A2B", "9CCC65", "F5F5DC", "3A2F2A", "D7CCC8", "263238", "8E44FF" }
    for i, tItem in ShopConfig.Slingshots do
        Pedestal("Slingshot", i, tItem, WorldLayout.SlingshotPedestal(i), Color3.fromHex(tSlingColors[i] or "FFFFFF"))
    end
    for i, tItem in ShopConfig.Bait do
        Pedestal("Bait", i, tItem, WorldLayout.BaitPedestal(i), tItem.Color)
    end
    local oSlingSign = Part({ Name = "SlingshotSign", Size = Vector3.one, Transparency = 1, CanCollide = false, Position = WorldLayout.SlingshotPedestal(4) + Vector3.new(0, 22, 0), Parent = oShop })
    Label(oSlingSign, "SLINGSHOTS", 36, Color3.fromHex("3DDC4E"), Vector3.zero)
    local oBaitSign = Part({ Name = "BaitSign", Size = Vector3.one, Transparency = 1, CanCollide = false, Position = WorldLayout.BaitPedestal(3.5) + Vector3.new(0, 22, 0), Parent = oShop })
    Label(oBaitSign, "BAIT", 36, Color3.fromHex("FFA62B"), Vector3.zero)
end

local mWorldBuilder = Module()

function mWorldBuilder.PreloadAsync(self)
    -- Real Blender assets first, so PlaceProp uses them instead of TEMP stand-ins.
    local nStart = os.clock()
    require(script.Parent.AssetLoader).LoadAll(6)
    print(string.format("[WorldBuilder] assets ready in %.1fs", os.clock() - nStart))
    local oExisting = Workspace:FindFirstChild("World")
    if oExisting then
        oExisting:Destroy()
    end
    oWorld = Instance.new("Folder")
    oWorld.Name = "World"
    BuildRim()
    BuildCanyon()
    BuildPlots()
    BuildTraining()
    BuildPedestals()
    oWorld.Parent = Workspace
    -- Remove Studio's default baseplate/spawn so players only spawn on plots.
    for _, sName in { "Baseplate", "SpawnLocation" } do
        local o = Workspace:FindFirstChild(sName)
        if o then o:Destroy() end
    end
end

function mWorldBuilder.GetPlotModel(self, iPlot: number): Model?
    local oPlots = oWorld and oWorld:FindFirstChild("Plots")
    return oPlots and oPlots:FindFirstChild("Plot" .. iPlot) :: Model?
end

return mWorldBuilder
