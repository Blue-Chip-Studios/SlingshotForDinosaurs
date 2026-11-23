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

-- Split models name moving pieces "<Region>_<Group>" (Body_Head, Accent_Tail, Belly_Jaw) and carry
-- hidden "Joint_<Group>" markers at each pivot. Colour and mutation logic only cares about the region.
local function Region(o: Instance): string
    return (o.Name:match("^(%a+)")) or o.Name
end
DinoModels.Region = Region

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
        local sR = Region(o)
        if o:IsA("BasePart") and not sR:match("^Eye") and sR ~= "Pupil" and sR ~= "Joint" then
            if sMutation == "Golden" then
                o.Color = o.Color:Lerp(cTint, 0.75)
                o.Material = Enum.Material.Foil
            elseif sMutation == "Frost" then
                o.Color = o.Color:Lerp(cTint, 0.7)
                o.Material = Enum.Material.Ice
            elseif sMutation == "Magma" then
                -- Charred black rock with glowing lava on the belly, stripes, crests and sails.
                local bGlow = sR == "Accent" or sR == "Belly" or o.Name:match("Stripe") or o.Name:match("Crest") or o.Name:match("Sail") or o.Name:match("Tail2") or o.Name:match("Plates") or o.Name:match("Frill")
                if bGlow then
                    o.Color = if sR == "Belly" then Color3.fromHex("FF8A1F") else cTint
                    o.Material = Enum.Material.Neon
                else
                    o.Color = Color3.fromHex("231A18")
                    o.Material = Enum.Material.Basalt
                end
            elseif sMutation == "Toxic" then
                -- Radioactive lime with glowing green markings and a sickly yellow belly.
                if sR == "Accent" then
                    o.Color = Color3.fromHex("7CFF2E")
                    o.Material = Enum.Material.Neon
                elseif sR == "Belly" then
                    o.Color = Color3.fromHex("E6FF5C")
                else
                    o.Color = Color3.fromHex("8BE01E"):Lerp(o.Color, 0.15)
                end
            elseif sMutation == "Cosmic" then
                o.Color = o.Color:Lerp(Color3.fromHex("2A1050"), 0.75)
                o.Material = Enum.Material.Glass
                o.Reflectance = 0.1
                if sR == "Accent" then
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
                local sR = Region(o)
                o.Color = tRegionColours[sR] or (if sR:match("^Leg") then tRegionColours.Body else o.Color)
                if sR == "Joint" then
                    o.Transparency = 1
                    o.CastShadow = false
                end
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
-- Moving pieces of split models: each group's parts (offsets from the pivot) and its joint.
type GroupRest = { vJoint: Vector3, tParts: { { oPart: BasePart, cfRel: CFrame } } }
local tRest: { [Model]: { nAboveFeet: number, tLegs: { LegRest }, tGroups: { [string]: GroupRest } } } = setmetatable({}, { __mode = "k" }) :: any

-- Diagonal pairs move together on quadrupeds; left/right alternate on bipeds.
local LEG_PHASE = { LegL = 0, LegR = math.pi, LegFL = 0, LegBR = 0, LegFR = math.pi, LegBL = math.pi }

local function Rest(oModel: Model)
    local t = tRest[oModel]
    if t then return t end
    local cfBox, vSize = oModel:GetBoundingBox()
    local cfPivot = oModel:GetPivot()
    t = { nAboveFeet = cfPivot.Position.Y - (cfBox.Position.Y - vSize.Y / 2), tLegs = {}, tGroups = {} }
    for _, o in oModel:GetChildren() do
        if o:IsA("BasePart") and LEG_PHASE[o.Name] then
            -- Hip: near the top of the leg mesh, where it joins the body.
            local vHipWorld = o.Position + Vector3.new(0, o.Size.Y * 0.42, 0)
            table.insert(t.tLegs, { oPart = o, cfRel = cfPivot:ToObjectSpace(o.CFrame), vHip = cfPivot:PointToObjectSpace(vHipWorld), nPhase = LEG_PHASE[o.Name] })
        end
    end
    -- Split pieces: a group exists only when its Joint_<Group> marker shipped with the model.
    for _, o in oModel:GetChildren() do
        local sJoint = o:IsA("BasePart") and o.Name:match("^Joint_(%a+)$")
        if sJoint then
            t.tGroups[sJoint] = { vJoint = cfPivot:PointToObjectSpace(o.Position), tParts = {} }
        end
    end
    for _, o in oModel:GetChildren() do
        local sGroup = o:IsA("BasePart") and Region(o) ~= "Joint" and o.Name:match("_(%a+)$")
        local tGroup = sGroup and t.tGroups[sGroup]
        if tGroup then
            table.insert(tGroup.tParts, { oPart = o :: BasePart, cfRel = cfPivot:ToObjectSpace((o :: BasePart).CFrame) })
        end
    end
    tRest[oModel] = t
    return t
