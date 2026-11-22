--[[
    PlotServer
    ----------
    Assigns each player one of the eight rim plots, spawns them on it, and
    publishes a public "Plot" replica (owner + dino list) that every client
    uses to render that plot's dinosaurs. Data stays authoritative in
    PlayerDataServer; this is a read-only public mirror.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Module = require(ReplicatedStorage.Shared.Module)
local BCDK = require(ReplicatedStorage.BCDKShared.BCDK)
local ReplicaServer = require(ReplicatedStorage.External.Replica.ReplicaServer)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)

local PlayerDataServer = require(ServerStorage.ServerModules.PlayerDataServer)
local WorldBuilder = require(ServerStorage.ServerModules.WorldBuilder)

local oToken = BCDK.CreateToken("Plot")
local tPlotOwners: { [number]: Player } = {}
local tPlayerPlot: { [Player]: number } = {}
local tReplicas: { [Player]: any } = {}

local function PublicDinos(tDinos: { any }): { any }
    local tOut = {}
    for i, t in tDinos do
        tOut[i] = { Id = t.Id, Species = t.Species, Size = t.Size, Mutation = t.Mutation }
    end
    return tOut
end

local function SpawnOnPlot(oPlayer: Player, oCharacter: Model)
    local iPlot = tPlayerPlot[oPlayer]
    if not iPlot then return end
    local oRoot = oCharacter:WaitForChild("HumanoidRootPart", 10)
    if oRoot then
        task.wait() -- let the default spawn finish first
        oCharacter:PivotTo(WorldLayout.Plot(iPlot).Spawn)
    end
end

-- Assigns a plot on first use. Called from both PlayerAdded and the profile-ready
-- callback: BCDK runs SMProfile.PlayerAdded (which yields until the profile loads,
-- then fires OnReady) before project modules' PlayerAdded hooks, so either may come first.
local function EnsurePlot(oPlayer: Player): number?
    if tPlayerPlot[oPlayer] then
        return tPlayerPlot[oPlayer]
    end
    for i = 1, GameConfig.PlotCount do
        if not tPlotOwners[i] then
            tPlotOwners[i] = oPlayer
            tPlayerPlot[oPlayer] = i
            oPlayer:SetAttribute("PlotIndex", i)
            oPlayer.CharacterAdded:Connect(function(oCharacter)
                SpawnOnPlot(oPlayer, oCharacter)
            end)
            if oPlayer.Character then
                task.spawn(SpawnOnPlot, oPlayer, oPlayer.Character)
            end
            return i
        end
    end
    warn("[PlotServer] no free plot for", oPlayer.Name) -- MaxPlayers should prevent this
    return nil
end

local mPlot = Module()

function mPlot.PlayerAdded(self, oPlayer: Player)
    EnsurePlot(oPlayer)
end

function mPlot.StartAsync(self)
    PlayerDataServer:OnReady(function(oPlayer: Player)
        local iPlot = EnsurePlot(oPlayer)
        if not iPlot then return end
        local oReplica = ReplicaServer.New({
            Token = oToken,
            Tags = { UserId = oPlayer.UserId },
            Data = {
                PlotIndex = iPlot,
                OwnerName = oPlayer.DisplayName,
                Dinos = PublicDinos(PlayerDataServer:Get(oPlayer, "Dinos") or {}),
                Exclusive = PlayerDataServer:Get(oPlayer, "ExclusiveDino") == true,
                VIP = (PlayerDataServer:Get(oPlayer, "Passes") or {}).VIP == true,
            },
        })
        oReplica:Replicate()
        tReplicas[oPlayer] = oReplica
        local oModel = WorldBuilder:GetPlotModel(iPlot)
        local oSign = oModel and oModel:FindFirstChild("OwnerSign")
        if oSign then
            oSign.SurfaceGui.Text.Text = `{oPlayer.DisplayName}'s Park`
        end
    end)

    Players.PlayerRemoving:Connect(function(oPlayer)
        local iPlot = tPlayerPlot[oPlayer]
        if iPlot then
            tPlotOwners[iPlot] = nil
            local oModel = WorldBuilder:GetPlotModel(iPlot)
            local oSign = oModel and oModel:FindFirstChild("OwnerSign")
            if oSign then
                oSign.SurfaceGui.Text.Text = "Empty Plot"
            end
        end
        tPlayerPlot[oPlayer] = nil
        if tReplicas[oPlayer] then
            tReplicas[oPlayer]:Destroy()
            tReplicas[oPlayer] = nil
        end
    end)
end

-- Called by EnclosureServer whenever the dino list or plot flags change.
function mPlot.Refresh(self, oPlayer: Player)
    local oReplica = tReplicas[oPlayer]
    if not oReplica then return end
    oReplica:Set({ "Dinos" }, PublicDinos(PlayerDataServer:Get(oPlayer, "Dinos") or {}))
    oReplica:Set({ "Exclusive" }, PlayerDataServer:Get(oPlayer, "ExclusiveDino") == true)
    oReplica:Set({ "VIP" }, (PlayerDataServer:Get(oPlayer, "Passes") or {}).VIP == true)
end

function mPlot.GetPlot(self, oPlayer: Player): number?
    return tPlayerPlot[oPlayer]
end

return mPlot
