--[[
    ShopServer
    ----------
    Cash purchases for the three upgrade tracks (slingshots, bait, enclosure
    slots). Owning a tier means owning every tier below it, so the profile
    only stores the current tier id. Robux skips are handled by
    MonetizationServer, which calls Grant* here after a receipt.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Module = require(ReplicatedStorage.Shared.Module)
local Remote = require(ReplicatedStorage.BCDKShared.Remote)
local ShopConfig = require(ReplicatedStorage.Config.ShopConfig)

local PlayerDataServer = require(ServerStorage.ServerModules.PlayerDataServer)
local AnalyticsServer = require(ServerStorage.ServerModules.AnalyticsServer)
local FTUEServer = require(ServerStorage.ServerModules.FTUEServer)
local PlotServer = require(ServerStorage.ServerModules.PlotServer)

local tBusy: { [Player]: boolean } = {}

local function TierOf(tList, sId): number
    for i, t in tList do
        if t.Id == sId then
            return i
        end
    end
    return 1
end

local tTracks = {
    Slingshot = { List = ShopConfig.Slingshots, Key = "Slingshot" },
    Bait = { List = ShopConfig.Bait, Key = "Bait" },
}

local mShop = Module()

-- Current tier index for a track ("Slingshot" | "Bait" | "Slots").
function mShop.GetTier(self, oPlayer: Player, sKind: string): number
    if sKind == "Slots" then
        return PlayerDataServer:Get(oPlayer, "SlotTier") or 1
    end
    local tTrack = tTracks[sKind]
    return TierOf(tTrack.List, PlayerDataServer:Get(oPlayer, tTrack.Key))
end

-- Sets a track to tier i if it's an upgrade. Shared by cash and Robux paths.
function mShop.GrantTier(self, oPlayer: Player, sKind: string, iTier: number, sSource: string): boolean
    local iCurrent = self:GetTier(oPlayer, sKind)
    if iTier <= iCurrent then
        return false
    end
    if sKind == "Slots" then
        PlayerDataServer:Set(oPlayer, "SlotTier", iTier)
        PlotServer:Refresh(oPlayer)
    else
        local tTrack = tTracks[sKind]
        PlayerDataServer:Set(oPlayer, tTrack.Key, tTrack.List[iTier].Id)
    end
    AnalyticsServer:Progression(oPlayer, sKind, Enum.AnalyticsProgressionType.Complete, iTier, sSource)
    FTUEServer:Reach(oPlayer, "FirstUpgrade")
    return true
end

local function Price(sKind: string, iTier: number): number?
    if sKind == "Slots" then
        local t = ShopConfig.Slots[iTier]
        return t and t.Price
    end
    local tTrack = tTracks[sKind]
    local t = tTrack and tTrack.List[iTier]
    return t and t.Price
end

function mShop.PreloadAsync(self)
    -- BuyWithCash({ Kind, Tier }) -> { Ok, Reason? }
    Remote:GetFunction("BuyWithCash"):OnServerInvoke(function(oPlayer: Player, tPayload)
        if typeof(tPayload) ~= "table" or typeof(tPayload.Kind) ~= "string" or typeof(tPayload.Tier) ~= "number" then
            return { Ok = false, Reason = "Bad" }
        end
        if not PlayerDataServer:IsReady(oPlayer) or tBusy[oPlayer] then
            return { Ok = false, Reason = "Busy" }
        end
        local sKind, iTier = tPayload.Kind, math.floor(tPayload.Tier)
        if sKind ~= "Slots" and not tTracks[sKind] then
            return { Ok = false, Reason = "Bad" }
        end
        local iCurrent = self:GetTier(oPlayer, sKind)
        if iTier <= iCurrent then
            return { Ok = false, Reason = "Owned" }
        end
        if sKind == "Slots" and iTier ~= iCurrent + 1 then
            return { Ok = false, Reason = "NotNext" } -- slots expand one step at a time
        end
        local nPrice = Price(sKind, iTier)
        if not nPrice then
            return { Ok = false, Reason = "Bad" }
        end
        tBusy[oPlayer] = true
        local bSpent = PlayerDataServer:SpendCash(oPlayer, nPrice)
        local tResult
        if bSpent then
            self:GrantTier(oPlayer, sKind, iTier, "Cash")
            AnalyticsServer:Economy(oPlayer, Enum.AnalyticsEconomyFlowType.Sink, "Cash", nPrice, PlayerDataServer:Get(oPlayer, "Cash") or 0, Enum.AnalyticsEconomyTransactionType.Shop.Name, `{sKind}_{iTier}`)
            tResult = { Ok = true }
        else
            tResult = { Ok = false, Reason = "Cash" }
        end
        tBusy[oPlayer] = nil
        return tResult
    end)
end

function mShop.PlayerRemoving(self, oPlayer: Player)
    tBusy[oPlayer] = nil
end

return mShop
