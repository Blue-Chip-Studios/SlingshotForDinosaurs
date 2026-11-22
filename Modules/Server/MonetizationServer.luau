--[[
    MonetizationServer
    ------------------
    Owns every Robux interaction: gamepass ownership, purchase prompts and
    MarketplaceService.ProcessReceipt.

    Receipts are granted idempotently: each PurchaseId is recorded in the
    player's profile with the grant, and a repeat receipt is acknowledged
    without granting again. Note: ProfileStore saves periodically and on
    leave; recording the id in the same profile write as the grant means a
    crash loses both or neither.

    Products/passes with Id = 0 aren't created on Roblox yet. In Studio a
    prompt for one is simulated (granted directly) so the grant path can be
    tested; in live servers the client hides their Robux buttons.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Module = require(ReplicatedStorage.Shared.Module)
local Remote = require(ReplicatedStorage.BCDKShared.Remote)
local MonetizationConfig = require(ReplicatedStorage.Config.MonetizationConfig)
local ShopConfig = require(ReplicatedStorage.Config.ShopConfig)
local WeatherConfig = require(ReplicatedStorage.Config.WeatherConfig)

local PlayerDataServer = require(ServerStorage.ServerModules.PlayerDataServer)
local AnalyticsServer = require(ServerStorage.ServerModules.AnalyticsServer)
local EnclosureServer = require(ServerStorage.ServerModules.EnclosureServer)
local ShopServer = require(ServerStorage.ServerModules.ShopServer)
local WeatherServer = require(ServerStorage.ServerModules.WeatherServer)
local PlotServer = require(ServerStorage.ServerModules.PlotServer)
local RetentionServer = require(ServerStorage.ServerModules.RetentionServer)
local NotificationServer = require(ServerStorage.ServerModules.NotificationServer)
local ProfileStore = require(ReplicatedStorage.External.ProfileStore)
local ProfileConfig = require(ReplicatedStorage.Config.ProfileConfig)
local ExclusiveRotation = require(ReplicatedStorage.Shared.ExclusiveRotation)

local tProductById: { [number]: string } = {}
local tPassById: { [number]: string } = {}
for sKey, t in MonetizationConfig.Products do
    if t.Id ~= 0 then tProductById[t.Id] = sKey end
end
for sKey, t in MonetizationConfig.Passes do
    if t.Id ~= 0 then tPassById[t.Id] = sKey end
end

local oPurchaseResult, oAnnounce

local function TierIndex(tList, sId: string): number?
    for i, t in tList do
        if t.Id == sId then return i end
    end
    return nil
end

-- ===== Gifting =====
-- A gift pass is stored in the recipient's GiftedPasses (merged into Passes).
-- The recipient is saved in the BUYER's profile (PendingGifts[pass]) when the
-- prompt opens, so a receipt retried after a leave/crash still finds them. It is
-- cleared only once delivery succeeded.
local PENDING_GIFT_MAX_AGE = 7 * 24 * 3600
local oGiftStore = ProfileStore.New(ProfileConfig.StoreName, ProfileConfig.ProfileTemplate)
local tProcessing: { [string]: boolean } = {} -- PurchaseIds being granted right now
local tBoughtThisSession: { [Player]: { [string]: boolean } } = {}
local tLastPrompt: { [Player]: number } = {}
local RefreshPasses -- forward declaration

local function OwnsPass(oPlayer: Player, sPass: string): boolean
    local t = PlayerDataServer:Get(oPlayer, "Passes")
    return typeof(t) == "table" and t[sPass] == true
end

-- Gives sPass to a loaded player (recipient side of a gift).
local function ApplyGift(oTarget: Player, sPass: string, sFrom: string)
    local tPass = MonetizationConfig.Passes[sPass]
    if not tPass then return end
    if OwnsPass(oTarget, sPass) then
        -- Bought before the recipient got it some other way: never waste the gift.
        PlayerDataServer:Set(oTarget, "Rerolls", (PlayerDataServer:Get(oTarget, "Rerolls") or 0) + 3)
    else
        PlayerDataServer:Update(oTarget, "GiftedPasses", function(t)
            t = t or {}
            t[sPass] = true
            return t
        end)
        RefreshPasses(oTarget)
    end
    oAnnounce:FireAllClients({ Text = `{sFrom} gifted {oTarget.DisplayName} the {tPass.Name} pass!`, Kind = "Event" })
end

-- Buyer side: deliver now if the recipient is here, otherwise by ProfileStore message.
local function ClearPendingGift(oBuyer: Player, sPass: string)
    PlayerDataServer:Update(oBuyer, "PendingGifts", function(t)
        t = t or {}
        t[sPass] = nil
        return t
    end)
end

local function DeliverGift(oBuyer: Player, sPass: string): boolean
    local tTarget = (PlayerDataServer:Get(oBuyer, "PendingGifts") or {})[sPass]
    local bValid = typeof(tTarget) == "table" and typeof(tTarget.UserId) == "number"
        and os.time() - (tTarget.At or 0) < PENDING_GIFT_MAX_AGE
    if not bValid then
        -- No recipient recorded at all: the buyer gets it rather than losing the purchase.
        ApplyGift(oBuyer, sPass, oBuyer.DisplayName)
        ClearPendingGift(oBuyer, sPass)
        return true
    end
    local oTarget = Players:GetPlayerByUserId(tTarget.UserId)
    if oTarget and PlayerDataServer:IsReady(oTarget) then
        ApplyGift(oTarget, sPass, oBuyer.DisplayName)
        ClearPendingGift(oBuyer, sPass)
        return true
    end
    -- Recipient offline: queue it on their profile. MessageAsync returns false (not an error)
    -- while the server is closing, so check both.
    local bOk, bSent = pcall(oGiftStore.MessageAsync, oGiftStore, ProfileConfig.Prefix .. tTarget.UserId, { Type = "Gift", Pass = sPass, From = oBuyer.DisplayName })
    if not (bOk and bSent ~= false) then
        return false -- receipt retried later; the pending recipient is kept
    end
    ClearPendingGift(oBuyer, sPass)
    -- Tell them (opted-in 13+ users only; no-op until configured).
    task.spawn(NotificationServer.Send, NotificationServer, tTarget.UserId, "GiftReceived", { giver = oBuyer.DisplayName, pass = MonetizationConfig.Passes[sPass].Name })
    return true
end

-- Applies a product's effect. Returns true if granted (false = cannot grant now).
local function GrantProduct(oPlayer: Player, sKey: string): boolean
    local tProduct = MonetizationConfig.Products[sKey]
    if not tProduct then return false end
    local sKind = tProduct.Kind
    if sKind == "MeteorStorm" then
        WeatherServer:TriggerEvent("MeteorStorm", WeatherConfig.PurchasedStormSeconds, oPlayer.DisplayName)
    elseif sKind == "Reroll" then
        PlayerDataServer:Set(oPlayer, "Rerolls", (PlayerDataServer:Get(oPlayer, "Rerolls") or 0) + tProduct.Amount)
    elseif sKind == "Gift" then
        AnalyticsServer:Custom(oPlayer, "GiftSent", 1, AnalyticsServer:Fields(tProduct.Pass))
        return DeliverGift(oPlayer, tProduct.Pass)
    elseif sKind == "ExclusiveDino" then
        if not EnclosureServer:GrantExclusive(oPlayer, (ExclusiveRotation.Current()).Id) then
            -- Already owned (shouldn't be promptable): compensate with rerolls rather than lose the purchase.
            PlayerDataServer:Set(oPlayer, "Rerolls", (PlayerDataServer:Get(oPlayer, "Rerolls") or 0) + 5)
        end
    elseif sKind == "Luck" then
        RetentionServer:AddLuckBoost(oPlayer, tProduct.Multiplier, tProduct.Minutes)
    elseif sKind == "Cash" then
        local nAmount = math.max(500, math.floor(EnclosureServer:GetIncome(oPlayer) * 60 * tProduct.Minutes))
        PlayerDataServer:AddCash(oPlayer, nAmount)
        AnalyticsServer:Economy(oPlayer, Enum.AnalyticsEconomyFlowType.Source, "Cash", nAmount, PlayerDataServer:Get(oPlayer, "Cash") or 0, Enum.AnalyticsEconomyTransactionType.IAP.Name, sKey)
    elseif sKind == "StarterPack" then
        PlayerDataServer:Set(oPlayer, "StarterPackBought", true)
        ShopServer:GrantTier(oPlayer, "Slingshot", TierIndex(ShopConfig.Slingshots, "Bone") :: number, "StarterPack")
        ShopServer:GrantTier(oPlayer, "Bait", TierIndex(ShopConfig.Bait, "Steak") :: number, "StarterPack")
        PlayerDataServer:Set(oPlayer, "Rerolls", (PlayerDataServer:Get(oPlayer, "Rerolls") or 0) + 1)
    elseif sKind == "Slingshot" or sKind == "Bait" then
        local tList = if sKind == "Slingshot" then ShopConfig.Slingshots else ShopConfig.Bait
        local iTier = TierIndex(tList, tProduct.Item)
        if not iTier then return false end
        if not ShopServer:GrantTier(oPlayer, sKind, iTier, "Robux") then
            -- Already at or above this tier: give the equivalent cash so the purchase isn't wasted.
            PlayerDataServer:AddCash(oPlayer, tList[iTier].Price)
        end
    else
        return false
    end
    return true
end

function RefreshPasses(oPlayer: Player)
    -- Look ownership up first (yields), then merge in one write using data read AFTER the
    -- yields, so a gift or purchase that lands meanwhile is never overwritten.
    local tLookup: { [string]: boolean? } = {} -- true/false = answered, nil = lookup failed
    for sKey, tPass in MonetizationConfig.Passes do
        if tPass.Id ~= 0 then
            local bOk, bOwns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, oPlayer.UserId, tPass.Id)
            if bOk then tLookup[sKey] = bOwns == true end
        end
    end
    if not PlayerDataServer:IsReady(oPlayer) then return end
    local tGifted = PlayerDataServer:Get(oPlayer, "GiftedPasses") or {}
    local tBought = tBoughtThisSession[oPlayer] or {}
    PlayerDataServer:Update(oPlayer, "Passes", function(tCurrent)
        tCurrent = tCurrent or {}
        local tOwned = {}
        for sKey, tPass in MonetizationConfig.Passes do
            local bAnswer = tLookup[sKey]
            if tGifted[sKey] or tBought[sKey] or bAnswer == true then
                tOwned[sKey] = true
            elseif bAnswer == nil and tCurrent[sKey] then
                -- Lookup failed (web hiccup) or Studio-simulated pass: keep what they had.
                tOwned[sKey] = true
            end
        end
        return tOwned
    end)
    PlotServer:Refresh(oPlayer)
end

local function GrantPass(oPlayer: Player, sKey: string)
    PlayerDataServer:Update(oPlayer, "Passes", function(t)
        t = t or {}
        t[sKey] = true
        return t
    end)
    PlotServer:Refresh(oPlayer)
end

local function ProcessReceipt(tReceipt)
    local oPlayer = Players:GetPlayerByUserId(tReceipt.PlayerId)
    if not oPlayer or not PlayerDataServer:IsReady(oPlayer) then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    local sPurchaseId = tostring(tReceipt.PurchaseId)
    local tIds = PlayerDataServer:Get(oPlayer, "PurchaseIds") or {}
    if tIds[sPurchaseId] then
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end
    local sKey = tProductById[tReceipt.ProductId]
    if not sKey then
        warn("[Monetization] unknown product", tReceipt.ProductId)
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    -- Grants can yield (gift delivery); never run the same receipt twice concurrently.
    if tProcessing[sPurchaseId] then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    tProcessing[sPurchaseId] = true
    local bOk, bGranted = pcall(GrantProduct, oPlayer, sKey)
    tProcessing[sPurchaseId] = nil
    if not (bOk and bGranted) then
        warn("[Monetization] grant failed", sKey, bGranted)
        AnalyticsServer:Funnel(oPlayer, "Purchase", sKey, 3, "Failed")
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    PlayerDataServer:Update(oPlayer, "PurchaseIds", function(t)
        t = t or {}
        t[sPurchaseId] = os.time()
        return t
    end)
    AnalyticsServer:Funnel(oPlayer, "Purchase", sKey, 3, "Succeeded")
    oPurchaseResult:FireClient(oPlayer, { Key = sKey, Ok = true })
    return Enum.ProductPurchaseDecision.PurchaseGranted
end

local mMonetization = Module()

function mMonetization.PreloadAsync(self)
    oPurchaseResult = Remote:GetEvent("PurchaseResult")
    oAnnounce = Remote:GetEvent("Announcement")
    MarketplaceService.ProcessReceipt = ProcessReceipt

    -- Prompt({ Kind = "Product" | "Pass", Key }) from the client.
    Remote:GetEvent("PromptPurchase"):OnServerEvent(function(oPlayer: Player, tPayload)
        if typeof(tPayload) ~= "table" or typeof(tPayload.Key) ~= "string" then return end
        -- One prompt per second: stops prompt spam and fake "Prompted" funnel events.
        if os.clock() - (tLastPrompt[oPlayer] or -math.huge) < 1 then return end
        tLastPrompt[oPlayer] = os.clock()
        local sKey = tPayload.Key
        if tPayload.Kind == "Pass" then
            local tPass = MonetizationConfig.Passes[sKey]
            if not tPass then return end
            AnalyticsServer:Funnel(oPlayer, "Purchase", sKey, 2, "Prompted")
            if tPass.Id == 0 then
                if RunService:IsStudio() then
                    GrantPass(oPlayer, sKey)
                    oPurchaseResult:FireClient(oPlayer, { Key = sKey, Ok = true, Simulated = true })
                end
                return
            end
            MarketplaceService:PromptGamePassPurchase(oPlayer, tPass.Id)
        else
            local tProduct = MonetizationConfig.Products[sKey]
            if not tProduct then return end
            if tProduct.Kind == "ExclusiveDino" and (PlayerDataServer:Get(oPlayer, "ExclusiveDinos") or {})[(ExclusiveRotation.Current()).Id] then return end
            if tProduct.Kind == "Gift" then
                -- Validate the recipient: in this server, not the buyer, and not already owning the pass.
                local oTarget = typeof(tPayload.Target) == "number" and Players:GetPlayerByUserId(tPayload.Target)
                if not oTarget or oTarget == oPlayer or not PlayerDataServer:IsReady(oTarget) or OwnsPass(oTarget, tProduct.Pass) then
                    oPurchaseResult:FireClient(oPlayer, { Key = sKey, Ok = false, Reason = "They already have this pass!" })
                    return
                end
                PlayerDataServer:Update(oPlayer, "PendingGifts", function(t)
                    t = t or {}
                    t[tProduct.Pass] = { UserId = oTarget.UserId, At = os.time() }
                    return t
                end)
            end
            if tProduct.OneTime and PlayerDataServer:Get(oPlayer, "StarterPackBought") then return end
            if tProduct.Kind == "Slingshot" or tProduct.Kind == "Bait" then
                -- Robux skips only for the next RobuxSkipAhead tiers (GDD 10).
                local tList = if tProduct.Kind == "Slingshot" then ShopConfig.Slingshots else ShopConfig.Bait
                local iTier = TierIndex(tList, tProduct.Item) or 0
                local iCurrent = ShopServer:GetTier(oPlayer, tProduct.Kind)
                if iTier <= iCurrent or iTier > iCurrent + ShopConfig.RobuxSkipAhead then return end
            end
            AnalyticsServer:Funnel(oPlayer, "Purchase", sKey, 2, "Prompted")
            if tProduct.Id == 0 then
                if RunService:IsStudio() and GrantProduct(oPlayer, sKey) then
                    oPurchaseResult:FireClient(oPlayer, { Key = sKey, Ok = true, Simulated = true })
                end
                return
            end
            MarketplaceService:PromptProductPurchase(oPlayer, tProduct.Id)
        end
    end)

    MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(oPlayer, iPassId, bPurchased)
        local sKey = tPassById[iPassId]
        if not sKey then return end
        if bPurchased then
            -- Remember for this session: UserOwnsGamePassAsync can be cached as false for a while.
            tBoughtThisSession[oPlayer] = tBoughtThisSession[oPlayer] or {}
            tBoughtThisSession[oPlayer][sKey] = true
            GrantPass(oPlayer, sKey)
            AnalyticsServer:Funnel(oPlayer, "Purchase", sKey, 3, "Succeeded")
            oPurchaseResult:FireClient(oPlayer, { Key = sKey, Ok = true })
        else
            AnalyticsServer:Funnel(oPlayer, "Purchase", sKey, 3, "Cancelled")
        end
    end)

    MarketplaceService.PromptProductPurchaseFinished:Connect(function(iUserId, iProductId, bPurchased)
        if bPurchased then return end -- success is reported by ProcessReceipt
        local oPlayer = Players:GetPlayerByUserId(iUserId)
        local sKey = tProductById[iProductId]
        if oPlayer and sKey then
            AnalyticsServer:Funnel(oPlayer, "Purchase", sKey, 3, "Cancelled")
        end
    end)
end

function mMonetization.StartAsync(self)
    PlayerDataServer:OnReady(RefreshPasses)
    PlayerDataServer:OnMessage(function(oPlayer, tMessage)
        if typeof(tMessage) == "table" and tMessage.Type == "Gift" and typeof(tMessage.Pass) == "string" then
            ApplyGift(oPlayer, tMessage.Pass, tostring(tMessage.From or "A friend"))
        end
    end)
    Players.PlayerRemoving:Connect(function(oPlayer)
        tBoughtThisSession[oPlayer] = nil
        tLastPrompt[oPlayer] = nil
    end)
end

function mMonetization.HasPass(self, oPlayer: Player, sKey: string): boolean
    local tPasses = PlayerDataServer:Get(oPlayer, "Passes")
    return typeof(tPasses) == "table" and tPasses[sKey] == true
end

-- Studio QA only (AdminServer gates it): runs the gift grant path without a purchase.
function mMonetization.QAGift(self, oPlayer: Player, sPass: string)
    if RunService:IsStudio() and MonetizationConfig.Passes[sPass] then
        ApplyGift(oPlayer, sPass, "QA")
    end
end

return mMonetization
