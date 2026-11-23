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
    Leather = { Color3.fromHex("7A4A2A"), Enum.Material.SmoothPlastic },
    Pouch = { Color3.fromHex("8A5530"), Enum.Material.SmoothPlastic },
}

-- Applies role colours; tOverrides[role] = Color3 recolours a role (e.g. slingshot tiers, biome leaves).
local function ColourProp(oModel: Model, tOverrides: { [string]: Color3 }?)
    for _, o in oModel:GetDescendants() do
        if o:IsA("BasePart") then
            -- Blender may suffix duplicate names ("Rock.003"); the role is the base name.
            local sRole = o.Name:gsub("%.%d+$", "")
            o.Name = sRole
            -- Hidden anchor markers (slingshot band tips and pouch centre).
            if sRole == "TipL" or sRole == "TipR" or sRole == "PouchMark" then
                o.Transparency = 1
                o.CanCollide = false
                o.CastShadow = false
            end
            local tRole = PROP_ROLES[sRole]
            if tRole then
                o.Color = (tOverrides and tOverrides[sRole]) or tRole[1]
                o.Material = tRole[2]
                if sRole == "Ice" or sRole == "Water" then
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
    -- Terrain voxels are 4 studs and the grass surface renders ~2 studs above the fill top,
    -- so fill to RimY - 2 to put the walkable surface at RimY (where props and dinos are placed).
    local vMax = Vector3.new(WorldLayout.RimMaxX, nY - 2, WorldLayout.RimMaxZ)
    -- Rim plateau as terrain grass (soft, textured, cheap) instead of a flat part.
    Workspace.Terrain:FillBlock(CFrame.new((vMin + vMax) / 2), vMax - vMin, Enum.Material.Grass)
    -- Cliff face down into the canyon: Blender cliff modules with an invisible collider behind them.
    local oCliffCollider = Part({ Name = "RimCliffCollider", Size = Vector3.new(vMax.X - vMin.X, nY, 4), Position = Vector3.new(0, nY / 2, vMin.Z - 2), Color = Color3.fromHex("A0703F"), Material = Enum.Material.Sandstone, Parent = oRim })
    if ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets.World:FindFirstChild("CliffWall") then
        oCliffCollider.Transparency = 1
        local tTint = { Rock = Color3.fromHex("B8875A"), RockDark = Color3.fromHex("8A5E3B"), Leaves = Color3.fromHex("6CC24A") }
        for k = 0, 10 do
            local vPos = Vector3.new(-200 + k * 40, nY - 74, vMin.Z - 8)
            PlaceProp("CliffWall", CFrame.lookAt(vPos, vPos + Vector3.new(0, 0, -1)), 1.0, function() end, tTint).Parent = oRim
        end
    end
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