end

-- Poses the moving pieces of a split model relative to its body (call before any whole-body tilt).
-- Angles in radians: head pitch (+ = nose up) and yaw (+ = turn left), jaw open (+ = open),
-- tail yaw (side sway) and tail pitch (+ = up). Models without split pieces ignore this.
export type Articulation = { HeadPitch: number?, HeadYaw: number?, Jaw: number?, TailYaw: number?, TailPitch: number? }
function DinoModels.Articulate(oModel: Model, a: Articulation)
    local t = Rest(oModel)
    local tHead, tJaw, tTail = t.tGroups.Head, t.tGroups.Jaw, t.tGroups.Tail
    if not (tHead or tTail) then return end
    local cfPivot = oModel:GetPivot()
    local cfHead = CFrame.identity
    if tHead then
        local j = tHead.vJoint
        cfHead = CFrame.new(j) * CFrame.Angles(0, a.HeadYaw or 0, 0) * CFrame.Angles(a.HeadPitch or 0, 0, 0) * CFrame.new(-j)
        for _, p in tHead.tParts do
            p.oPart.CFrame = cfPivot * cfHead * p.cfRel
        end
    end
    if tJaw then
        local j = tJaw.vJoint
        -- The jaw rides on the head, then hinges open (tip down = negative pitch in model space).
        local cfJaw = cfHead * CFrame.new(j) * CFrame.Angles(-(a.Jaw or 0), 0, 0) * CFrame.new(-j)
        for _, p in tJaw.tParts do
            p.oPart.CFrame = cfPivot * cfJaw * p.cfRel
        end
    end
    if tTail then
        local j = tTail.vJoint
        -- The tail points backwards (+Z), so lifting it is a negative pitch.
        local cfTail = CFrame.new(j) * CFrame.Angles(0, a.TailYaw or 0, 0) * CFrame.Angles(-(a.TailPitch or 0), 0, 0) * CFrame.new(-j)
        for _, p in tTail.tParts do
            p.oPart.CFrame = cfPivot * cfTail * p.cfRel
        end
    end
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

-- ===== Idle life =====
-- The models are one fused mesh plus separate legs, so idle life is whole-body motion pivoting
-- around the feet: breathing, weight shifts, looking around, the odd hop, shuffle or sniff. Each
-- dino gets its own random timing so a park never moves in sync.

export type IdleState = {
    nSeed: number, nYaw: number, nYawTarget: number, nNextLook: number,
    nActionStart: number, sAction: string?, nNextAction: number,
}

-- Rest height per model (the bounding box changes while it tilts, so measure once).
local tRestHeight: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local function RestHeight(oModel: Model): number
    local n = tRestHeight[oModel]
    if not n then
        local _, vSize = oModel:GetBoundingBox()
        n = vSize.Y
        tRestHeight[oModel] = n
    end
    return n
end

function DinoModels.NewIdleState(): IdleState
    local nNow = os.clock()
    return {
        nSeed = math.random() * 100, nYaw = 0, nYawTarget = 0, nNextLook = nNow + math.random() * 3,
        nActionStart = 0, sAction = nil, nNextAction = nNow + 3 + math.random() * 8,
    }
end

