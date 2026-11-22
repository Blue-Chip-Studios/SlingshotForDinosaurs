--[[
    BadgeServer
    -----------
    Awards Config/BadgeConfig badges. Other servers call Award(player, key);
    ids that are 0 (not created yet) are skipped. Each badge is checked at
    most once per player per session so we never spam BadgeService.
]]

local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Module = require(ReplicatedStorage.Shared.Module)
local BadgeConfig = require(ReplicatedStorage.Config.BadgeConfig)

local AnalyticsServer = require(ServerStorage.ServerModules.AnalyticsServer)

local tAwarded: { [Player]: { [string]: boolean } } = {}

local mBadge = Module()

function mBadge.Award(self, oPlayer: Player, sKey: string)
    local tBadge = BadgeConfig[sKey]
    if not tBadge or tBadge.Id == 0 then return end
    tAwarded[oPlayer] = tAwarded[oPlayer] or {}
    if tAwarded[oPlayer][sKey] then return end
    tAwarded[oPlayer][sKey] = true
    task.spawn(function()
        local bOk, bHas = pcall(BadgeService.UserHasBadgeAsync, BadgeService, oPlayer.UserId, tBadge.Id)
        if bOk and bHas then return end
        local bAwardOk, vResult = pcall(BadgeService.AwardBadge, BadgeService, oPlayer.UserId, tBadge.Id)
        if bAwardOk and vResult then
            AnalyticsServer:Custom(oPlayer, "BadgeEarned", 1, AnalyticsServer:Fields(sKey))
        elseif tAwarded[oPlayer] then
            tAwarded[oPlayer][sKey] = nil -- retry on the next trigger
        end
    end)
end

function mBadge.PlayerRemoving(self, oPlayer: Player)
    tAwarded[oPlayer] = nil
end

return mBadge
