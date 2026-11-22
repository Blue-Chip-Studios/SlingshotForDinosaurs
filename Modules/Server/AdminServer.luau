--[[
    AdminServer
    -----------
    Developer-only "Admin Abuse" panel for live events. Access is checked on
    the server for every action (UserId allowlist or group rank, always
    allowed in Studio); the client only sees the panel button when the
    player's IsAdmin attribute is true. Every action is logged to analytics.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TextService = game:GetService("TextService")

local Module = require(ReplicatedStorage.Shared.Module)
local Remote = require(ReplicatedStorage.BCDKShared.Remote)
local AdminConfig = require(ReplicatedStorage.Config.AdminConfig)

local AnalyticsServer = require(ServerStorage.ServerModules.AnalyticsServer)
local WeatherServer = require(ServerStorage.ServerModules.WeatherServer)
local LaunchServer = require(ServerStorage.ServerModules.LaunchServer)

local tAdmins: { [Player]: boolean } = {}
local tLastAction: { [Player]: number } = {}

local function CheckAdmin(oPlayer: Player): boolean
    if RunService:IsStudio() then
        return true
    end
    if table.find(AdminConfig.UserIds, oPlayer.UserId) then
        return true
    end
    local bOk, iRank = pcall(oPlayer.GetRankInGroup, oPlayer, AdminConfig.GroupId)
    return bOk and iRank >= AdminConfig.MinGroupRank
end

local mAdmin = Module()

function mAdmin.PlayerAdded(self, oPlayer: Player)
    local bAdmin = CheckAdmin(oPlayer)
    tAdmins[oPlayer] = bAdmin
    oPlayer:SetAttribute("IsAdmin", bAdmin)
end

function mAdmin.PreloadAsync(self)
    local oAnnounce = Remote:GetEvent("Announcement")
    Remote:GetEvent("AdminAction"):OnServerEvent(function(oPlayer: Player, tPayload)
        if not tAdmins[oPlayer] or typeof(tPayload) ~= "table" then return end
        if os.clock() - (tLastAction[oPlayer] or 0) < 0.5 then return end
        tLastAction[oPlayer] = os.clock()
        local sAction = tPayload.Action
        if sAction == "MeteorStorm" or sAction == "IceAge" then
            local nMinutes = if typeof(tPayload.Minutes) == "number" then math.clamp(tPayload.Minutes, 1, 60) else 5
            WeatherServer:TriggerEvent(sAction, nMinutes * 60)
        elseif sAction == "Clear" then
            WeatherServer:TriggerEvent("Clear", 1)
        elseif sAction == "Luck" then
            local nMult = if typeof(tPayload.Multiplier) == "number" then tPayload.Multiplier else 2
            local nMinutes = if typeof(tPayload.Minutes) == "number" then math.clamp(tPayload.Minutes, 1, 60) else 5
            if not table.find(AdminConfig.LuckOptions, nMult) then return end
            WeatherServer:SetServerLuck(nMult, nMinutes * 60)
        elseif sAction == "RareSpawn" then
            LaunchServer:ForceRareForAll()
            oAnnounce:FireAllClients({ Text = "RARE SPAWN! Your next launch catches a Legendary!", Kind = "Event" })
        elseif sAction == "Announce" then
            if typeof(tPayload.Text) ~= "string" then return end
            local sText = tPayload.Text:sub(1, 120)
            local bOk, oResult = pcall(TextService.FilterStringAsync, TextService, sText, oPlayer.UserId, Enum.TextFilterContext.PublicChat)
            if not bOk then return end
            local bOk2, sFiltered = pcall(oResult.GetNonChatStringForBroadcastAsync, oResult)
            if not bOk2 then return end
            oAnnounce:FireAllClients({ Text = sFiltered, Kind = "Admin" })
        else
            return
        end
        AnalyticsServer:Custom(oPlayer, "AdminAction", 1, AnalyticsServer:Fields(sAction))
    end)
end

function mAdmin.StartAsync(self)
    Players.PlayerRemoving:Connect(function(oPlayer)
        tAdmins[oPlayer] = nil
        tLastAction[oPlayer] = nil
    end)
end

return mAdmin