-- Per-area look. Prop: the main scattered prop (Tree props get trunk/leaf tints, others a Leaves tint
-- or an explicit Tint table). Decor: small ground clutter { asset, scale, tint? }. Feature: a second
-- terrain material splashed over the floor. Hero: a few big landmark props along the walls.
local tBiomeLook = {
    Jungle = { Wall = "7A5230", Prop = "JungleTree", Tree = true, Trunk = "8B5A2B", Leaves = "1FA82F",
        Terrain = Enum.Material.Grass, Decor = { "GrassClump", 2.2 } },
    Swamp = { Wall = "4F5A2A", Prop = "SwampTree", Tree = true, Trunk = "4E3B24", Leaves = "6B8E23",
        Terrain = Enum.Material.Mud, Feature = Enum.Material.Water, FeatureCount = 7, Decor = { "GrassClump", 2.6, { Leaves = "6B8E23" } } },
    TarPits = { Wall = "3A2F2A", Prop = "TarRock", Leaves = "5A4A40",
        Terrain = Enum.Material.Ground, Feature = Enum.Material.Asphalt, FeatureCount = 9, Decor = { "Bones", 2 } },
    Badlands = { Wall = "C8693A", Prop = "Cactus", Tree = true, PropScale = { 3, 4.6 }, Count = 20, Trunk = "3E8E3A", Leaves = "4FA83F", CliffTop = "D9A05A",
        Terrain = Enum.Material.Sandstone, Feature = Enum.Material.Sand, FeatureCount = 8, Decor = { "Bones", 2.2 },
        Hero = { "Mesa", 5, 7.5, { Rock = "D9824A", RockDark = "A9542E" } } },
    CoralCoast = { Wall = "D8C08A", Prop = "PalmTree", Tree = true, PropScale = { 3.2, 4.6 }, Count = 20, Trunk = "B07A45", Leaves = "2FBF5A",
        Terrain = Enum.Material.Sand, Lagoon = true, Decor = { "Coral", 3, { Glow = "FF7BA8", Band = "FF5A5A", Gold = "FFB13B" } } },
    IceAge = { Wall = "A9DDF5", Prop = "IceBlock", Leaves = "FFFFFF",
        Terrain = Enum.Material.Snow, Feature = Enum.Material.Glacier, FeatureCount = 6, Decor = { "Crystal", 2.5 } },
    Redwood = { Wall = "6B4A32", Prop = "Redwood", Tree = true, PropScale = { 3.6, 5.6 }, Count = 24, Trunk = "8E3B22", Leaves = "1E7A3A",
        Terrain = Enum.Material.LeafyGrass, Decor = { "GrassClump", 3, { Leaves = "2E8B3E" } } },
    CrystalCaves = { Wall = "3A2E5A", Prop = "CrystalCluster", PropScale = { 2.6, 4.8 }, Count = 20, Tint = { Glow = "C27BFF", RockDark = "2A2240" }, CliffTop = "8A5CFF",
        Terrain = Enum.Material.Rock, Decor = { "Crystal", 2.6, { Ice = "FF9BF0" } }, Lights = "C27BFF" },
    Volcano = { Wall = "3B1A14", Prop = "LavaRock", Leaves = "FF6A1A", CliffTop = "5A2E24",
        Terrain = Enum.Material.Asphalt, Feature = Enum.Material.CrackedLava, FeatureCount = 22, Lights = "FF6A1A" },
    SkyIslands = { Wall = "BFD8FF", Prop = "Cloud", PropScale = { 2.5, 4.5 }, Tint = { Snow = "FFFFFF" },
        Terrain = Enum.Material.Salt, Decor = { "Cloud", 1.2 }, NoWalls = true },
}

local function Tints(t: { [string]: string }?): { [string]: Color3 }?
    if not t then return nil end
    local tOut = {}
    for k, v in t do tOut[k] = Color3.fromHex(v) end
    return tOut
end

-- Stylised terrain palette (bright and saturated to match the art style).
local function ApplyTerrainColours()
    local oTerrain = Workspace.Terrain
    oTerrain:SetMaterialColor(Enum.Material.Grass, Color3.fromHex("5DC93E"))
    oTerrain:SetMaterialColor(Enum.Material.Mud, Color3.fromHex("6B7A34"))
    oTerrain:SetMaterialColor(Enum.Material.Ground, Color3.fromHex("6A5243"))
    oTerrain:SetMaterialColor(Enum.Material.Asphalt, Color3.fromHex("1E1A1C"))
    oTerrain:SetMaterialColor(Enum.Material.Snow, Color3.fromHex("F2F8FF"))
    oTerrain:SetMaterialColor(Enum.Material.Glacier, Color3.fromHex("9EDCF5"))
    oTerrain:SetMaterialColor(Enum.Material.Basalt, Color3.fromHex("3A1E18"))
    oTerrain:SetMaterialColor(Enum.Material.Rock, Color3.fromHex("4A3A80"))
    oTerrain:SetMaterialColor(Enum.Material.CrackedLava, Color3.fromHex("FF6A1A"))
    oTerrain:SetMaterialColor(Enum.Material.Sandstone, Color3.fromHex("E09A5A"))
    oTerrain:SetMaterialColor(Enum.Material.Sand, Color3.fromHex("F2D89A"))
    oTerrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromHex("3E9A3A"))
    oTerrain:SetMaterialColor(Enum.Material.Slate, Color3.fromHex("4A3F6B"))
    oTerrain:SetMaterialColor(Enum.Material.Salt, Color3.fromHex("EAF3FF"))
    oTerrain.WaterColor = Color3.fromHex("3AAFB8")
    oTerrain.WaterTransparency = 0.6
    oTerrain.WaterWaveSize = 0.1
