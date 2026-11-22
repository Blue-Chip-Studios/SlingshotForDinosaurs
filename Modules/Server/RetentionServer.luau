--[[
    RetentionServer
    ---------------
    Reasons to come back and keep playing (Config/RetentionConfig):
      * 7-day login streak (ClaimDaily)
      * Daily quests + one weekly quest (Track / ClaimQuest)
      * Promo codes (RedeemCode)
      * Rebirth (Rebirth): permanent Power/distance multiplier
      * Timed personal luck boosts (potions, rewards) and the 2x Luck pass
      * Perfect-bounce streak luck
    Every grant is server-side; the client only asks.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Module = require(ReplicatedStorage.Shared.Module)
local Remote = require(ReplicatedStorage.BCDKShared.Remote)
local RetentionConfig = require(ReplicatedStorage.Config.RetentionConfig)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local QuestPicker = require(ReplicatedStorage.Shared.QuestPicker)
local SocialConfig = require(ReplicatedStorage.Config.SocialConfig)

local PlayerDataServer = require(ServerStorage.ServerModules.PlayerDataServer)
local AnalyticsServer = require(ServerStorage.ServerModules.AnalyticsServer)
local EnclosureServer = require(ServerStorage.ServerModules.EnclosureServer)
local BadgeServer = require(ServerStorage.ServerModules.BadgeServer)

local tBusy: { [Player]: boolean } = {}

local function Now(): number
    return Workspace:GetServerTimeNow()
end

local function HasPass(oPlayer: Player, sKey: string): boolean
    local t = PlayerDataServer:Get(oPlayer, "Passes")
    return typeof(t) == "table" and t[sKey] == true
end

local mRetention = Module()

-- ===== Rewards =====

function mRetention.AddLuckBoost(self, oPlayer: Player, nMultiplier: number, nMinutes: number)
    local nNow = Now()
    local nEnds = PlayerDataServer:Get(oPlayer, "LuckBoostEndsAt") or 0
    local nMult = PlayerDataServer:Get(oPlayer, "LuckBoostMult") or 1
    if nEnds <= nNow then
        nEnds, nMult = nNow, 1
    end
    PlayerDataServer:Set(oPlayer, "LuckBoostMult", math.max(nMult, nMultiplier))
    PlayerDataServer:Set(oPlayer, "LuckBoostEndsAt", nEnds + nMinutes * 60)
end

-- Applies a reward table; returns a short description for the UI.
function mRetention.Grant(self, oPlayer: Player, tReward, sSource: string): string
    if tReward.Kind == "Cash" then
        local nAmount = math.max(tReward.Min or 0, math.floor(EnclosureServer:GetIncome(oPlayer) * 60 * (tReward.Minutes or 1)))
        PlayerDataServer:AddCash(oPlayer, nAmount)
        AnalyticsServer:Economy(oPlayer, Enum.AnalyticsEconomyFlowType.Source, "Cash", nAmount, PlayerDataServer:Get(oPlayer, "Cash") or 0, Enum.AnalyticsEconomyTransactionType.Gameplay.Name, sSource)
        return "$" .. tostring(nAmount)
    elseif tReward.Kind == "Reroll" then
        PlayerDataServer:Set(oPlayer, "Rerolls", (PlayerDataServer:Get(oPlayer, "Rerolls") or 0) + tReward.Amount)
        return `{tReward.Amount} Reroll`
    elseif tReward.Kind == "Luck" then
        self:AddLuckBoost(oPlayer, tReward.Multiplier, tReward.Minutes)
        return `{tReward.Multiplier}x Luck {tReward.Minutes}m`
    end
    return ""
end

-- ===== Luck / multipliers used by LaunchServer and TrainingServer =====

function mRetention.GetLuckMultiplier(self, oPlayer: Player): number
    local n = 1
    if HasPass(oPlayer, "DoubleLuck") then n *= 2 end
    if (PlayerDataServer:Get(oPlayer, "LuckBoostEndsAt") or 0) > Now() then
        n *= PlayerDataServer:Get(oPlayer, "LuckBoostMult") or 1
    end
    local tStreak = RetentionConfig.PerfectStreak
    local iStreak = math.min(PlayerDataServer:Get(oPlayer, "PerfectStreak") or 0, tStreak.MaxSteps)
    -- Playing with friends: +10% luck per friend here (SocialServer sets FriendsHere).
    local iFriends = math.min(oPlayer:GetAttribute("FriendsHere") or 0, SocialConfig.FriendLuckMaxFriends)
    n *= 1 + iFriends * SocialConfig.FriendLuckPerFriend
    return n * (1 + iStreak * tStreak.LuckPerStep)
end

function mRetention.GetRebirthBonus(self, oPlayer: Player): number
    return 1 + (PlayerDataServer:Get(oPlayer, "Rebirths") or 0) * RetentionConfig.Rebirth.BonusPerRebirth
end

-- Called by LaunchServer for every bounce result ("Perfect" | "Good" | "OK" | "Miss").
function mRetention.OnBounce(self, oPlayer: Player, sQuality: string)
    if sQuality == "Perfect" then
        PlayerDataServer:Set(oPlayer, "PerfectStreak", (PlayerDataServer:Get(oPlayer, "PerfectStreak") or 0) + 1)
        self:Track(oPlayer, "Perfect", 1)
    else
        PlayerDataServer:Set(oPlayer, "PerfectStreak", 0)
    end
end

-- ===== Quests =====

local function RollOver(oPlayer: Player)
    local iDay = QuestPicker.Today()
    if (PlayerDataServer:Get(oPlayer, "QuestDay") or 0) ~= iDay then
        PlayerDataServer:Set(oPlayer, "QuestDay", iDay)
        PlayerDataServer:Set(oPlayer, "QuestProgress", {})
        PlayerDataServer:Set(oPlayer, "QuestClaimed", {})
    end
    local iWeek = QuestPicker.Week()
    if (PlayerDataServer:Get(oPlayer, "WeekIndex") or 0) ~= iWeek then
        PlayerDataServer:Set(oPlayer, "WeekIndex", iWeek)
        PlayerDataServer:Set(oPlayer, "WeeklyProgress", 0)
        PlayerDataServer:Set(oPlayer, "WeeklyClaimed", false)
    end
end

-- Adds progress to any of today's quests (and the weekly) that track sTrack.
function mRetention.Track(self, oPlayer: Player, sTrack: string, nAmount: number)
    if not PlayerDataServer:IsReady(oPlayer) then return end
    RollOver(oPlayer)
    for _, tQuest in QuestPicker.Daily(oPlayer.UserId) do
        if tQuest.Id == sTrack then
            PlayerDataServer:Update(oPlayer, "QuestProgress", function(t)
                t = t or {}
                t[sTrack] = math.min((t[sTrack] or 0) + nAmount, tQuest.Goal)
                return t
            end)
        end
    end
    local tWeekly = RetentionConfig.WeeklyQuest
    if tWeekly.Track == sTrack then
        PlayerDataServer:Set(oPlayer, "WeeklyProgress", math.min((PlayerDataServer:Get(oPlayer, "WeeklyProgress") or 0) + nAmount, tWeekly.Goal))
    end
end

-- ===== Lifecycle / remotes =====

function mRetention.PreloadAsync(self)
    Remote:GetFunction("ClaimDaily"):OnServerInvoke(function(oPlayer: Player)
        if tBusy[oPlayer] or not PlayerDataServer:IsReady(oPlayer) then return { Ok = false } end
        tBusy[oPlayer] = true
        local iDay = QuestPicker.Today()
        local iLast = PlayerDataServer:Get(oPlayer, "LastDailyDay") or 0
        local tResult
        if iLast == iDay then
            tResult = { Ok = false, Reason = "Claimed" }
        else
            local iStreak = if iLast == iDay - 1 then (PlayerDataServer:Get(oPlayer, "DailyStreak") or 0) + 1 else 1
            local iSlot = ((iStreak - 1) % #RetentionConfig.Daily) + 1
            local tReward = RetentionConfig.Daily[iSlot]
            local sGot = self:Grant(oPlayer, tReward, "DailyReward")
            if tReward.Bonus then
                sGot ..= " + " .. self:Grant(oPlayer, tReward.Bonus, "DailyReward")
            end
            PlayerDataServer:Set(oPlayer, "DailyStreak", iStreak)
            PlayerDataServer:Set(oPlayer, "LastDailyDay", iDay)
            AnalyticsServer:Custom(oPlayer, "DailyClaim", iStreak)
            tResult = { Ok = true, Got = sGot, Streak = iStreak }
        end
        tBusy[oPlayer] = nil
        return tResult
    end)

    Remote:GetFunction("ClaimQuest"):OnServerInvoke(function(oPlayer: Player, sId)
        if typeof(sId) ~= "string" or tBusy[oPlayer] or not PlayerDataServer:IsReady(oPlayer) then return { Ok = false } end
        tBusy[oPlayer] = true
        RollOver(oPlayer)
        local tResult = { Ok = false, Reason = "NotDone" }
        if sId == RetentionConfig.WeeklyQuest.Id then
            local tWeekly = RetentionConfig.WeeklyQuest
            if not PlayerDataServer:Get(oPlayer, "WeeklyClaimed") and (PlayerDataServer:Get(oPlayer, "WeeklyProgress") or 0) >= tWeekly.Goal then
                PlayerDataServer:Set(oPlayer, "WeeklyClaimed", true)
                tResult = { Ok = true, Got = self:Grant(oPlayer, tWeekly.Reward, "WeeklyQuest") }
                AnalyticsServer:Custom(oPlayer, "QuestComplete", 1, AnalyticsServer:Fields(sId))
            end
        else
            for _, tQuest in QuestPicker.Daily(oPlayer.UserId) do
                if tQuest.Id == sId then
                    local tProgress = PlayerDataServer:Get(oPlayer, "QuestProgress") or {}
                    local tClaimed = PlayerDataServer:Get(oPlayer, "QuestClaimed") or {}
                    if not tClaimed[sId] and (tProgress[sId] or 0) >= tQuest.Goal then
                        PlayerDataServer:Update(oPlayer, "QuestClaimed", function(t)
                            t = t or {}
                            t[sId] = true
                            return t
                        end)
                        tResult = { Ok = true, Got = self:Grant(oPlayer, tQuest.Reward, "DailyQuest") }
                        AnalyticsServer:Custom(oPlayer, "QuestComplete", 1, AnalyticsServer:Fields(sId))
                    end
                end
            end
        end
        tBusy[oPlayer] = nil
        return tResult
    end)

    Remote:GetFunction("RedeemCode"):OnServerInvoke(function(oPlayer: Player, sCode)
        if typeof(sCode) ~= "string" or tBusy[oPlayer] or not PlayerDataServer:IsReady(oPlayer) then return { Ok = false } end
        sCode = sCode:upper():gsub("%s", ""):sub(1, 24)
        local tCode = RetentionConfig.Codes[sCode]
        if not tCode or (tCode.Expires > 0 and os.time() > tCode.Expires) then
            return { Ok = false, Reason = "Invalid" }
        end
        local tUsed = PlayerDataServer:Get(oPlayer, "CodesRedeemed") or {}
        if tUsed[sCode] then
            return { Ok = false, Reason = "Used" }
        end
        tBusy[oPlayer] = true
        PlayerDataServer:Update(oPlayer, "CodesRedeemed", function(t)
            t = t or {}
            t[sCode] = os.time()
            return t
        end)
        local tGot = {}
        for _, tReward in tCode.Rewards do
            table.insert(tGot, self:Grant(oPlayer, tReward, "Code"))
        end
        AnalyticsServer:Custom(oPlayer, "CodeRedeemed", 1, AnalyticsServer:Fields(sCode))
        tBusy[oPlayer] = nil
        return { Ok = true, Got = table.concat(tGot, " + ") }
    end)

    Remote:GetFunction("Rebirth"):OnServerInvoke(function(oPlayer: Player)
        if tBusy[oPlayer] or not PlayerDataServer:IsReady(oPlayer) then return { Ok = false } end
        local tCfg = RetentionConfig.Rebirth
        local iRebirths = PlayerDataServer:Get(oPlayer, "Rebirths") or 0
        local nCost = tCfg.BaseCost * tCfg.CostGrowth ^ iRebirths
        if (PlayerDataServer:Get(oPlayer, "BestDistance") or 0) < tCfg.RequiredMeters then
            return { Ok = false, Reason = "Distance" }
        end
        tBusy[oPlayer] = true
        local tResult
        if PlayerDataServer:SpendCash(oPlayer, nCost) then
            -- Reset the launch progression; dinos, Index, slots and purchases are kept.
            PlayerDataServer:SpendCash(oPlayer, PlayerDataServer:Get(oPlayer, "Cash") or 0) -- via the currency replica
            PlayerDataServer:Set(oPlayer, "Power", GameConfig.StartingPower)
            PlayerDataServer:Set(oPlayer, "Slingshot", "Twig")
            PlayerDataServer:Set(oPlayer, "Bait", "Berries")
            PlayerDataServer:Set(oPlayer, "Rebirths", iRebirths + 1)
            BadgeServer:Award(oPlayer, "Rebirth")
            AnalyticsServer:Progression(oPlayer, "Rebirth", Enum.AnalyticsProgressionType.Complete, iRebirths + 1)
            tResult = { Ok = true, Rebirths = iRebirths + 1 }
        else
            tResult = { Ok = false, Reason = "Cash" }
        end
        tBusy[oPlayer] = nil
        return tResult
    end)
end

function mRetention.StartAsync(self)
    PlayerDataServer:OnReady(function(oPlayer)
        RollOver(oPlayer)
        -- Premium flag for the income bonus (EnclosureServer reads the attribute).
        oPlayer:SetAttribute("Premium", oPlayer.MembershipType == Enum.MembershipType.Premium)
    end)
    Players.PlayerMembershipChanged:Connect(function(oPlayer)
        oPlayer:SetAttribute("Premium", oPlayer.MembershipType == Enum.MembershipType.Premium)
    end)
    Players.PlayerRemoving:Connect(function(oPlayer)
        tBusy[oPlayer] = nil
    end)
end

return mRetention
