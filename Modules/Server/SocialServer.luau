--[[
    SocialServer
    ------------
    * FriendsHere attribute: how many of a player's friends are in this server
      (RetentionServer turns it into bonus luck).
    * GroupMember attribute: community group membership (EnclosureServer
      turns it into bonus income). Rechecked when the client reports a join.
    * Analytics for invites, group joins and favourite prompts.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Module = require(ReplicatedStorage.Shared.Module)
local Remote = require(ReplicatedStorage.BCDKShared.Remote)
local SocialConfig = require(ReplicatedStorage.Config.SocialConfig)

local PlayerDataServer = require(ServerStorage.ServerModules.PlayerDataServer)
local AnalyticsServer = require(ServerStorage.ServerModules.AnalyticsServer)

local tFriends: { [Player]: { [Player]: boolean } } = {}
local tLastAction: { [Player]: { [string]: number } } = {}
local tRechecking: { [Player]: boolean } = {}
local ACTION_COOLDOWN = 10

local function Recount()
    for oPlayer, tSet in tFriends do
        local n = 0
        for oOther in tSet do
            if oOther.Parent == Players then n += 1 end
        end
        oPlayer:SetAttribute("FriendsHere", n)
    end
end

local function CheckGroup(oPlayer: Player): boolean
    local bOk, bIn = pcall(oPlayer.IsInGroupAsync, oPlayer, SocialConfig.GroupId)
    local bMember = bOk and bIn == true
    oPlayer:SetAttribute("GroupMember", bMember)
    return bMember
end

local mSocial = Module()

local function Cleanup(oPlayer: Player)
    tFriends[oPlayer] = nil
    tLastAction[oPlayer] = nil
    tRechecking[oPlayer] = nil
    for _, tSet in tFriends do
        tSet[oPlayer] = nil
    end
    Recount()
end

function mSocial.PlayerAdded(self, oPlayer: Player)
    if oPlayer.Parent ~= Players then return end -- left during profile load
    tFriends[oPlayer] = {}
    task.spawn(CheckGroup, oPlayer)
    -- Friend lookups are web calls: never hold up other modules' PlayerAdded.
    task.spawn(function()
        for _, oOther in Players:GetPlayers() do
            if oOther ~= oPlayer and tFriends[oOther] then
                local bOk, bFriends = pcall(oPlayer.IsFriendsWith, oPlayer, oOther.UserId)
                if bOk and bFriends and tFriends[oPlayer] and tFriends[oOther] then
                    tFriends[oPlayer][oOther] = true
                    tFriends[oOther][oPlayer] = true
                end
            end
        end
        Recount()
    end)
end

function mSocial.PlayerRemoving(self, oPlayer: Player)
    Cleanup(oPlayer)
end

function mSocial.PreloadAsync(self)
    -- PlayerRemoving above only runs for players whose profile loaded; this catches the rest.
    Players.PlayerRemoving:Connect(Cleanup)

    Remote:GetEvent("SocialAction"):OnServerEvent(function(oPlayer: Player, tPayload)
        if typeof(tPayload) ~= "table" or not PlayerDataServer:IsReady(oPlayer) then return end
        local sAction = tPayload.Action
        if typeof(sAction) ~= "string" then return end
        -- Rate limit per action: these only drive analytics and a membership recheck.
        tLastAction[oPlayer] = tLastAction[oPlayer] or {}
        if os.clock() - (tLastAction[oPlayer][sAction] or -math.huge) < ACTION_COOLDOWN then return end
        tLastAction[oPlayer][sAction] = os.clock()

        if sAction == "InviteSent" then
            AnalyticsServer:Custom(oPlayer, "InviteSent", 1)
        elseif sAction == "GroupPrompted" then
            if PlayerDataServer:Get(oPlayer, "GroupPrompted") ~= true then
                PlayerDataServer:Set(oPlayer, "GroupPrompted", true)
            end
            if tPayload.Joined == true and not oPlayer:GetAttribute("GroupMember") and not tRechecking[oPlayer] then
                tRechecking[oPlayer] = true
                AnalyticsServer:Custom(oPlayer, "GroupJoined", 1)
                -- The server's membership cache can lag the join; retry briefly (one loop per player).
                task.spawn(function()
                    for _ = 1, 6 do
                        if oPlayer.Parent ~= Players or CheckGroup(oPlayer) then break end
                        task.wait(10)
                    end
                    tRechecking[oPlayer] = nil
                end)
            end
        elseif sAction == "FavoritePrompted" then
            if PlayerDataServer:Get(oPlayer, "FavoritePrompted") then return end
            PlayerDataServer:Set(oPlayer, "FavoritePrompted", true)
            AnalyticsServer:Custom(oPlayer, "FavoritePrompted", if tPayload.Favorited == true then 1 else 0)
        end
    end)
end

return mSocial
