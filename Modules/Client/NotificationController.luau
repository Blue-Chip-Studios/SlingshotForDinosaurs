--[[
    NotificationController
    ----------------------
    Shows Roblox's Experience Notifications opt-in prompt once, after the
    player has launched NotificationConfig.PromptAfterLaunches times and isn't
    busy (it waits until they're idle, like the social prompts). Roblox only allows it for eligible (13+) users; for everyone
    else CanPromptOptInAsync is false and nothing happens.
]]

local ExperienceNotificationService = game:GetService("ExperienceNotificationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Module = require(ReplicatedStorage.Shared.Module)
local Remote = require(ReplicatedStorage.BCDKShared.Remote)
local NotificationConfig = require(ReplicatedStorage.Config.NotificationConfig)
local DataClient = require(ReplicatedStorage.ClientModules.DataClient)
local SocialController = require(ReplicatedStorage.ClientModules.SocialController)

local bDone = false

local function TryPrompt()
    -- Studio playtests can't answer it (and Roblox sends no notifications from Studio), so it
    -- would pop up over every test session.
    if bDone or RunService:IsStudio() or DataClient:Get("NotificationsPrompted") then return end
    if (DataClient:Get("TotalLaunches") or 0) < NotificationConfig.PromptAfterLaunches then return end
    bDone = true
    -- Only once the player is idle (never mid-charge, mid-flight or during a catch reveal).
    if not SocialController:WaitUntilIdle() then bDone = false return end
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
