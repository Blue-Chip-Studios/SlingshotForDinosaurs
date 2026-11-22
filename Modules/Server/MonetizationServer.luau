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
-- tGiftTarget[buyer] is set when the gift prompt opens; the receipt reads it.
local tGiftTarget: { [Player]: { UserId: number, Pass: string, Expires: number } } = {}
local oGiftStore = ProfileStore.New(ProfileConfig.StoreName, ProfileConfig.ProfileTemplate)
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
local function DeliverGift(oBuyer: Player, sPass: string): boolean
    local tTarget = tGiftTarget[oBuyer]
    tGiftTarget[oBuyer] = nil
    if not tTarget or tTarget.Pass ~= sPass or os.clock() > tTarget.Expires then
        -- No valid recipient recorded (e.g. server restarted mid-purchase): the buyer gets it.
        ApplyGift(oBuyer, sPass, oBuyer.DisplayName)
        return true
    end
    local oTarget = Players:GetPlayerByUserId(tTarget.UserId)
    if oTarget and PlayerDataServer:IsReady(oTarget) then
        ApplyGift(oTarget, sPass, oBuyer.DisplayName)
        return true
    end
    local bOk = pcall(oGiftStore.MessageAsync, oGiftStore, ProfileConfig.Prefix .. tTarget.UserId, { Type = "Gift", Pass = sPass, From = oBuyer.DisplayName })
    if bOk then
        -- Recipient left: tell them (opted-in 13+ users only; no-op until configured).
        task.spawn(NotificationServer.Send, NotificationServer, tTarget.UserId, "GiftReceived", { giver = oBuyer.DisplayName, pass = MonetizationConfig.Passes[sPass].Name })
    end
    return bOk -- false: receipt retried later rather than losing the gift
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
    local tOwned = {}
    -- Gifted passes count as owned.
    for sKey, b in PlayerDataServer:Get(oPlayer, "GiftedPasses") or {} do
        if b then tOwned[sKey] = true end
    end
    for sKey, tPass in MonetizationConfig.Passes do
        if tPass.Id ~= 0 then
            local bOk, bOwns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, oPlayer.UserId, tPass.Id)
            if bOk and bOwns then tOwned[sKey] = true end
        end
    end
    -- Keep passes simulated in Studio (Id = 0) for testing.
    local tCurrent = PlayerDataServer:Get(oPlayer, "Passes") or {}
    if RunService:IsStudio() then
        for sKey, tPass in MonetizationConfig.Passes do
            if tPass.Id == 0 and tCurrent[sKey] then tOwned[sKey] = true end
        end
    end
    PlayerDataServer:Set(oPlayer, "Passes", tOwned)
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
    local bOk, bGranted = pcall(GrantProduct, oPlayer, sKey)
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
                if not oTarget or oTarget == oPlayer or not PlayerDataServer:IsReady(oTarget) or OwnsPass(oTarget, tProduct.Pass) then return end
                tGiftTarget[oPlayer] = { UserId = oTarget.UserId, Pass = tProduct.Pass, Expires = os.clock() + 300 }
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
        tGiftTarget[oPlayer] = nil
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
