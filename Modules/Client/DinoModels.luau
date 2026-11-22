--[[
    DinoModels
    ----------
    Builds the visual model for a dino entry (species + size + mutation).
    Not a lifecycle module.

    Prefers a real model from ReplicatedStorage.Assets.Dinos.<SpeciesId>
    (the Blender pipeline). Until those exist it builds a TEMP_ stand-in from
    chunky primitives per archetype (tracked in Docs/TEMP_ART.md), so the
    whole loop is playable and readable now.

    Size scales the model; mutations recolour it and add an aura.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DinoConfig = require(ReplicatedStorage.Config.DinoConfig)
local Theme = require(ReplicatedStorage.Shared.Theme)

local DinoModels = {}

local function P(oModel: Model, sName: string, vSize: Vector3, cf: CFrame, cColor: Color3, eShape: Enum.PartType?): Part
    local o = Instance.new("Part")
    o.Name = sName
    o.Size = vSize
    o.CFrame = cf
    o.Color = cColor
    o.Material = Enum.Material.SmoothPlastic
    o.Shape = eShape or Enum.PartType.Block
    o.Anchored = true
    o.CanCollide = false
    o.CanQuery = false
    o.CanTouch = false
    o.CastShadow = true
    o.TopSurface = Enum.SurfaceType.Smooth
    o.BottomSurface = Enum.SurfaceType.Smooth
    o.Parent = oModel
    return o
end

-- Builds a stand-in facing -Z with its feet at y = 0, about tSpecies.Height tall.
local function BuildTemp(tSpecies): Model
    local oModel = Instance.new("Model")
    oModel.Name = "TEMP_" .. tSpecies.Id
    local c = tSpecies.Colors
    local sArch = tSpecies.Archetype
    local oRoot
    if sArch == "Theropod" or sArch == "Small" then
        -- Upright two-legged hunter: big head, chunky body, tail out back.
        oRoot = P(oModel, "Body", Vector3.new(2.2, 2, 3.4), CFrame.new(0, 2.6, 0) * CFrame.Angles(math.rad(-12), 0, 0), c.Body)
        P(oModel, "Belly", Vector3.new(1.8, 1.4, 2.6), CFrame.new(0, 2.2, -0.3), c.Belly)
        P(oModel, "Neck", Vector3.new(1.2, 1.6, 1.2), CFrame.new(0, 3.6, -1.5) * CFrame.Angles(math.rad(25), 0, 0), c.Body)
        P(oModel, "Head", Vector3.new(1.7, 1.4, 2.4), CFrame.new(0, 4.4, -2.4), c.Body)
        P(oModel, "Jaw", Vector3.new(1.5, 0.5, 2.0), CFrame.new(0, 3.75, -2.5), c.Belly)
        P(oModel, "EyeL", Vector3.new(0.4, 0.4, 0.4), CFrame.new(-0.75, 4.7, -2.9), Theme.Ink, Enum.PartType.Ball)
        P(oModel, "EyeR", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0.75, 4.7, -2.9), Theme.Ink, Enum.PartType.Ball)
        P(oModel, "Tail1", Vector3.new(1.4, 1.2, 2.4), CFrame.new(0, 2.8, 2.4) * CFrame.Angles(math.rad(10), 0, 0), c.Body)
        P(oModel, "Tail2", Vector3.new(0.8, 0.7, 2.2), CFrame.new(0, 3.1, 4.4) * CFrame.Angles(math.rad(14), 0, 0), c.Accent)
        P(oModel, "LegL", Vector3.new(0.8, 2, 1.1), CFrame.new(-0.8, 1, 0.4), c.Body)
        P(oModel, "LegR", Vector3.new(0.8, 2, 1.1), CFrame.new(0.8, 1, 0.4), c.Body)
        P(oModel, "ArmL", Vector3.new(0.35, 0.9, 0.35), CFrame.new(-0.9, 2.6, -1.4), c.Accent)
        P(oModel, "ArmR", Vector3.new(0.35, 0.9, 0.35), CFrame.new(0.9, 2.6, -1.4), c.Accent)
        if tSpecies.Id == "Spinosaurus" then
            P(oModel, "Sail", Vector3.new(0.3, 2.4, 3.2), CFrame.new(0, 4.4, 0.2), c.Accent)
        elseif tSpecies.Id == "Dilophosaurus" or tSpecies.Id == "Cryolophosaurus" then
            P(oModel, "Crest", Vector3.new(0.3, 0.9, 1.6), CFrame.new(0, 5.4, -2.2), c.Accent)
        elseif tSpecies.Id == "Carnotaurus" then
            P(oModel, "HornL", Vector3.new(0.35, 0.8, 0.35), CFrame.new(-0.6, 5.3, -2.0), c.Accent)
            P(oModel, "HornR", Vector3.new(0.35, 0.8, 0.35), CFrame.new(0.6, 5.3, -2.0), c.Accent)
        elseif tSpecies.Id == "Therizinosaurus" then
            P(oModel, "ClawL", Vector3.new(0.25, 0.25, 1.6), CFrame.new(-0.9, 2.1, -2.0), c.Accent)
            P(oModel, "ClawR", Vector3.new(0.25, 0.25, 1.6), CFrame.new(0.9, 2.1, -2.0), c.Accent)
        else
            P(oModel, "Stripe", Vector3.new(2.3, 0.3, 0.6), CFrame.new(0, 3.55, 0.2), c.Accent)
        end
    elseif sArch == "Quadruped" then
        oRoot = P(oModel, "Body", Vector3.new(3.4, 2.4, 4.6), CFrame.new(0, 2.6, 0), c.Body)
        P(oModel, "Belly", Vector3.new(3.0, 0.8, 4.0), CFrame.new(0, 1.5, 0), c.Belly)
        P(oModel, "Head", Vector3.new(2.2, 1.8, 2.2), CFrame.new(0, 2.6, -3.2), c.Body)
        P(oModel, "EyeL", Vector3.new(0.4, 0.4, 0.4), CFrame.new(-1.0, 3.0, -3.9), Theme.Ink, Enum.PartType.Ball)
        P(oModel, "EyeR", Vector3.new(0.4, 0.4, 0.4), CFrame.new(1.0, 3.0, -3.9), Theme.Ink, Enum.PartType.Ball)
        P(oModel, "Tail", Vector3.new(1.4, 1.2, 3.2), CFrame.new(0, 2.6, 3.6), c.Body)
        for _, v in { Vector3.new(-1.2, 0.8, -1.5), Vector3.new(1.2, 0.8, -1.5), Vector3.new(-1.2, 0.8, 1.5), Vector3.new(1.2, 0.8, 1.5) } do
            P(oModel, "Leg", Vector3.new(0.9, 1.6, 0.9), CFrame.new(v), c.Body)
        end
        if tSpecies.Id == "Triceratops" then
            P(oModel, "Frill", Vector3.new(3.2, 2.4, 0.4), CFrame.new(0, 3.6, -2.2), c.Accent)
            P(oModel, "HornL", Vector3.new(0.35, 0.35, 1.6), CFrame.new(-0.6, 3.3, -4.4), Theme.Panel)
            P(oModel, "HornR", Vector3.new(0.35, 0.35, 1.6), CFrame.new(0.6, 3.3, -4.4), Theme.Panel)
        else
            P(oModel, "Club", Vector3.new(1.4, 1, 1), CFrame.new(0, 2.6, 5.4), c.Accent)
            P(oModel, "Plates", Vector3.new(3.0, 0.4, 3.8), CFrame.new(0, 3.9, 0), c.Accent)
        end
    elseif sArch == "Sauropod" then
        oRoot = P(oModel, "Body", Vector3.new(3.6, 3, 5.4), CFrame.new(0, 4, 0), c.Body)
        P(oModel, "Belly", Vector3.new(3.2, 1, 4.6), CFrame.new(0, 2.7, 0), c.Belly)
        P(oModel, "Neck1", Vector3.new(1.3, 4, 1.3), CFrame.new(0, 7, -2.6) * CFrame.Angles(math.rad(20), 0, 0), c.Body)
        P(oModel, "Neck2", Vector3.new(1.1, 4, 1.1), CFrame.new(0, 10.6, -3.6) * CFrame.Angles(math.rad(8), 0, 0), c.Body)
        P(oModel, "Head", Vector3.new(1.5, 1.2, 2.2), CFrame.new(0, 12.8, -4.4), c.Body)
        P(oModel, "EyeL", Vector3.new(0.35, 0.35, 0.35), CFrame.new(-0.7, 13.1, -5.0), Theme.Ink, Enum.PartType.Ball)
        P(oModel, "EyeR", Vector3.new(0.35, 0.35, 0.35), CFrame.new(0.7, 13.1, -5.0), Theme.Ink, Enum.PartType.Ball)
        P(oModel, "Tail", Vector3.new(1.2, 1.2, 5), CFrame.new(0, 4, 5) * CFrame.Angles(math.rad(-8), 0, 0), c.Accent)
        for _, v in { Vector3.new(-1.3, 1.3, -1.8), Vector3.new(1.3, 1.3, -1.8), Vector3.new(-1.3, 1.3, 1.8), Vector3.new(1.3, 1.3, 1.8) } do
            P(oModel, "Leg", Vector3.new(1.2, 2.6, 1.2), CFrame.new(v), c.Body)
        end
    else -- Ornithopod: duck-billed / dome-headed walkers
        oRoot = P(oModel, "Body", Vector3.new(2.6, 2.4, 3.8), CFrame.new(0, 3, 0) * CFrame.Angles(math.rad(-10), 0, 0), c.Body)
        P(oModel, "Belly", Vector3.new(2.2, 1.4, 3), CFrame.new(0, 2.6, -0.2), c.Belly)
        P(oModel, "Neck", Vector3.new(1.2, 1.8, 1.2), CFrame.new(0, 4.3, -1.6) * CFrame.Angles(math.rad(20), 0, 0), c.Body)
        P(oModel, "Head", Vector3.new(1.6, 1.4, 2.2), CFrame.new(0, 5.1, -2.4), c.Body)
        P(oModel, "EyeL", Vector3.new(0.4, 0.4, 0.4), CFrame.new(-0.7, 5.4, -2.9), Theme.Ink, Enum.PartType.Ball)
        P(oModel, "EyeR", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0.7, 5.4, -2.9), Theme.Ink, Enum.PartType.Ball)
        P(oModel, "Tail", Vector3.new(1.2, 1.2, 3.4), CFrame.new(0, 3.2, 3) * CFrame.Angles(math.rad(8), 0, 0), c.Body)
        P(oModel, "LegL", Vector3.new(1, 2.2, 1.2), CFrame.new(-0.9, 1.1, 0.4), c.Body)
        P(oModel, "LegR", Vector3.new(1, 2.2, 1.2), CFrame.new(0.9, 1.1, 0.4), c.Body)
        if tSpecies.Id == "Parasaurolophus" then
            P(oModel, "Crest", Vector3.new(0.5, 0.5, 3), CFrame.new(0, 6.2, -1.2) * CFrame.Angles(math.rad(-25), 0, 0), c.Accent)
        else
            P(oModel, "Dome", Vector3.new(1.7, 1.2, 1.7), CFrame.new(0, 6, -2.3), c.Accent, Enum.PartType.Ball)
        end
    end
    oModel.WorldPivot = CFrame.new() -- feet at origin, facing -Z (no PrimaryPart, so tilted bodies don't skew the pivot)
    -- Normalise to the species' height.
    local _, vSize = oModel:GetBoundingBox()
    oModel:ScaleTo(tSpecies.Height / math.max(vSize.Y, 0.1))
    return oModel
end

local function ApplyMutation(oModel: Model, sMutation: string)
    if sMutation == "Normal" then return end
    local cTint = Theme.Mutation[sMutation]
    for _, o in oModel:GetDescendants() do
        if o:IsA("BasePart") and not o.Name:match("^Eye") and o.Name ~= "Pupil" then
            if sMutation == "Golden" then
                o.Color = o.Color:Lerp(cTint, 0.75)
                o.Material = Enum.Material.Foil
            elseif sMutation == "Frost" then
                o.Color = o.Color:Lerp(cTint, 0.7)
                o.Material = Enum.Material.Ice
            elseif sMutation == "Magma" then
                -- Charred black rock with glowing lava on the belly, stripes, crests and sails.
                local bGlow = o.Name == "Accent" or o.Name == "Belly" or o.Name:match("Stripe") or o.Name:match("Crest") or o.Name:match("Sail") or o.Name:match("Tail2") or o.Name:match("Plates") or o.Name:match("Frill")
                if bGlow then
                    o.Color = if o.Name == "Belly" then Color3.fromHex("FF8A1F") else cTint
                    o.Material = Enum.Material.Neon
                else
                    o.Color = Color3.fromHex("231A18")
                    o.Material = Enum.Material.Basalt
                end
            elseif sMutation == "Toxic" then
                -- Radioactive lime with glowing green markings and a sickly yellow belly.
                if o.Name == "Accent" then
                    o.Color = Color3.fromHex("7CFF2E")
                    o.Material = Enum.Material.Neon
                elseif o.Name == "Belly" then
                    o.Color = Color3.fromHex("E6FF5C")
                else
                    o.Color = Color3.fromHex("8BE01E"):Lerp(o.Color, 0.15)
                end
            elseif sMutation == "Cosmic" then
                o.Color = o.Color:Lerp(Color3.fromHex("2A1050"), 0.75)
                o.Material = Enum.Material.Glass
                o.Reflectance = 0.1
                if o.Name == "Accent" then
                    -- Glowing pink markings, like the cosmic aura.
                    o.Color = Color3.fromHex("FF5EDB")
                    o.Material = Enum.Material.Neon
                end
            end
        end
    end
    -- Aura: particles + light on the root part
    local oRoot = oModel.PrimaryPart or oModel:FindFirstChild("Body") or oModel:FindFirstChildWhichIsA("BasePart", true)
    if not oRoot then return end
    local oAura = Instance.new("ParticleEmitter")
    oAura.Name = "Aura"
    oAura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    oAura.Color = if sMutation == "Cosmic" then ColorSequence.new(Color3.fromHex("8E44FF"), Color3.fromHex("FF5EDB")) else ColorSequence.new(cTint)
    oAura.LightEmission = 1
    oAura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
    oAura.Lifetime = NumberRange.new(0.8, 1.4)
    oAura.Rate = if sMutation == "Cosmic" then 30 else 12
    oAura.Speed = NumberRange.new(1, 3)
    oAura.SpreadAngle = Vector2.new(180, 180)
    oAura.Parent = oRoot
    local oLight = Instance.new("PointLight")
    oLight.Color = cTint
    oLight.Range = 10
    oLight.Brightness = if sMutation == "Cosmic" then 3 else 1.5
    oLight.Parent = oRoot
end

-- Returns a new, anchored model with feet at its pivot's base.
function DinoModels.Build(tDino: { Species: string, Size: string, Mutation: string }): Model
    local tSpecies = DinoConfig.Species[tDino.Species]
    local oAssets = ReplicatedStorage:FindFirstChild("Assets")
    local oDinos = oAssets and oAssets:FindFirstChild("Dinos")
    local oTemplate = oDinos and oDinos:FindFirstChild(tDino.Species)
    local oModel: Model
    if oTemplate and oTemplate:IsA("Model") then
        -- Blender model: colour each named region from DinoConfig, then normalise to species height.
        oModel = oTemplate:Clone()
        local tRegionColours = {
            Body = tSpecies.Colors.Body,
            Belly = tSpecies.Colors.Belly,
            Accent = tSpecies.Colors.Accent,
            EyeWhite = Color3.new(1, 1, 1),
            Pupil = Theme.Ink,
        }
        for _, o in oModel:GetDescendants() do
            if o:IsA("BasePart") then
                o.Anchored = true
                o.CanCollide = false
                o.CanQuery = false
                o.CanTouch = false
                o.Material = Enum.Material.SmoothPlastic
                o.Name = o.Name:gsub("%.%d+$", "") -- Blender duplicate-name suffixes ("Body.001")
                -- v2 models have separate legs (LegL/LegR, LegFL/LegFR/LegBL/LegBR) coloured like the body.
                o.Color = tRegionColours[o.Name] or (if o.Name:match("^Leg") then tRegionColours.Body else o.Color)
            end
        end
        local _, vSize = oModel:GetBoundingBox()
        oModel:ScaleTo(oModel:GetScale() * tSpecies.Height / math.max(vSize.Y, 0.1))
    else
        oModel = BuildTemp(tSpecies)
    end
    local tSize = DinoConfig.GetSize(tDino.Size)
    if tSize and tSize.Scale ~= 1 then
        oModel:ScaleTo(oModel:GetScale() * tSize.Scale)
    end
    ApplyMutation(oModel, tDino.Mutation)
    oModel:SetAttribute("Species", tDino.Species)
    return oModel
end

-- Rest-pose data per model, captured the first time it's placed: the pivot's height above
-- the feet (so swinging legs can't change it and bob the dino) and each leg's offset and hip.
type LegRest = { oPart: BasePart, cfRel: CFrame, vHip: Vector3, nPhase: number }
local tRest: { [Model]: { nAboveFeet: number, tLegs: { LegRest } } } = setmetatable({}, { __mode = "k" }) :: any

-- Diagonal pairs move together on quadrupeds; left/right alternate on bipeds.
local LEG_PHASE = { LegL = 0, LegR = math.pi, LegFL = 0, LegBR = 0, LegFR = math.pi, LegBL = math.pi }

local function Rest(oModel: Model)
    local t = tRest[oModel]
    if t then return t end
    local cfBox, vSize = oModel:GetBoundingBox()
    local cfPivot = oModel:GetPivot()
    t = { nAboveFeet = cfPivot.Position.Y - (cfBox.Position.Y - vSize.Y / 2), tLegs = {} }
    for _, o in oModel:GetChildren() do
        if o:IsA("BasePart") and LEG_PHASE[o.Name] then
            -- Hip: near the top of the leg mesh, where it joins the body.
            local vHipWorld = o.Position + Vector3.new(0, o.Size.Y * 0.42, 0)
            table.insert(t.tLegs, { oPart = o, cfRel = cfPivot:ToObjectSpace(o.CFrame), vHip = cfPivot:PointToObjectSpace(vHipWorld), nPhase = LEG_PHASE[o.Name] })
        end
    end
    tRest[oModel] = t
    return t
end

-- Swings the legs around their hips. nPhase advances with walking; nAmount is the swing in radians (0 = standing).
function DinoModels.Pose(oModel: Model, nPhase: number, nAmount: number)
    local t = Rest(oModel)
    if #t.tLegs == 0 then return end
    local cfPivot = oModel:GetPivot()
    for _, tLeg in t.tLegs do
        local nAngle = math.sin(nPhase + tLeg.nPhase) * nAmount
        tLeg.oPart.CFrame = cfPivot * CFrame.new(tLeg.vHip) * CFrame.Angles(nAngle, 0, 0) * CFrame.new(-tLeg.vHip) * tLeg.cfRel
    end
end

-- Stands the model on the ground at vFeet, facing vLookDir (flat).
function DinoModels.PlaceAt(oModel: Model, vFeet: Vector3, vLookDir: Vector3?)
    local nPivotAboveFeet = Rest(oModel).nAboveFeet
    local vLook = vLookDir and Vector3.new(vLookDir.X, 0, vLookDir.Z) or Vector3.new(0, 0, -1)
    if vLook.Magnitude < 1e-3 then vLook = Vector3.new(0, 0, -1) end
    local vPivot = vFeet + Vector3.new(0, nPivotAboveFeet, 0)
    oModel:PivotTo(CFrame.lookAt(vPivot, vPivot + vLook.Unit))
end

-- Height of the built model's bounding box (for placing labels).
function DinoModels.Height(oModel: Model): number
    local _, vSize = oModel:GetBoundingBox()
    return vSize.Y
end

return DinoModels
