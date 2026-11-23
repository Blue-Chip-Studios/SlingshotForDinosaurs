--[[
    PetServer
    ---------
    Baby-dino pets (PetConfig). Cash pets are bought here; Robux pets are granted by
    MonetizationServer after a receipt (Grant). One pet is equipped at a time; its perk is
    read by EnclosureServer (Cash) and RetentionServer (Luck, Power). The equipped pet id is
    mirrored to the player's "Pet" attribute so every client can draw everyone's pet.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Module = require(ReplicatedStorage.Shared.Module)
local Remote = require(ReplicatedStorage.BCDKShared.Remote)
local PetConfig = require(ReplicatedStorage.Config.PetConfig)

local PlayerDataServer = require(ServerStorage.ServerModules.PlayerDataServer)
local AnalyticsServer = require(ServerStorage.ServerModules.AnalyticsServer)

local tBusy: { [Player]: boolean } = {}

local mPet = Module()

local function Mirror(oPlayer: Player)
    oPlayer:SetAttribute("Pet", PlayerDataServer:Get(oPlayer, "EquippedPet") or "")
end

function mPet.Owns(self, oPlayer: Player, sId: string): boolean
    return (PlayerDataServer:Get(oPlayer, "Pets") or {})[sId] == true
end

function mPet.Equip(self, oPlayer: Player, sId: string)
    PlayerDataServer:Set(oPlayer, "EquippedPet", sId)
    Mirror(oPlayer)
end

-- Adds a pet to the player's collection and equips it (shared by cash and Robux paths).
function mPet.Grant(self, oPlayer: Player, sId: string, sSource: string): boolean
    local tPet = PetConfig.Get(sId)
    if not tPet or self:Owns(oPlayer, sId) then return false end
    local tOwned = table.clone(PlayerDataServer:Get(oPlayer, "Pets") or {})
    tOwned[sId] = true
    PlayerDataServer:Set(oPlayer, "Pets", tOwned)
    self:Equip(oPlayer, sId)
    AnalyticsServer:Custom(oPlayer, "PetBought", 1, AnalyticsServer:Fields(sId, sSource))
    return true
end

function mPet.PreloadAsync(self)
    -- BuyPet({ Id }) -> { Ok, Reason? }   (cash pets only; Robux pets go through MonetizationServer)
    Remote:GetFunction("BuyPet"):OnServerInvoke(function(oPlayer: Player, tPayload)
        if typeof(tPayload) ~= "table" or typeof(tPayload.Id) ~= "string" then return { Ok = false, Reason = "Bad" } end
        if not PlayerDataServer:IsReady(oPlayer) or tBusy[oPlayer] then return { Ok = false, Reason = "Busy" } end
        local tPet = PetConfig.Get(tPayload.Id)
        local nPrice = tPet and tPet.Price.Cash
        if not tPet or not nPrice then return { Ok = false, Reason = "Bad" } end
        if self:Owns(oPlayer, tPet.Id) then return { Ok = false, Reason = "Owned" } end
        tBusy[oPlayer] = true
        local tResult
        if PlayerDataServer:SpendCash(oPlayer, nPrice) then
            self:Grant(oPlayer, tPet.Id, "Cash")
            AnalyticsServer:Economy(oPlayer, Enum.AnalyticsEconomyFlowType.Sink, "Cash", nPrice, PlayerDataServer:Get(oPlayer, "Cash") or 0, Enum.AnalyticsEconomyTransactionType.Shop.Name, `Pet_{tPet.Id}`)
            tResult = { Ok = true }
        else
            tResult = { Ok = false, Reason = "Cash" }
        end
        tBusy[oPlayer] = nil
        return tResult
    end)

    -- EquipPet({ Id }): Id = "" unequips.
    Remote:GetEvent("EquipPet"):OnServerEvent(function(oPlayer: Player, tPayload)
        if typeof(tPayload) ~= "table" or typeof(tPayload.Id) ~= "string" then return end
        if not PlayerDataServer:IsReady(oPlayer) then return end
        if tPayload.Id ~= "" and not self:Owns(oPlayer, tPayload.Id) then return end
        self:Equip(oPlayer, tPayload.Id)
    end)
end

function mPet.StartAsync(self)
    PlayerDataServer:OnReady(Mirror)
end

function mPet.PlayerRemoving(self, oPlayer: Player)
    tBusy[oPlayer] = nil
end

return mPet
