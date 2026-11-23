--[[
    PetController
    -------------
    Draws every player's equipped pet (their "Pet" attribute, set by PetServer) as a plush
    mini dino trailing beside its owner. It hops along while the owner moves, turns to face
    where it's going, and uses the shared idle animation (breathing, looking around, yawns)
    when standing. Flying pets hover and bob instead of hopping. Client-side CFrame only.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Module = require(ReplicatedStorage.Shared.Module)
local PetConfig = require(ReplicatedStorage.Config.PetConfig)
local DinoModels = require(ReplicatedStorage.ClientModules.DinoModels)

local PET_HEIGHT = 2.6       -- studs, standing pets
local FLY_HEIGHT = 2.2
local OFFSET = Vector3.new(2.6, 0, 2.2) -- beside and a little behind the owner (owner space)
local FOLLOW_SPEED = 9       -- how quickly the pet catches up (higher = snappier)
local VIEW_DISTANCE = 200

type PetState = { sId: string, oModel: Model, vPos: Vector3, vLook: Vector3, tIdle: any, nHop: number, bFlies: boolean }
local tPets: { [Player]: PetState } = {}
local oFolder: Folder

local function Remove(oPlayer: Player)
    local t = tPets[oPlayer]
    if t then
        t.oModel:Destroy()
        tPets[oPlayer] = nil
    end
end

local function Spawn(oPlayer: Player, sId: string, oRoot: BasePart): PetState?
    local tPet = PetConfig.Get(sId)
    if not tPet then return nil end
    local ok, oModel = pcall(DinoModels.Build, { Species = tPet.Species, Size = "Normal", Mutation = tPet.Mutation or "Normal" })
    if not ok or not oModel then return nil end
    oModel:ScaleTo(oModel:GetScale() * (if tPet.Flies then FLY_HEIGHT else PET_HEIGHT) / math.max(oModel:GetExtentsSize().Y, 0.1))
    for _, o in oModel:GetDescendants() do
        if o:IsA("BillboardGui") then o:Destroy() end
    end
    oModel.Name = "Pet_" .. oPlayer.UserId
    oModel.Parent = oFolder
    local vStart = (oRoot.CFrame * CFrame.new(OFFSET)).Position
    local t: PetState = {
        sId = sId, oModel = oModel, vPos = vStart, vLook = oRoot.CFrame.LookVector,
        tIdle = DinoModels.NewIdleState(), nHop = 0, bFlies = tPet.Flies == true,
    }
    tPets[oPlayer] = t
    return t
end

-- Feet height under the owner (their HumanoidRootPart sits HipHeight + half its size above the floor).
local function FloorY(oRoot: BasePart, oHumanoid: Humanoid): number
    return oRoot.Position.Y - oRoot.Size.Y / 2 - oHumanoid.HipHeight
end

local mPet = Module()

function mPet.StartAsync(self)
    oFolder = Instance.new("Folder")
    oFolder.Name = "Pets"
    oFolder.Parent = Workspace
    Players.PlayerRemoving:Connect(Remove)
    RunService.Heartbeat:Connect(function(nDt)
        local oCamera = Workspace.CurrentCamera
        local vCam = oCamera and oCamera.CFrame.Position or Vector3.zero
        local nT = os.clock()
        for _, oPlayer in Players:GetPlayers() do
            local sId = oPlayer:GetAttribute("Pet") or ""
            local oCharacter = oPlayer.Character
            local oRoot = oCharacter and oCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
            local oHumanoid = oCharacter and oCharacter:FindFirstChildOfClass("Humanoid")
            local t = tPets[oPlayer]
            local bShow = sId ~= "" and oRoot ~= nil and oHumanoid ~= nil and oHumanoid.Health > 0
                and (oRoot.Position - vCam).Magnitude < VIEW_DISTANCE
            if t and (not bShow or t.sId ~= sId) then
                Remove(oPlayer)
                t = nil
            end
            if bShow and oRoot and oHumanoid then
                t = t or Spawn(oPlayer, sId, oRoot)
                if t then
                    local vGoal = (oRoot.CFrame * CFrame.new(OFFSET)).Position
                    local nFloor = FloorY(oRoot, oHumanoid)
                    vGoal = Vector3.new(vGoal.X, nFloor, vGoal.Z)
                    -- Teleports / respawns: snap rather than sprint across the map.
                    if (vGoal - t.vPos).Magnitude > 40 then t.vPos = vGoal end
                    local vFlat = Vector3.new(vGoal.X - t.vPos.X, 0, vGoal.Z - t.vPos.Z)
                    local nDist = vFlat.Magnitude
                    t.vPos = t.vPos:Lerp(vGoal, math.min(1, nDt * FOLLOW_SPEED * math.clamp(nDist / 3, 0.35, 1.5)))
                    local bMoving = nDist > 0.6
                    if bMoving then
                        t.vLook = t.vLook:Lerp(vFlat.Unit, math.min(1, nDt * 8))
                        t.nHop += nDt * 11
                    else
                        -- Standing: face the same way as the owner.
                        t.vLook = t.vLook:Lerp(oRoot.CFrame.LookVector, math.min(1, nDt * 3))
                    end
                    local vFeet = t.vPos
                    if t.bFlies then
                        vFeet += Vector3.new(0, 2.6 + math.sin(nT * 2.4) * 0.35, 0)
                    end
                    if bMoving and not t.bFlies then
                        -- Hop: a bouncy arc per step with legs swinging.
                        local nHopY = math.abs(math.sin(t.nHop)) * 0.55
                        DinoModels.PlaceAt(t.oModel, vFeet + Vector3.new(0, nHopY, 0), t.vLook)
                        DinoModels.Pose(t.oModel, t.nHop * 2, 0.5)
                        DinoModels.WalkArticulate(t.oModel, t.nHop * 2)
                    elseif bMoving then
                        DinoModels.PlaceAt(t.oModel, vFeet, t.vLook)
                        DinoModels.WalkArticulate(t.oModel, nT * 6)
                    else
                        DinoModels.PlaceAt(t.oModel, vFeet, t.vLook)
                        DinoModels.Idle(t.oModel, vFeet, t.vLook, t.tIdle)
                    end
                end
            end
        end
    end)
end

return mPet
