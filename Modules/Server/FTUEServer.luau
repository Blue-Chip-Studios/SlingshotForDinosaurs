--[[
    FTUEServer
    ----------
    Persists first-time-user-experience progress (FTUEStep in PlayerData) and
    logs each step to the onboarding funnel. The client's FTUEController
    reads FTUEStep from the replica to decide which hint to show, so a
    rejoining player resumes where they left off.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Module = require(ReplicatedStorage.Shared.Module)
local AnalyticsConfig = require(ReplicatedStorage.Config.AnalyticsConfig)

local PlayerDataServer = require(ServerStorage.ServerModules.PlayerDataServer)
local AnalyticsServer = require(ServerStorage.ServerModules.AnalyticsServer)

local mFTUE = Module()

function mFTUE.StartAsync(self)
    PlayerDataServer:OnReady(function(oPlayer)
        self:Reach(oPlayer, "Joined")
    end)
end

-- Records that the player reached sStep (a key of AnalyticsConfig.OnboardingSteps).
function mFTUE.Reach(self, oPlayer: Player, sStep: string)
    local iStep = AnalyticsConfig.OnboardingSteps[sStep]
    if not iStep then
        warn("[FTUE] unknown step", sStep)
        return
    end
    AnalyticsServer:Onboarding(oPlayer, sStep)
    local iCurrent = PlayerDataServer:Get(oPlayer, "FTUEStep") or 0
    if iStep > iCurrent then
        PlayerDataServer:Set(oPlayer, "FTUEStep", iStep)
    end
end

function mFTUE.IsDone(self, oPlayer: Player): boolean
    return (PlayerDataServer:Get(oPlayer, "FTUEStep") or 0) >= AnalyticsConfig.OnboardingSteps.FirstUpgrade
end

return mFTUE
