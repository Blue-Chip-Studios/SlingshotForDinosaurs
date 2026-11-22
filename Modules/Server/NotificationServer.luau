--[[
    NotificationServer
    ------------------
    Sends Roblox Experience Notifications through Open Cloud
    (POST /cloud/v2/users/{id}/notifications). The API key is read from a
    Roblox Secret, never from code. Disabled (no-op) until the secret and the
    message ids in Config/NotificationConfig exist.

    Also records the client's opt-in prompt so it is only shown once.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Module = require(ReplicatedStorage.Shared.Module)
local Remote = require(ReplicatedStorage.BCDKShared.Remote)
local NotificationConfig = require(ReplicatedStorage.Config.NotificationConfig)

local PlayerDataServer = require(ServerStorage.ServerModules.PlayerDataServer)
local AnalyticsServer = require(ServerStorage.ServerModules.AnalyticsServer)

local oSecret: Secret? = nil

local mNotification = Module()

function mNotification.IsEnabled(self): boolean
    return oSecret ~= nil
end

-- Sends sName to iUserId. tParams maps the message's {param} names to strings.
-- Returns true if Roblox accepted it. Yields; call from a spawned thread.
function mNotification.Send(self, iUserId: number, sName: string, tParams: { [string]: string }?, sLaunchData: string?): boolean
    local tMessage = NotificationConfig.Messages[sName]
    if not oSecret or not tMessage or tMessage.MessageId == "" then return false end
    local tParameters = {}
    for sKey, sValue in tParams or {} do
        tParameters[sKey] = { stringValue = tostring(sValue) }
    end
    local tBody = {
        source = { universe = "universes/" .. NotificationConfig.UniverseId },
        payload = {
            type = "MOMENT",
            messageId = tMessage.MessageId,
            parameters = tParameters,
            joinExperience = { launchData = sLaunchData or sName },
        },
    }
    local bOk, tResponse = pcall(HttpService.RequestAsync, HttpService, {
        Url = `https://apis.roblox.com/cloud/v2/users/{iUserId}/notifications`,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
            ["x-api-key"] = oSecret,
        } :: any,
        Body = HttpService:JSONEncode(tBody),
    })
    local bSent = bOk and tResponse.Success
    if not bSent then
        warn(`[Notification] {sName} to {iUserId} failed: {if bOk then tResponse.StatusCode else tResponse}`)
    end
    return bSent
end

function mNotification.PreloadAsync(self)
    local bOk, vSecret = pcall(HttpService.GetSecret, HttpService, NotificationConfig.SecretName)
    if bOk then
        oSecret = vSecret
    end

    Remote:GetEvent("NotificationPrompted"):OnServerEvent(function(oPlayer: Player, bOptedIn)
        if not PlayerDataServer:IsReady(oPlayer) or PlayerDataServer:Get(oPlayer, "NotificationsPrompted") then return end
        PlayerDataServer:Set(oPlayer, "NotificationsPrompted", true)
        AnalyticsServer:Custom(oPlayer, "NotificationOptIn", if bOptedIn == true then 1 else 0)
    end)
end

return mNotification