-- Rotates the whole model about its feet in its own frame (pitch = nose up, roll = lean) and lifts it.
local function TiltAboutFeet(oModel: Model, vFeet: Vector3, vLook: Vector3, nPitch: number, nYaw: number, nRoll: number, nLift: number)
    local vFlat = Vector3.new(vLook.X, 0, vLook.Z)
    if vFlat.Magnitude < 1e-3 then vFlat = Vector3.new(0, 0, -1) end
    local cfFeet = CFrame.lookAt(vFeet, vFeet + vFlat.Unit)
    local cfDelta = cfFeet * CFrame.Angles(nPitch, nYaw, nRoll) * cfFeet:Inverse()
    oModel:PivotTo(CFrame.new(0, nLift, 0) * cfDelta * oModel:GetPivot())
end

local function Ease(x: number): number
    x = math.clamp(x, 0, 1)
    return x * x * (3 - 2 * x)
end

-- Call every frame for a standing dino, right after PlaceAt(oModel, vFeet, vLook).
-- Split models move their head, jaw and tail on top of the whole-body motion.
function DinoModels.Idle(oModel: Model, vFeet: Vector3, vLook: Vector3, tState: IdleState)
    local nT = os.clock()
    local s = tState.nSeed
    local nH = RestHeight(oModel)
    local nScale = math.clamp(nH / 8, 0.4, 2.5)
    local bSplit = Rest(oModel).tGroups.Head ~= nil

    -- Look around: turn toward a new angle every few seconds, eased. Split models turn mostly
    -- the head and a little of the body; whole-mesh models turn the whole body.
    if nT >= tState.nNextLook then
        tState.nYawTarget = if math.random() < 0.35 then 0 else (math.random() - 0.5) * math.rad(80)
        tState.nNextLook = nT + 1.5 + math.random() * 4
    end
    tState.nYaw += (tState.nYawTarget - tState.nYaw) * 0.06
    local nBodyYaw = if bSplit then tState.nYaw * 0.35 else tState.nYaw
    local a: Articulation = {
        HeadYaw = tState.nYaw * 0.65,
        HeadPitch = math.sin(nT * 1.7 + s + 0.6) * 0.03,
        Jaw = 0.02 + math.max(0, math.sin(nT * 1.7 + s)) * 0.03,     -- breathing through the mouth
        TailYaw = math.sin(nT * 1.3 + s) * 0.16,                      -- lazy tail sway
        TailPitch = math.sin(nT * 0.9 + s * 3) * 0.04,
    }

    -- Breathing (slow nose rise and chest lift) and a lazy side-to-side weight shift.
    local nBreath = math.sin(nT * 1.7 + s)
    local nPitch = nBreath * 0.022
    local nRoll = math.sin(nT * 0.6 + s * 2) * 0.03
    local nLift = (nBreath * 0.5 + 0.5) * 0.04 * nScale
    local nStride, nSwing = 0, 0

    -- Occasional actions: a happy hop, a stomp in place, a sniff of the ground, or a big yawn.
    if not tState.sAction and nT >= tState.nNextAction then
        local r = math.random()
        tState.sAction = if r < 0.3 then "Hop" elseif r < 0.55 then "Shuffle" elseif r < 0.8 then "Sniff" else (if bSplit then "Yawn" else "Sniff")
        tState.nActionStart = nT
    end
    if tState.sAction then
        local u = nT - tState.nActionStart
        if tState.sAction == "Hop" then
            if u < 0.5 then
                local k = math.sin(math.pi * u / 0.5)
                nLift += k * 0.09 * nH
                nPitch += k * 0.12
                nStride, nSwing = math.pi / 2, 0.35 * k
                a.HeadPitch = (a.HeadPitch :: number) + k * 0.25
                a.TailPitch = (a.TailPitch :: number) + k * 0.35
                a.Jaw = (a.Jaw :: number) + k * 0.25                  -- happy open mouth
            else
                tState.sAction = nil
            end
        elseif tState.sAction == "Shuffle" then
            if u < 1.2 then
                local k = math.sin(math.pi * u / 1.2)
                nStride, nSwing = u * 14, 0.28 * k
                nRoll += math.sin(u * 14) * 0.04
                a.TailYaw = (a.TailYaw :: number) + math.sin(u * 14) * 0.25 * k
            else
                tState.sAction = nil
            end
        elseif tState.sAction == "Sniff" then -- lower the head, two quick sniffs, back up
            if u < 1.6 then
                local k = Ease(u / 0.4) * (1 - Ease((u - 1.2) / 0.4))
                local nSniff = k * math.max(0, math.sin(u * 22))
                if bSplit then
                    nPitch -= k * 0.06
                    a.HeadPitch = (a.HeadPitch :: number) - k * 0.5 - nSniff * 0.06
                    a.TailPitch = (a.TailPitch :: number) + k * 0.15
                else
                    nPitch -= k * 0.18 + nSniff * 0.025
                end
            else
                tState.sAction = nil
            end
        else -- Yawn: head tips back, jaw opens wide, slowly closes
            if u < 1.8 then
                local k = Ease(u / 0.5) * (1 - Ease((u - 1.2) / 0.6))
                a.HeadPitch = (a.HeadPitch :: number) + k * 0.35
                a.Jaw = (a.Jaw :: number) + k * 0.55
                nPitch += k * 0.04
            else
                tState.sAction = nil
            end
        end
        if not tState.sAction then
            tState.nNextAction = nT + 4 + math.random() * 9
        end
    end

    DinoModels.Pose(oModel, nStride, nSwing)
    DinoModels.Articulate(oModel, a)
    TiltAboutFeet(oModel, vFeet, vLook, nPitch, nBodyYaw, nRoll, nLift)
