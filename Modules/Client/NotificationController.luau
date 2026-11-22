--[[
    NotificationController
    ----------------------
    Shows Roblox's Experience Notifications opt-in prompt once, after the
    player has launched NotificationConfig.PromptAfterLaunches times and isn't
    mid-flight. Roblox only allows it for eligible (13+) users; for everyone
    else CanPromptOptInAsync is false and nothing happens.
]]

local ExperienceNotificationService = game:GetService("ExperienceNotificationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Module = require(ReplicatedStorage.Shared.Module)
local Remote = require(ReplicatedStorage.BCDKShared.Remote)
local NotificationConfig = require(ReplicatedStorage.Config.NotificationConfig)
local DataClient = require(ReplicatedStorage.ClientModules.DataClient)

local bDone = false

local function TryPrompt()
    if bDone or DataClient:Get("NotificationsPrompted") then return end
    if (DataClient:Get("TotalLaunches") or 0) < NotificationConfig.PromptAfterLaunches then return end
    bDone = true
    -- Let the catch celebration finish first.
    task.wait(6)
    local bOk, bCan = pcall(ExperienceNotificationService.CanPromptOptInAsync, ExperienceNotificationService)
    if not (bOk and bCan) then return end
    local oConn
    oConn = ExperienceNotificationService.OptInPromptClosed:Connect(function()
        oConn:Disconnect()
        local bOkCheck, bStill = pcall(ExperienceNotificationService.CanPromptOptInAsync, ExperienceNotificationService)
        -- After accepting, the prompt can no longer be shown.
        Remote:GetEvent("NotificationPrompted"):FireServer(bOkCheck and not bStill)
    end)
    pcall(ExperienceNotificationService.PromptOptIn, ExperienceNotificationService)
end

local mNotification = Module()

function mNotification.StartAsync(self)
    DataClient:Changed("TotalLaunches", function()
        task.spawn(TryPrompt)
    end)
    task.spawn(TryPrompt)
end

return mNotification
