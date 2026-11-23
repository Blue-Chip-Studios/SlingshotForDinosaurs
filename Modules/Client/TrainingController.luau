--[[
    TrainingController
    ------------------
    Makes training visible and silly: while a player stands still on a training pad (their
    "OnPad" attribute, set by TrainingServer), their avatar runs a dino-themed workout that
    changes every few seconds:

        BoneLift   squats while pressing a giant cartoon dino bone overhead
        EggJuggle  juggles three speckled dino eggs
        TRexArms   tucks its arms in tiny like a T-Rex and stomps, with a "RAWR!" pop
        DinoLift   presses a tiny plush Compy overhead while it wiggles

    Purely visual and client-side: every client animates every training player it can see
    (OnPad replicates), by writing R15 joint Transforms after the Animator each frame and
    placing local props at the hands. Joints go back to the Animator when training stops.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Module = require(ReplicatedStorage.Shared.Module)
local Theme = require(ReplicatedStorage.Shared.Theme)
local DinoModels = require(ReplicatedStorage.ClientModules.DinoModels)

local ROUTINES = { "BoneLift", "EggJuggle", "TRexArms", "DinoLift" }
local SWITCH_MIN, SWITCH_MAX = 6, 9
local VIEW_DISTANCE = 140

local JOINTS = {
    RightShoulder = "RightUpperArm", LeftShoulder = "LeftUpperArm",
    RightElbow = "RightLowerArm", LeftElbow = "LeftLowerArm",
    RightHip = "RightUpperLeg", LeftHip = "LeftUpperLeg",
    RightKnee = "RightLowerLeg", LeftKnee = "LeftLowerLeg",
    Waist = "UpperTorso", Root = "LowerTorso", Neck = "Head",
}

type State = {
    oCharacter: Model,
    tMotors: { [string]: Instance }, -- Motor6D (classic rigs) or AnimationConstraint (newer rigs)
    tPose: { [string]: CFrame }, -- this frame's workout pose per joint (written to Transform before physics)
    tPosed: { [string]: boolean }, -- joints posed last frame (released back to the Animator when unused)
    sRoutine: string,
    nStart: number,
    nSwitchAt: number,
    oProps: Folder,
    oSweat: ParticleEmitter?,
    nLastRawr: number,
}

local tStates: { [Player]: State } = {}

-- ===== Props (local, uncollidable) =====

local function Part(oParent: Instance, sShape: Enum.PartType, vSize: Vector3, cColor: Color3): Part
    local o = Instance.new("Part")
    o.Shape = sShape
    o.Size = vSize
    o.Color = cColor
    o.Material = Enum.Material.SmoothPlastic
    o.Anchored, o.CanCollide, o.CanQuery, o.CanTouch = true, false, false, false
    o.CastShadow = false
    o.Parent = oParent
    return o
end

-- A chunky cartoon bone: a shaft with two knobbly ends, built along +X, centred on its pivot.
local function MakeBone(oParent: Instance): Model
    local m = Instance.new("Model")
    m.Name = "Bone"
    local cBone = Color3.fromHex("FFF4DC")
    local oShaft = Part(m, Enum.PartType.Cylinder, Vector3.new(3.6, 0.55, 0.55), cBone)
    oShaft.Name = "Shaft"
    for _, nSide in { -1, 1 } do
        for _, nOff in { -0.32, 0.32 } do
            local o = Part(m, Enum.PartType.Ball, Vector3.new(0.95, 0.95, 0.95), cBone)
            o.CFrame = CFrame.new(nSide * 1.85, nOff, 0)
        end
    end
    m.PrimaryPart = oShaft
    m.Parent = oParent
    return m
end

local function MakeEgg(oParent: Instance, cColor: Color3): Part
    local o = Part(oParent, Enum.PartType.Ball, Vector3.new(0.8, 1.0, 0.8), cColor)
    o.Name = "Egg"
    -- Speckles: three tiny darker dots stuck to the shell.
    for i = 1, 3 do
        local d = Part(oParent, Enum.PartType.Ball, Vector3.new(0.16, 0.16, 0.16), cColor:Lerp(Color3.new(0, 0, 0), 0.35))
        d.Name = "Speckle"
        d:SetAttribute("Egg", o.Name)
        d:SetAttribute("Offset", Vector3.new(math.cos(i * 2.1) * 0.36, (i - 2) * 0.22, math.sin(i * 2.1) * 0.36))
    end
    return o
end

local function MakeBaby(oParent: Instance): Model?
    local ok, m = pcall(DinoModels.Build, { Species = "Compy", Size = "Normal", Mutation = "Normal" })
    if not ok or not m then return nil end
    m:ScaleTo(m:GetScale() * 1.8 / math.max(m:GetExtentsSize().Y, 0.1))
    for _, o in m:GetDescendants() do
        if o:IsA("BasePart") then o.CastShadow = false end
        if o:IsA("BillboardGui") then o:Destroy() end
    end
    m.Parent = oParent
    return m
end

local function Rawr(oHead: BasePart)
    local b = Instance.new("BillboardGui")
    b.Size = UDim2.fromOffset(140, 50)
    b.StudsOffsetWorldSpace = Vector3.new(1.6, 2.2, 0)
    b.AlwaysOnTop = true
    b.LightInfluence = 0
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Size = UDim2.fromScale(1, 1)
    t.FontFace = Theme.Display
    t.TextScaled = true
    t.Text = "RAWR!"
    t.TextColor3 = Color3.fromHex("FFE14D")
    t.Rotation = math.random(-12, 12)
    local s = Instance.new("UIStroke")
    s.Thickness = 3
    s.Color = Theme.Ink
    s.Parent = t
    t.Parent = b
    b.Parent = oHead
    task.spawn(function()
        for i = 1, 20 do
            b.StudsOffsetWorldSpace += Vector3.new(0, 0.06, 0)
            t.TextTransparency = math.max(0, (i - 10) / 10)
            s.Transparency = t.TextTransparency
            task.wait(0.04)
        end
        b:Destroy()
    end)
end

-- ===== State =====

local function Stop(oPlayer: Player)
    local t = tStates[oPlayer]
    if not t then return end
    tStates[oPlayer] = nil
    -- Hand the joints back to the Animator (it rewrites Transform every frame it plays).
    for sJoint in t.tPosed do
        local oJoint = t.tMotors[sJoint] :: any
        if oJoint and oJoint.Parent then oJoint.Transform = CFrame.identity end
    end
    t.oProps:Destroy()
    if t.oSweat then t.oSweat:Destroy() end
end

local function Start(oPlayer: Player, oCharacter: Model): State?
    local oHumanoid = oCharacter:FindFirstChildOfClass("Humanoid")
    if not oHumanoid or oHumanoid.RigType ~= Enum.HumanoidRigType.R15 then return nil end
    local tMotors = {}
    for sJoint, sPart in JOINTS do
        local oPart = oCharacter:FindFirstChild(sPart)
        local oJoint = oPart and oPart:FindFirstChild(sJoint)
        -- Both joint types expose Transform (the slot animations write to), applied between the
        -- two joint frames, so one code path poses classic and newer avatars alike.
        if oJoint and (oJoint:IsA("Motor6D") or oJoint:IsA("AnimationConstraint")) then
            tMotors[sJoint] = oJoint
        end
    end
    if not (tMotors.RightShoulder and tMotors.LeftShoulder and tMotors.Root) then return nil end
    local oProps = Instance.new("Folder")
    oProps.Name = "TrainingProps_" .. oPlayer.UserId
    oProps.Parent = Workspace
    local oSweat: ParticleEmitter? = nil
    local oHead = oCharacter:FindFirstChild("Head")
    if oHead then
        oSweat = Instance.new("ParticleEmitter")
        oSweat.Name = "TrainingSweat"
        oSweat.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        oSweat.Color = ColorSequence.new(Color3.fromHex("8FD8FF"))
        oSweat.Size = NumberSequence.new(0.25, 0.05)
        oSweat.Lifetime = NumberRange.new(0.5, 0.8)
        oSweat.Rate = 6
        oSweat.Speed = NumberRange.new(3, 5)
        oSweat.SpreadAngle = Vector2.new(50, 50)
        oSweat.Acceleration = Vector3.new(0, -20, 0)
        oSweat.Parent = oHead
    end
    local nNow = os.clock()
    local t: State = {
        oCharacter = oCharacter, tMotors = tMotors, tPose = {}, tPosed = {},
        sRoutine = ROUTINES[math.random(#ROUTINES)], nStart = nNow,
        nSwitchAt = nNow + math.random(SWITCH_MIN, SWITCH_MAX),
        oProps = oProps, oSweat = oSweat, nLastRawr = 0,
    }
    tStates[oPlayer] = t
    return t
end

local function SetRoutine(t: State, sRoutine: string)
    t.sRoutine = sRoutine
    t.nStart = os.clock()
    t.oProps:ClearAllChildren()
end

-- ===== Poses =====

local function Pose(t: State, sJoint: string, cf: CFrame)
    if t.tMotors[sJoint] then t.tPose[sJoint] = cf end
end

-- Runs after the Animator and before physics: the workout pose replaces the animation on the
-- joints it uses; joints it stopped using get identity once, then the Animator takes over again.
local function ApplyPoses()
    for _, t in tStates do
        for sJoint, cf in t.tPose do
            local oJoint = t.tMotors[sJoint] :: any
            if oJoint and oJoint.Parent then oJoint.Transform = cf end
        end
        for sJoint in t.tPosed do
            if not t.tPose[sJoint] then
                local oJoint = t.tMotors[sJoint] :: any
                if oJoint and oJoint.Parent then oJoint.Transform = CFrame.identity end
            end
        end
        t.tPosed = {}
        for sJoint in t.tPose do t.tPosed[sJoint] = true end
    end
end

local function Rad(n: number): number
    return math.rad(n)
end

local function HandsMid(t: State): CFrame?
    local r = t.oCharacter:FindFirstChild("RightHand")
    local l = t.oCharacter:FindFirstChild("LeftHand")
    local oRoot = t.oCharacter:FindFirstChild("HumanoidRootPart")
    if not (r and l and oRoot) then return nil end
    local vMid = ((r :: BasePart).Position + (l :: BasePart).Position) / 2
    return CFrame.new(vMid) * (oRoot :: BasePart).CFrame.Rotation
end

local function Animate(t: State, nT: number)
    t.tPose = {}
    local u = nT - t.nStart
    local oRoot = t.oCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not oRoot then return end
    if t.sRoutine == "BoneLift" or t.sRoutine == "DinoLift" then
        -- Squat and press overhead: down with arms at the shoulders, up with arms straight up.
        local k = 0.5 - 0.5 * math.cos(u * 3.2)          -- 0 = standing tall, 1 = squat
        local nPress = 1 - k
        Pose(t, "Root", CFrame.new(0, -0.9 * k, 0))
        Pose(t, "RightHip", CFrame.Angles(Rad(55 * k), 0, 0))
        Pose(t, "LeftHip", CFrame.Angles(Rad(55 * k), 0, 0))
        Pose(t, "RightKnee", CFrame.Angles(Rad(-80 * k), 0, 0))
        Pose(t, "LeftKnee", CFrame.Angles(Rad(-80 * k), 0, 0))
        Pose(t, "RightShoulder", CFrame.Angles(Rad(100 + 75 * nPress), 0, Rad(-10)))
        Pose(t, "LeftShoulder", CFrame.Angles(Rad(100 + 75 * nPress), 0, Rad(10)))
        Pose(t, "RightElbow", CFrame.Angles(Rad(60 * k), 0, 0))
        Pose(t, "LeftElbow", CFrame.Angles(Rad(60 * k), 0, 0))
        Pose(t, "Neck", CFrame.Angles(Rad(-10 - 8 * k), 0, 0))
        local cfHands = HandsMid(t)
        if cfHands then
            if t.sRoutine == "BoneLift" then
                local oBone = t.oProps:FindFirstChild("Bone") :: Model? or MakeBone(t.oProps)
                oBone:PivotTo(cfHands * CFrame.new(0, 0.2, 0))
            else
                local oBaby = t.oProps:FindFirstChildOfClass("Model") or MakeBaby(t.oProps)
                if oBaby then
                    local nWiggle = math.sin(nT * 14) * 0.25
                    DinoModels.PlaceAt(oBaby, cfHands.Position + Vector3.new(0, 0.15, 0), oRoot.CFrame.LookVector)
                    oBaby:PivotTo(oBaby:GetPivot() * CFrame.Angles(0, nWiggle, nWiggle * 0.6))
                    DinoModels.Pose(oBaby, nT * 16, 0.6)
                end
            end
        end
    elseif t.sRoutine == "EggJuggle" then
        -- Arms alternate tossing; three eggs loop on an arc above the head.
        local a = math.sin(u * 7)
        Pose(t, "RightShoulder", CFrame.Angles(Rad(70 + 35 * a), 0, Rad(-8)))
        Pose(t, "LeftShoulder", CFrame.Angles(Rad(70 - 35 * a), 0, Rad(8)))
        Pose(t, "RightElbow", CFrame.Angles(Rad(55), 0, 0))
        Pose(t, "LeftElbow", CFrame.Angles(Rad(55), 0, 0))
        Pose(t, "Neck", CFrame.Angles(Rad(18), 0, 0))
        Pose(t, "Root", CFrame.new(0, 0.08 * math.abs(a), 0))
        if #t.oProps:GetChildren() == 0 then
            for _, c in { Color3.fromHex("BFF0C8"), Color3.fromHex("FFE1A8"), Color3.fromHex("CFE3FF") } do
                MakeEgg(t.oProps, c)
            end
        end
        local cf = oRoot.CFrame * CFrame.new(0, 1.0, -1.4)
        local tEggs = {}
        for _, o in t.oProps:GetChildren() do
            if o.Name == "Egg" then table.insert(tEggs, o) end
        end
        for i, oEgg in tEggs do
            local p = (u * 1.6 + i / #tEggs) % 1
            local x = math.cos(p * math.pi * 2) * 1.1
            local y = 1.2 + math.abs(math.sin(p * math.pi * 2)) * 2.2
            oEgg.CFrame = cf * CFrame.new(x, y, 0) * CFrame.Angles(u * 6 + i, u * 4, 0)
        end
        local iEgg = 0
        for _, o in t.oProps:GetChildren() do
            if o.Name == "Speckle" then
                iEgg += 1
                local oEgg = tEggs[(iEgg - 1) // 3 + 1]
                if oEgg then
                    o.CFrame = oEgg.CFrame * CFrame.new(o:GetAttribute("Offset") :: Vector3)
                end
            end
        end
    else -- TRexArms: tiny tucked arms flapping, high-knee stomps, the odd RAWR
        local s = math.sin(u * 9)
        Pose(t, "RightShoulder", CFrame.Angles(Rad(45), 0, Rad(-15)) * CFrame.Angles(0, 0, Rad(8 * s)))
        Pose(t, "LeftShoulder", CFrame.Angles(Rad(45), 0, Rad(15)) * CFrame.Angles(0, 0, Rad(-8 * s)))
        Pose(t, "RightElbow", CFrame.Angles(Rad(110 + 15 * s), 0, 0))
        Pose(t, "LeftElbow", CFrame.Angles(Rad(110 - 15 * s), 0, 0))
        local kr, kl = math.max(0, s), math.max(0, -s)
        Pose(t, "RightHip", CFrame.Angles(Rad(70 * kr), 0, 0))
        Pose(t, "LeftHip", CFrame.Angles(Rad(70 * kl), 0, 0))
        Pose(t, "RightKnee", CFrame.Angles(Rad(-80 * kr), 0, 0))
        Pose(t, "LeftKnee", CFrame.Angles(Rad(-80 * kl), 0, 0))
        Pose(t, "Waist", CFrame.Angles(Rad(-12), Rad(10 * s), 0))
        Pose(t, "Neck", CFrame.Angles(Rad(-15), 0, 0))
        Pose(t, "Root", CFrame.new(0, 0.15 * math.abs(s), 0))
        if nT - t.nLastRawr > 2.4 then
            t.nLastRawr = nT
            local oHead = t.oCharacter:FindFirstChild("Head")
            if oHead then Rawr(oHead :: BasePart) end
        end
    end
end

local mTraining = Module()

function mTraining.StartAsync(self)
    Players.PlayerRemoving:Connect(Stop)
    RunService.PreSimulation:Connect(ApplyPoses)
    RunService.Heartbeat:Connect(function()
        local nT = os.clock()
        local oCamera = Workspace.CurrentCamera
        local vCam = oCamera and oCamera.CFrame.Position or Vector3.zero
        for _, oPlayer in Players:GetPlayers() do
            local oCharacter = oPlayer.Character
            local oHumanoid = oCharacter and oCharacter:FindFirstChildOfClass("Humanoid")
            local oRoot = oCharacter and oCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
            local bTraining = (oPlayer:GetAttribute("OnPad") or 0) > 0
                and oHumanoid ~= nil and oHumanoid.Health > 0 and oRoot ~= nil
                and oHumanoid.MoveDirection.Magnitude < 0.1
                and oHumanoid.FloorMaterial ~= Enum.Material.Air
                and (oRoot.Position - vCam).Magnitude < VIEW_DISTANCE
            local t = tStates[oPlayer]
            if t and (not bTraining or t.oCharacter ~= oCharacter) then
                Stop(oPlayer)
                t = nil
            end
            if bTraining and oCharacter then
                t = t or Start(oPlayer, oCharacter)
                if t then
                    if nT >= t.nSwitchAt then
                        local sNext = t.sRoutine
                        while sNext == t.sRoutine do sNext = ROUTINES[math.random(#ROUTINES)] end
                        SetRoutine(t, sNext)
                        t.nSwitchAt = nT + math.random(SWITCH_MIN, SWITCH_MAX)
                    end
                    Animate(t, nT)
                end
            end
        end
    end)
end

return mTraining
