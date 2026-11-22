--[[
    LeaderboardServer
    -----------------
    Player-list leaderstats: Best distance and income per second, formatted
    as short strings ("12.4K m", "$3.2M/s") so big numbers stay readable.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Module = require(ReplicatedStorage.Shared.Module)
local Format = require(ReplicatedStorage.Shared.Format)

local PlayerDataServer = require(ServerStorage.ServerModules.PlayerDataServer)

local mLeaderboard = Module()

function mLeaderboard.PlayerAdded(self, oPlayer: Player)
    local oStats = Instance.new("Folder")
    oStats.Name = "leaderstats"
    local oBest = Instance.new("StringValue")
    oBest.Name = "Best"
    oBest.Value = "0 m"
    oBest.Parent = oStats
    local oIncome = Instance.new("StringValue")
    oIncome.Name = "$/s"
    oIncome.Value = "$0"
    oIncome.Parent = oStats
    oStats.Parent = oPlayer
end

function mLeaderboard.StartAsync(self)
    while true do
        task.wait(2)
        for _, oPlayer in Players:GetPlayers() do
            local oStats = oPlayer:FindFirstChild("leaderstats")
            if oStats and PlayerDataServer:IsReady(oPlayer) then
                oStats.Best.Value = Format.Meters(PlayerDataServer:Get(oPlayer, "BestDistance") or 0)
                oStats["$/s"].Value = Format.Cash(oPlayer:GetAttribute("Income") or 0)
            end
        end
    end
end

return mLeaderboard
