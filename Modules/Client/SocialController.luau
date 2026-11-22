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

local oLocalPlayer = Players.LocalPlayer
local bGroupAsked, bFavoriteAsked = false, false

local mSocial = Module()

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
        task.wait(5)
        self:PromptGroup()
    end)

    -- Favourite prompt on a happy moment: the first mutated catch.
    Remote:GetEvent("CatchResult"):OnClientEvent(function(tResult)
        if bFavoriteAsked or DataClient:Get("FavoritePrompted") then return end
        local tDino = typeof(tResult) == "table" and tResult.Dino
        if typeof(tDino) ~= "table" or tDino.Mutation == nil or tDino.Mutation == "Normal" then return end
        if (DataClient:Get("TotalLaunches") or 0) < SocialConfig.FavoritePromptAfterLaunches then return end
        bFavoriteAsked = true
        task.wait(4) -- after the reveal
        local oConn
        oConn = AvatarEditorService.PromptSetFavoriteCompleted:Connect(function(eResult)
            oConn:Disconnect()
            Remote:GetEvent("SocialAction"):FireServer({ Action = "FavoritePrompted", Favorited = eResult == Enum.AvatarPromptResult.Success })
        end)
        pcall(AvatarEditorService.PromptSetFavorite, AvatarEditorService, game.PlaceId, Enum.AvatarItemType.Asset, true)
    end)
end

return mSocial
