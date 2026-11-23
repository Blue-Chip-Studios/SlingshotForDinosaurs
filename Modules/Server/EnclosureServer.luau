--[[
    EnclosureServer
    ---------------
    Owns the player's dinosaurs: placement, the full-enclosure choice,
    income every second, offline earnings with the Welcome Back payout,
    mutation rerolls and the exclusive dino.

    Income per second = sum(dino incomes) + exclusive bonus, then x2 with the
    2x Cash pass and x1.25 with VIP. Offline = 50% of that, capped at 8h (12h VIP).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Module = require(ReplicatedStorage.Shared.Module)
local Remote = require(ReplicatedStorage.BCDKShared.Remote)
local DinoConfig = require(ReplicatedStorage.Config.DinoConfig)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local ShopConfig = require(ReplicatedStorage.Config.ShopConfig)
local MonetizationConfig = require(ReplicatedStorage.Config.MonetizationConfig)
local PetConfig = require(ReplicatedStorage.Config.PetConfig)
local RetentionConfig = require(ReplicatedStorage.Config.RetentionConfig)
local SocialConfig = require(ReplicatedStorage.Config.SocialConfig)
local ExclusiveRotation = require(ReplicatedStorage.Shared.ExclusiveRotation)

local PlayerDataServer = require(ServerStorage.ServerModules.PlayerDataServer)
local AnalyticsServer = require(ServerStorage.ServerModules.AnalyticsServer)
local PlotServer = require(ServerStorage.ServerModules.PlotServer)
local WeatherServer = require(ServerStorage.ServerModules.WeatherServer)
local CatchRoller = require(ServerStorage.ServerModules.CatchRoller)

local FULL_CHOICE_TIMEOUT = 30

type Dino = { Id: number, Species: string, Size: string, Mutation: string, CaughtAt: number }

-- Pending catches waiting for the player's "replace or sell" answer.
local tPendingFull: { [Player]: { tDino: Dino, nExpires: number } } = {}
local tRerollBusy: { [Player]: boolean } = {}

local oEnclosureFull, oResolveFull, oCollectOffline, oReroll, oSetSetting

local function HasPass(oPlayer: Player, sKey: string): boolean
    local tPasses = PlayerDataServer:Get(oPlayer, "Passes")
    return typeof(tPasses) == "table" and tPasses[sKey] == true
end

local mEnclosure = Module()

function mEnclosure.GetSlotCount(self, oPlayer: Player): number
    local iTier = PlayerDataServer:Get(oPlayer, "SlotTier") or 1
    local tTier = ShopConfig.Slots[math.clamp(iTier, 1, #ShopConfig.Slots)]
    return tTier.Slots + (if HasPass(oPlayer, "VIP") then ShopConfig.VIPExtraSlots else 0)
end

function mEnclosure.GetIncome(self, oPlayer: Player): number
    local tDinos = PlayerDataServer:Get(oPlayer, "Dinos") or {}
    local nTotal, nBest = 0, 0
    for _, tDino in tDinos do
        local n = DinoConfig.GetIncome(tDino)
        nTotal += n
        nBest = math.max(nBest, n)
    end
    -- Exclusives: the best owned earns Multiplier x the best regular dino; each extra adds +100% (DECISIONS #34).
    local iExclusives = 0
    for _ in PlayerDataServer:Get(oPlayer, "ExclusiveDinos") or {} do
        iExclusives += 1
    end
    if iExclusives > 0 then
        local tRot = MonetizationConfig.ExclusiveRotation
        nTotal += nBest * (tRot.Multiplier + (iExclusives - 1) * tRot.ExtraEachMultiplier)
    end
    if HasPass(oPlayer, "DoubleCash") then nTotal *= 2 end
    if HasPass(oPlayer, "VIP") then nTotal *= 1.25 end
    if oPlayer:GetAttribute("Premium") then nTotal *= 1 + RetentionConfig.PremiumIncomeBonus end
    if oPlayer:GetAttribute("GroupMember") then nTotal *= 1 + SocialConfig.GroupIncomeBonus end
    -- Rebirths: permanent income bonus (the reward for resetting the run).
    nTotal *= 1 + (PlayerDataServer:Get(oPlayer, "Rebirths") or 0) * RetentionConfig.Rebirth.IncomePerRebirth
    -- Equipped pet perk.
    nTotal *= PetConfig.Multiplier(PlayerDataServer:Get(oPlayer, "EquippedPet"), "Cash")
    return nTotal
end

local function WeakestIndex(tDinos: { Dino }): (number?, number)
    local iWeakest, nWeakest = nil, math.huge
    for i, tDino in tDinos do
        local n = DinoConfig.GetIncome(tDino)
        if n < nWeakest then
            iWeakest, nWeakest = i, n
        end
    end
    return iWeakest, nWeakest
end

local function Sell(oPlayer: Player, tDino: Dino): number
    local nValue = math.floor(DinoConfig.GetIncome(tDino) * GameConfig.SellSecondsOfIncome)
    PlayerDataServer:AddCash(oPlayer, nValue)
    AnalyticsServer:Economy(oPlayer, Enum.AnalyticsEconomyFlowType.Source, "Cash", nValue, PlayerDataServer:Get(oPlayer, "Cash") or 0, Enum.AnalyticsEconomyTransactionType.Gameplay.Name, "SellCatch")
    return nValue
end

-- Creates a dino record with a fresh id (does not place it).
function mEnclosure.NewDino(self, oPlayer: Player, sSpecies: string, sSize: string, sMutation: string): Dino
    local iId = PlayerDataServer:Get(oPlayer, "NextDinoId") or 1
    PlayerDataServer:Set(oPlayer, "NextDinoId", iId + 1)
    return { Id = iId, Species = sSpecies, Size = sSize, Mutation = sMutation, CaughtAt = os.time() }
end

--[[
    Places a caught dino. Returns a result table for the client reveal:
        { Status = "Placed" | "Replaced" | "Full", ReplacedSpecies?, SoldFor? }
    "Full" means the player is being asked to choose (EnclosureFull event).
]]
function mEnclosure.AddDino(self, oPlayer: Player, tDino: Dino): { [string]: any }
    local tDinos = PlayerDataServer:Get(oPlayer, "Dinos") or {}
    local iSlots = self:GetSlotCount(oPlayer)
    if #tDinos < iSlots then
        PlayerDataServer:Update(oPlayer, "Dinos", function(t)
            table.insert(t, tDino)
            return t
        end)
        PlotServer:Refresh(oPlayer)
        return { Status = "Placed" }
    end
    local iWeakest, nWeakest = WeakestIndex(tDinos)
    local tSettings = PlayerDataServer:Get(oPlayer, "Settings") or {}
    if tSettings.AutoReplace and iWeakest then
        if DinoConfig.GetIncome(tDino) > nWeakest then
            local tOld = tDinos[iWeakest]
            PlayerDataServer:Update(oPlayer, "Dinos", function(t)
                t[iWeakest] = tDino
                return t
            end)
            local nSold = Sell(oPlayer, tOld)
            PlotServer:Refresh(oPlayer)
            AnalyticsServer:Custom(oPlayer, "EnclosureFullChoice", 1, AnalyticsServer:Fields("AutoReplace"))
            return { Status = "Replaced", ReplacedSpecies = tOld.Species, SoldFor = nSold }
        end
        local nSold = Sell(oPlayer, tDino)
        AnalyticsServer:Custom(oPlayer, "EnclosureFullChoice", 1, AnalyticsServer:Fields("AutoSell"))
        return { Status = "Sold", SoldFor = nSold }
    end
    -- Ask the player. A previous unanswered choice is resolved as a sale first.
    if tPendingFull[oPlayer] then
        Sell(oPlayer, tPendingFull[oPlayer].tDino)
    end
    tPendingFull[oPlayer] = { tDino = tDino, nExpires = os.clock() + FULL_CHOICE_TIMEOUT }
    local tWeak = iWeakest and tDinos[iWeakest]
    oEnclosureFull:FireClient(oPlayer, {
        New = tDino,
        Weakest = tWeak,
        SellValue = math.floor(DinoConfig.GetIncome(tDino) * GameConfig.SellSecondsOfIncome),
        WeakestSellValue = tWeak and math.floor(DinoConfig.GetIncome(tWeak) * GameConfig.SellSecondsOfIncome) or 0,
    })
    return { Status = "Full" }
end

local function ResolveFull(oPlayer: Player, sChoice: string)
    local tPending = tPendingFull[oPlayer]
    if not tPending then return end
    tPendingFull[oPlayer] = nil
    if sChoice == "Replace" then
        local tDinos = PlayerDataServer:Get(oPlayer, "Dinos") or {}
        local iWeakest = WeakestIndex(tDinos)
        if iWeakest then
            local tOld = tDinos[iWeakest]
            PlayerDataServer:Update(oPlayer, "Dinos", function(t)
                t[iWeakest] = tPending.tDino
                return t
            end)
            Sell(oPlayer, tOld)
            PlotServer:Refresh(oPlayer)
        else
            Sell(oPlayer, tPending.tDino)
        end
    else
        Sell(oPlayer, tPending.tDino)
    end
    AnalyticsServer:Custom(oPlayer, "EnclosureFullChoice", 1, AnalyticsServer:Fields(sChoice == "Replace" and "Replace" or "Sell"))
end

function mEnclosure.PreloadAsync(self)
    oEnclosureFull = Remote:GetEvent("EnclosureFull")
    oResolveFull = Remote:GetEvent("ResolveFull")
    oCollectOffline = Remote:GetEvent("CollectOffline")
    oReroll = Remote:GetFunction("RerollMutation")
    oSetSetting = Remote:GetEvent("SetSetting")

    oResolveFull:OnServerEvent(function(oPlayer: Player, sChoice)
        if typeof(sChoice) ~= "string" then return end
        ResolveFull(oPlayer, sChoice)
    end)

    oCollectOffline:OnServerEvent(function(oPlayer: Player)
        if not PlayerDataServer:IsReady(oPlayer) then return end
        local nPending = PlayerDataServer:Get(oPlayer, "PendingOffline") or 0
        if nPending <= 0 then return end
        PlayerDataServer:Set(oPlayer, "PendingOffline", 0)
        PlayerDataServer:AddCash(oPlayer, nPending)
        AnalyticsServer:Economy(oPlayer, Enum.AnalyticsEconomyFlowType.Source, "Cash", nPending, PlayerDataServer:Get(oPlayer, "Cash") or 0, Enum.AnalyticsEconomyTransactionType.Gameplay.Name, "OfflineIncome")
        AnalyticsServer:Custom(oPlayer, "WelcomeBackCollected", nPending)
    end)

    oSetSetting:OnServerEvent(function(oPlayer: Player, tPayload)
        if typeof(tPayload) ~= "table" or typeof(tPayload.Value) ~= "boolean" then return end
        local sKey = tPayload.Key
        if sKey ~= "AutoReplace" and sKey ~= "AutoLaunch" and sKey ~= "MusicOff" then return end
        if sKey == "AutoLaunch" and not HasPass(oPlayer, "AutoLaunch") then return end
        PlayerDataServer:Update(oPlayer, "Settings", function(t)
            t = t or {}
            t[sKey] = tPayload.Value
            return t
        end)
    end)

    -- Reroll one dino's mutation using a potion. Returns { Ok, Mutation?, Reason? }.
    oReroll:OnServerInvoke(function(oPlayer: Player, iDinoId)
        if typeof(iDinoId) ~= "number" or tRerollBusy[oPlayer] then
            return { Ok = false, Reason = "Busy" }
        end
        if (PlayerDataServer:Get(oPlayer, "Rerolls") or 0) <= 0 then
            return { Ok = false, Reason = "NoPotions" }
        end
        tRerollBusy[oPlayer] = true
        local tResult = { Ok = false, Reason = "NotFound" }
        local tDinos = PlayerDataServer:Get(oPlayer, "Dinos") or {}
        for i, tDino in tDinos do
            if tDino.Id == iDinoId then
                local sOld = tDino.Mutation
                local sNew = CatchRoller.RollMutation(1, WeatherServer:GetMutationMultipliers())
                -- A paid reroll never makes a dino worse: keep the old mutation if the roll is lower (DECISIONS #26).
                local tOldMut, tNewMut = DinoConfig.GetMutation(sOld), DinoConfig.GetMutation(sNew)
                local bKept = tOldMut and tNewMut and tNewMut.Cash < tOldMut.Cash
                if bKept then
                    sNew = sOld
                end
                PlayerDataServer:Set(oPlayer, "Rerolls", (PlayerDataServer:Get(oPlayer, "Rerolls") or 1) - 1)
                PlayerDataServer:Update(oPlayer, "Dinos", function(t)
                    t[i].Mutation = sNew
                    return t
                end)
                self:MarkIndex(oPlayer, tDino.Species, sNew)
                PlotServer:Refresh(oPlayer)
                AnalyticsServer:Custom(oPlayer, "Reroll", 1, AnalyticsServer:Fields(sOld, sNew))
                tResult = { Ok = true, Mutation = sNew, Kept = bKept == true }
                break
            end
        end
        tRerollBusy[oPlayer] = nil
        return tResult
    end)
end

-- Records a species+mutation in the Index. Returns true if it was new.
function mEnclosure.MarkIndex(self, oPlayer: Player, sSpecies: string, sMutation: string): boolean
    local sKey = `{sSpecies}:{sMutation}`
    local tIndex = PlayerDataServer:Get(oPlayer, "Index") or {}
    if tIndex[sKey] then
        return false
    end
    PlayerDataServer:Update(oPlayer, "Index", function(t)
        t[sKey] = true
        return t
    end)
    return true
end

-- Grants an exclusive dino from the rotation (MonetizationServer). Each one is owned once.
function mEnclosure.GrantExclusive(self, oPlayer: Player, sId: string): boolean
    local tEx = ExclusiveRotation.Get(sId)
    local tOwned = PlayerDataServer:Get(oPlayer, "ExclusiveDinos") or {}
    if not tEx or tOwned[sId] then
        return false
    end
    PlayerDataServer:Update(oPlayer, "ExclusiveDinos", function(t)
        t = t or {}
        t[sId] = true
        return t
    end)
    self:MarkIndex(oPlayer, tEx.Species, tEx.Mutation)
    PlotServer:Refresh(oPlayer)
    return true
end

function mEnclosure.StartAsync(self)
    PlayerDataServer:OnReady(function(oPlayer: Player)
        -- Offline earnings since the last save.
        local nLast = PlayerDataServer:Get(oPlayer, "LastOnline") or 0
        local nNow = os.time()
        if nLast > 0 and nNow > nLast then
            local nCap = if HasPass(oPlayer, "VIP") then GameConfig.OfflineCapSecondsVIP else GameConfig.OfflineCapSeconds
            local nElapsed = math.min(nNow - nLast, nCap)
            if nElapsed >= GameConfig.OfflineMinSecondsToShow then
                local nEarned = math.floor(self:GetIncome(oPlayer) * GameConfig.OfflineRate * nElapsed)
                if nEarned > 0 then
                    PlayerDataServer:Set(oPlayer, "PendingOffline", (PlayerDataServer:Get(oPlayer, "PendingOffline") or 0) + nEarned)
                end
            end
        end
        PlayerDataServer:Set(oPlayer, "LastOnline", nNow)
    end)

    local nSinceSave = 0
    while true do
        task.wait(GameConfig.IncomeTickSeconds)
        nSinceSave += GameConfig.IncomeTickSeconds
        for _, oPlayer in Players:GetPlayers() do
            if PlayerDataServer:IsReady(oPlayer) then
                local nIncome = self:GetIncome(oPlayer) * GameConfig.IncomeTickSeconds
                if nIncome > 0 then
                    PlayerDataServer:AddCash(oPlayer, nIncome)
                    AnalyticsServer:AddIncome(oPlayer, nIncome)
                end
                oPlayer:SetAttribute("Income", self:GetIncome(oPlayer))
                -- Keep LastOnline fresh so a server crash doesn't lose offline time.
                if nSinceSave >= 60 then
                    PlayerDataServer:Set(oPlayer, "LastOnline", os.time())
                end
                local tPending = tPendingFull[oPlayer]
                if tPending and os.clock() > tPending.nExpires then
                    ResolveFull(oPlayer, "Sell")
                end
            end
        end
        if nSinceSave >= 60 then
            nSinceSave = 0
        end
    end
end

function mEnclosure.PlayerRemoving(self, oPlayer: Player)
    if tPendingFull[oPlayer] then
        ResolveFull(oPlayer, "Sell")
    end
    tRerollBusy[oPlayer] = nil
end

-- Rebirth: clears the park except the single best-earning dino. Returns that dino (or nil).
function mEnclosure.ResetForRebirth(self, oPlayer: Player): Dino?
    local tBest, nBest = nil, -1
    for _, t in PlayerDataServer:Get(oPlayer, "Dinos") or {} do
        local n = DinoConfig.GetIncome(t)
        if n > nBest then tBest, nBest = t, n end
    end
    PlayerDataServer:Set(oPlayer, "Dinos", if tBest then { tBest } else {})
    PlotServer:Refresh(oPlayer)
    return tBest
end

return mEnclosure