end

local BuildLandmarks: (Folder) -> ()

local function BuildCanyon()
    local oCanyon = Folder("Canyon", oWorld)
    local nHalf = CanyonMath.CanyonHalfWidth
    local nLen = CanyonMath.BiomeLength
    for i, tBiome in DinoConfig.Biomes do
        local tLook = tBiomeLook[tBiome.Id]
        local oBiome = Folder(tBiome.Id, oCanyon)
        local nZ0 = CanyonMath.CanyonStartZ - (i - 1) * nLen
        local nMidZ = nZ0 - nLen / 2
        -- Floor as terrain, one material per biome, plus a feature layer (swamp pools, tar, lava cracks).
        local oTerrain = Workspace.Terrain
        local vFloorSize = Vector3.new(nHalf * 2 + 40, 8, nLen)
        oTerrain:FillBlock(CFrame.new(0, CanyonMath.FloorY - 4, nMidZ), vFloorSize, tLook.Terrain)
        if tLook.Lagoon then
            -- A turquoise lagoon along the right-hand side of the beach.
            local nW = nHalf + 20 - 76
            oTerrain:FillBlock(CFrame.new(76 + nW / 2, CanyonMath.FloorY - 2, nMidZ), Vector3.new(nW, 8, nLen), Enum.Material.Air)
            oTerrain:FillBlock(CFrame.new(76 + nW / 2, CanyonMath.FloorY - 4, nMidZ), Vector3.new(nW, 4, nLen), Enum.Material.Water)
            oTerrain:FillBlock(CFrame.new(76 + nW / 2, CanyonMath.FloorY - 8, nMidZ), Vector3.new(nW, 4, nLen), Enum.Material.Sand)
        end
        for _ = 1, tLook.FeatureCount or 0 do
            local vPos = Vector3.new(oRandom:NextNumber(-nHalf + 30, nHalf - 30), CanyonMath.FloorY - 0.6, nZ0 - oRandom:NextNumber(30, nLen - 30))
            local nSize = oRandom:NextNumber(18, 40)
            if tLook.DeepFeature then
                oTerrain:FillCylinder(CFrame.new(vPos.X, CanyonMath.FloorY - 2.6, vPos.Z), 5, nSize / 2, tLook.Feature)
            else
                oTerrain:FillCylinder(CFrame.new(vPos.X, CanyonMath.FloorY - 1.8, vPos.Z), 4, nSize / 2, tLook.Feature)
            end
        end
        local nWallHeight = 110 + i * 12
        local bCliffAsset = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets.World:FindFirstChild("CliffWall") ~= nil
        for _, nSide in (if tLook.NoWalls then {} else { -1, 1 }) do
            if bCliffAsset then
                -- Blender cliff modules (100 studs wide at scale 2.5), facing into the canyon, tinted per biome.
                local cWall = Color3.fromHex(tLook.Wall)
                local tTint = { Rock = cWall:Lerp(Color3.new(1, 1, 1), 0.12), RockDark = cWall:Lerp(Color3.new(0, 0, 0), 0.25), Leaves = Color3.fromHex(tLook.CliffTop or tLook.Leaves or "4E8A3A") }
                -- Overlapping modules with random scale, depth and height offsets so the strata don't read as tiles.
                for k = 0, 4 do
                    local nScale = oRandom:NextNumber(2.1, 2.9)
                    local vPos = Vector3.new(nSide * (nHalf + oRandom:NextNumber(10, 22)), CanyonMath.FloorY - oRandom:NextNumber(4, 30), nZ0 - 40 - k * 82)
                    local cf = CFrame.lookAt(vPos, vPos + Vector3.new(-nSide, 0, 0)) * CFrame.Angles(0, math.rad(oRandom:NextNumber(-8, 8)), math.rad(oRandom:NextNumber(-4, 4)))
                    PlaceProp("CliffWall", cf, nScale, function() end, tTint).Parent = oBiome
                end
                -- Invisible collider keeps the canyon edge solid and cheap.
                Part({ Name = "WallCollider", Size = Vector3.new(24, nWallHeight, nLen), Position = Vector3.new(nSide * (nHalf + 12), nWallHeight / 2 - 4, nMidZ), Transparency = 1, Parent = oBiome })
            else
                Part({ Name = "TEMP_Wall", Size = Vector3.new(24, nWallHeight, nLen), Position = Vector3.new(nSide * (nHalf + 12), nWallHeight / 2 - 4, nMidZ), Color = Color3.fromHex(tLook.Wall), Material = Enum.Material.Rock, Parent = oBiome })
            end
        end
        -- Biome decoration from the Blender kit (cheap, small props).
        local tDecor = tLook.Decor
        if tDecor then
            local tTint = Tints(tDecor[3])
            for _ = 1, 16 do
                local vPos = Vector3.new(oRandom:NextNumber(-nHalf + 15, nHalf - 15), CanyonMath.FloorY, nZ0 - oRandom:NextNumber(15, nLen - 15))
                if tLook.Lagoon then
                    -- Coral grows on the lagoon bed.
                    vPos = Vector3.new(oRandom:NextNumber(88, nHalf - 12), CanyonMath.FloorY - 5, vPos.Z)
                end
                PlaceProp(tDecor[1], CFrame.new(vPos) * CFrame.Angles(0, oRandom:NextNumber(0, 6.28), 0), tDecor[2] * oRandom:NextNumber(0.8, 1.3), function() end, tTint).Parent = oBiome
            end
        end
        -- Biome gate: an arch of two pillars + a floating sign readable from the rim
        if i > 1 then
            for _, nSide in { -1, 1 } do
                Part({ Name = "TEMP_GatePillar", Size = Vector3.new(10, 70, 10), Position = Vector3.new(nSide * (nHalf - 10), 35, nZ0), Color = tBiome.Color, Material = Enum.Material.Neon, Parent = oBiome })
            end
            local oSign = Part({ Name = "GateSign", Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false, Position = Vector3.new(0, 70, nZ0), Parent = oBiome })
            local oBillboard = Label(oSign, `{tBiome.Name}\n{Format.Meters(tBiome.MinMeters)}`, 36, Color3.new(1, 1, 1), Vector3.zero)
            -- Sized in studs (scale) so distant gates shrink naturally but stay readable from the rim.
            -- Only the next few gates show; farther ones piled into an unreadable cluster on the horizon.
            oBillboard.MaxDistance = 1300
            oBillboard.Size = UDim2.fromScale(110, 50)
        end
        -- Props
        local tScale = tLook.PropScale or (if tLook.Tree then { 1.6, 3 } else { 2.5, 6 })
        for _ = 1, tLook.Count or 26 do
            local vPos = Vector3.new(oRandom:NextNumber(-nHalf + 15, nHalf - 15), CanyonMath.FloorY, nZ0 - oRandom:NextNumber(20, nLen - 20))
            if math.abs(vPos.X) > 25 and not (tLook.Lagoon and vPos.X > 66) then
                local cfProp = CFrame.new(vPos) * CFrame.Angles(0, oRandom:NextNumber(0, 6.28), 0)
                local nScale = oRandom:NextNumber(tScale[1], tScale[2])
                if tLook.Prop == "Cloud" then
                    -- Sky Islands: clouds drift at different heights above the cloud floor.
                    cfProp = cfProp + Vector3.new(0, oRandom:NextNumber(0, 40), 0)
                end
                if tLook.Tree then
                    PlaceProp(tLook.Prop, cfProp, nScale, TempTree(Color3.fromHex(tLook.Trunk), Color3.fromHex(tLook.Leaves), 16),
                        { Trunk = Color3.fromHex(tLook.Trunk), Leaves = Color3.fromHex(tLook.Leaves) }).Parent = oBiome
                else
                    local tTint = Tints(tLook.Tint)
                    PlaceProp(tLook.Prop, cfProp, nScale, TempRock(Color3.fromHex(tLook.Leaves or "FFFFFF")), tTint).Parent = oBiome
                end
            end
        end
        -- Landmarks hugging the walls (e.g. Badlands mesas), leaving the flight lane clear.
        if tLook.Hero then
            local tHero = tLook.Hero
            for k = 0, 3 do
                local nSide = if k % 2 == 0 then -1 else 1
                local vPos = Vector3.new(nSide * (nHalf - oRandom:NextNumber(10, 35)), CanyonMath.FloorY, nZ0 - 50 - k * 95)
                PlaceProp(tHero[1], CFrame.new(vPos) * CFrame.Angles(0, oRandom:NextNumber(0, 6.28), 0), oRandom:NextNumber(tHero[2], tHero[3]), function() end, Tints(tHero[4])).Parent = oBiome
            end
        end
        -- Coloured glow lights for the darker areas.
        if tLook.Lights then
            for k = 0, 3 do
                local oLamp = Part({ Name = "AreaLight", Size = Vector3.one, Transparency = 1, CanCollide = false,
                    Position = Vector3.new((k % 2 * 2 - 1) * nHalf * 0.5, 25, nZ0 - 50 - k * 100), Parent = oBiome })
                local oLight = Instance.new("PointLight")
                oLight.Range = 60
                oLight.Brightness = 2
                oLight.Color = Color3.fromHex(tLook.Lights)
                oLight.Parent = oLamp
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
    BuildLandmarks(oCanyon)