end

-- Walking pose for the moving pieces (tail swings with the stride, head bobs). Call after Pose.
function DinoModels.WalkArticulate(oModel: Model, nStride: number)
    DinoModels.Articulate(oModel, {
        HeadPitch = math.sin(nStride * 2) * 0.05,
        TailYaw = math.sin(nStride) * 0.22,
        TailPitch = 0.05,
        Jaw = 0.03,
    })
end

-- Catch reveal: pop out with a bounce, rear back and roar with a shake and stamping feet.
-- Split models throw the head back, open the jaw wide and lash the tail.
-- Call every frame right after PlaceAt; u = seconds since the dino appeared. Returns true once done.
function DinoModels.Roar(oModel: Model, vFeet: Vector3, vLook: Vector3, u: number): boolean
    local nH = RestHeight(oModel)
    local bSplit = Rest(oModel).tGroups.Head ~= nil
    local nPitch, nRoll, nLift, nStride, nSwing = 0, 0, 0, 0, 0
    local a: Articulation = {}
    if u < 0.45 then                       -- pop out of the ground with a bounce
        local k = math.sin(math.pi * u / 0.45)
        nLift = k * 0.25 * nH
        nPitch = k * 0.15
        nStride, nSwing = math.pi / 2, 0.4 * k
        a.TailPitch = k * 0.4
    elseif u < 0.65 then                   -- landing squash: dip forward
        local k = math.sin(math.pi * (u - 0.45) / 0.2)
        nPitch = -k * 0.08
        a.HeadPitch = -k * 0.15
    elseif u < 1.9 then                    -- rear back and roar, shaking
        local k = Ease((u - 0.65) / 0.3) * (1 - Ease((u - 1.55) / 0.35))
        nPitch = k * (if bSplit then 0.18 else 0.3)
        nRoll = k * math.sin(u * 45) * 0.035
        nLift = k * 0.03 * nH
        nStride, nSwing = u * 18, k * 0.12
        a.HeadPitch = k * 0.35 + k * math.sin(u * 40) * 0.04
        a.HeadYaw = k * math.sin(u * 23) * 0.06
        a.Jaw = k * 0.65
        a.TailPitch = k * 0.3
        a.TailYaw = k * math.sin(u * 20) * 0.3
    else
        return true
    end
    DinoModels.Pose(oModel, nStride, nSwing)
    DinoModels.Articulate(oModel, a)
    TiltAboutFeet(oModel, vFeet, vLook, nPitch, 0, nRoll, nLift)
    return false
end

-- Height of the built model's bounding box (for placing labels).
function DinoModels.Height(oModel: Model): number
    local _, vSize = oModel:GetBoundingBox()
    return vSize.Y
end

return DinoModels
