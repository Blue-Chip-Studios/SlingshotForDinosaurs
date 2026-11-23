--[[
    SocialController
    ----------------
    Friend invites, the community group join prompt and the one-time
    favourite prompt (shown on the first mutated catch after a few launches,
    a moment the player is happy).
]]

local AvatarEditorService = game:GetService("AvatarEditorService")
local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Module = require(ReplicatedStorage.Shared.Module)
local Remote = require(ReplicatedStorage.BCDKShared.Remote)
local SocialConfig = require(ReplicatedStorage.Config.SocialConfig)
local DataClient = require(ReplicatedStorage.ClientModules.DataClient)
local Store = require(ReplicatedStorage.BCDKClient.LMGui.Store)
local peek = require(ReplicatedStorage.Packages.fusion).peek

-- Roblox's group/favourite prompts are modal and eat the next click, so only show them
-- once the player has been idle on the rim (not charging, flying, on the reveal card or in
-- a menu) for a few seconds in a row. Gives up after five minutes; it asks again next session.
local IDLE_SECONDS = 6
local function IsIdle(): boolean
    local V = Store.Values
    return not peek(V.Charging) and not peek(V.Flying) and peek(V.Reveal) == false
        and peek(V.Modal) == "" and not peek(V.PopupOpen)
end
local function WaitUntilIdle(): boolean -- also used by NotificationController (mSocial.WaitUntilIdle)
    local nIdleSince, nGiveUp = nil, os.clock() + 300
    while os.clock() < nGiveUp do
        if IsIdle() then
            nIdleSince = nIdleSince or os.clock()
            if os.clock() - nIdleSince >= IDLE_SECONDS then return true end
        else
            nIdleSince = nil
        end
        task.wait(0.25)
    end
    return false
end

local oLocalPlayer = Players.LocalPlayer
local bGroupAsked, bFavoriteAsked = false, false

local mSocial = Module()

-- Waits until the player has been idle (not charging, flying, revealing or in a menu) for a few
-- seconds, so system prompts never steal a click mid-launch. False if they never go idle.
function mSocial.WaitUntilIdle(self): boolean
    return WaitUntilIdle()
end

function mSocial.Invite(self)
    local bOk, bCan = pcall(SocialService.CanSendGameInviteAsync, SocialService, oLocalPlayer)
    if not (bOk and bCan) then return end
    local oConn
    oConn = SocialService.GameInvitePromptClosed:Connect(function(_, tRecipients)
        oConn:Disconnect()
        if typeof(tRecipients) == "table" and #tRecipients > 0 then
            Remote:GetEvent("SocialAction"):FireServer({ Action = "InviteSent" })
        end
    end)
    local oOptions = Instance.new("ExperienceInviteOptions")
    oOptions.PromptMessage = "Come catch dinos with me! Friends get bonus luck!"
    if not pcall(SocialService.PromptGameInvite, SocialService, oLocalPlayer, oOptions) then
        oConn:Disconnect() -- prompt never opened; don't leave a listener behind
    end
end

function mSocial.PromptGroup(self)
    local bOk, eStatus = pcall(GroupService.PromptJoinAsync, GroupService, SocialConfig.GroupId)
    local bJoined = bOk and (eStatus == Enum.GroupMembershipStatus.Joined or eStatus == Enum.GroupMembershipStatus.AlreadyMember)
    Remote:GetEvent("SocialAction"):FireServer({ Action = "GroupPrompted", Joined = bJoined })
end

function mSocial.StartAsync(self)
    -- One automatic group prompt once the player is invested.
    DataClient:Changed("TotalLaunches", function(iLaunches)
        if bGroupAsked or DataClient:Get("GroupPrompted") or oLocalPlayer:GetAttribute("GroupMember") then return end
        if (iLaunches or 0) < SocialConfig.GroupPromptAfterLaunches then return end
        bGroupAsked = true
        if WaitUntilIdle() then self:PromptGroup() else bGroupAsked = false end
    end)

    -- Favourite prompt on a happy moment: the first mutated catch.
    Remote:GetEvent("CatchResult"):OnClientEvent(function(tResult)
        if bFavoriteAsked or DataClient:Get("FavoritePrompted") then return end
        local tDino = typeof(tResult) == "table" and tResult.Dino
        if typeof(tDino) ~= "table" or tDino.Mutation == nil or tDino.Mutation == "Normal" then return end
        if (DataClient:Get("TotalLaunches") or 0) < SocialConfig.FavoritePromptAfterLaunches then return end
        bFavoriteAsked = true
        if not WaitUntilIdle() then bFavoriteAsked = false return end
        local oConn
        oConn = AvatarEditorService.PromptSetFavoriteCompleted:Connect(function(eResult)
            oConn:Disconnect()
            Remote:GetEvent("SocialAction"):FireServer({ Action = "FavoritePrompted", Favorited = eResult == Enum.AvatarPromptResult.Success })
        end)
        pcall(AvatarEditorService.PromptSetFavorite, AvatarEditorService, game.PlaceId, Enum.AvatarItemType.Asset, true)
    end)
end

return mSocial