end

local function BiomeStartZ(sId: string): number?
    for i, tBiome in DinoConfig.Biomes do
        if tBiome.Id == sId then
            return CanyonMath.CanyonStartZ - (i - 1) * CanyonMath.BiomeLength
        end
    end
    return nil
end

-- Volcanoes towering over the Volcano area (one each side, outside the walls so the flight lane
-- stays clear), with smoke, embers and a crater glow; then floating islands for the Sky Islands finale.
BuildLandmarks = function(oCanyon: Folder)
    local nHalf = CanyonMath.CanyonHalfWidth
    local nLen = CanyonMath.BiomeLength
    local nVolcanoZ = BiomeStartZ("Volcano")
    if nVolcanoZ then
        for _, t in { { -1, 0.55, 3.9 }, { 1, 0.9, 3.2 } } do
            local nSide, nAlong, nScale = t[1], t[2], t[3]
            local oVolcano = PlaceProp("VolcanoBig", CFrame.new(nSide * (nHalf + 70 * nScale * 0.85), CanyonMath.FloorY - 6, nVolcanoZ - nLen * nAlong), nScale, function(oModel)
                for iLayer = 0, 5 do
                    local nRadius = 70 - iLayer * 10
                    Part({ Name = "RockDark", Shape = Enum.PartType.Cylinder, Size = Vector3.new(14, nRadius * 2, nRadius * 2), CFrame = CFrame.new(0, iLayer * 14 + 7, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromHex("3B1A14"), Material = Enum.Material.Basalt, Parent = oModel })
                end
            end, { Rock = Color3.fromHex("5A2E24"), RockDark = Color3.fromHex("2A1612") })
            oVolcano.Parent = oCanyon
            local cfBox, vSize = oVolcano:GetBoundingBox()
            local vCrater = cfBox.Position + Vector3.new(0, vSize.Y / 2 - 4, 0)
            local oCrater = Part({ Name = "Crater", Size = Vector3.new(vSize.X * 0.2, 2, vSize.Z * 0.2), Transparency = 1, CanCollide = false, Position = vCrater, Parent = oCanyon })
            local oLight = Instance.new("PointLight")
            oLight.Range = 60
            oLight.Brightness = 6
            oLight.Color = Color3.fromHex("FF6A1A")
            oLight.Parent = oCrater
            local oSmoke = Instance.new("ParticleEmitter")
            oSmoke.Name = "Smoke"
            oSmoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
            oSmoke.Color = ColorSequence.new(Color3.fromHex("5A4A48"), Color3.fromHex("2A2222"))
            oSmoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 18 * nScale), NumberSequenceKeypoint.new(1, 45 * nScale) })
            oSmoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
            oSmoke.Lifetime = NumberRange.new(8, 12)
            oSmoke.Speed = NumberRange.new(10, 16)
            oSmoke.SpreadAngle = Vector2.new(12, 12)
            oSmoke.Rate = 3
            oSmoke.RotSpeed = NumberRange.new(-15, 15)
            oSmoke.Parent = oCrater
            local oEmbers = Instance.new("ParticleEmitter")
            oEmbers.Name = "Embers"
            oEmbers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
            oEmbers.Color = ColorSequence.new(Color3.fromHex("FFB13B"), Color3.fromHex("FF3A1A"))
            oEmbers.LightEmission = 1
            oEmbers.Size = NumberSequence.new(2.5, 0.5)
            oEmbers.Lifetime = NumberRange.new(3, 5)
            oEmbers.Speed = NumberRange.new(30, 55)
            oEmbers.SpreadAngle = Vector2.new(25, 25)
            oEmbers.Acceleration = Vector3.new(0, -20, 0)
            oEmbers.Rate = 12
            oEmbers.Parent = oCrater
        end
    end
    local nSkyZ = BiomeStartZ("SkyIslands")
    if nSkyZ then
        local tIslands = {
            { -110, 60, 70, 3.2 }, { 120, 100, 150, 4.0 }, { -50, 150, 240, 2.8 }, { 100, 55, 310, 3.4 }, { -130, 120, 370, 4.4 },
            { 0, 170, nLen + 120, 9.0 }, -- the big finale island beyond the last metre
        }
        for _, t in tIslands do
            local vPos = Vector3.new(t[1], CanyonMath.FloorY + t[2], nSkyZ - t[3])
            PlaceProp("SkyIsland", CFrame.new(vPos) * CFrame.Angles(0, oRandom:NextNumber(0, 6.28), 0), t[4], function() end,
                { Leaves = Color3.fromHex("6FD45A"), Leaves2 = Color3.fromHex("B8F06A") }).Parent = oCanyon
        end
        -- Cloud banks along the edges and the far end hide the cloud floor's hard edges.
        local tWhite = { Snow = Color3.new(1, 1, 1) }
        for k = 0, 13 do
            for _, nSide in { -1, 1 } do
                local vPos = Vector3.new(nSide * (nHalf + oRandom:NextNumber(-10, 25)), CanyonMath.FloorY - oRandom:NextNumber(8, 16), nSkyZ - k * 32 - oRandom:NextNumber(0, 20))
                PlaceProp("Cloud", CFrame.new(vPos) * CFrame.Angles(0, math.rad(90 + oRandom:NextNumber(-20, 20)), 0), oRandom:NextNumber(5, 8), function() end, tWhite).Parent = oCanyon
            end
        end
        for k = -4, 4 do
            local vPos = Vector3.new(k * 48, CanyonMath.FloorY - oRandom:NextNumber(8, 16), nSkyZ - nLen - oRandom:NextNumber(0, 25))
            PlaceProp("Cloud", CFrame.new(vPos) * CFrame.Angles(0, oRandom:NextNumber(-0.3, 0.3), 0), oRandom:NextNumber(5, 8), function() end, tWhite).Parent = oCanyon
        end
    end
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
        -- Launch stand: the giant slingshot (Blender) on the canyon side of the pad, so the player stands behind it and looks through the fork.
        local vStand = tPlot.LaunchStand
        Part({ Name = "LaunchPad", Size = Vector3.new(10, 1, 8), Position = vStand + Vector3.new(0, 0.5, 0), Color = Color3.fromHex("FFC531"), Material = Enum.Material.SmoothPlastic, Parent = oPlot })
        local oSling = PlaceProp("LaunchSlingshot", CFrame.new(vStand + Vector3.new(0, 1, -3.4)), 1.15, function(oModel)
            Part({ Name = "Wood", Size = Vector3.new(1.2, 6, 1.2), CFrame = CFrame.new(0, 3, 0), Parent = oModel })
        end)
        -- Only the boulder base is solid: the fork, bands and pouch never snag the player.
        for _, o in oSling:GetDescendants() do
            if o:IsA("BasePart") and o.Name ~= "Rock" then o.CanCollide = false end
        end
        oSling.Parent = oPlot
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
        -- Blender pad on top; the flat part stays as an invisible floor + label anchor.
        local bPadAsset = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets.World:FindFirstChild("TrainingPad") ~= nil
        if bPadAsset then
            oPad.Transparency = 1
            PlaceProp("TrainingPad", CFrame.new(vPos), 1.05, function() end, { Glow = tPad.Color }).Parent = oTraining
        end
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
    Workspace.Terrain:Clear()
    ApplyTerrainColours()
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
