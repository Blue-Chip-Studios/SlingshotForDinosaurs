--[[
    PlayerDataServer
    ----------------
    The only module that writes game data to a player's profile. It wraps
    BCDK SMProfile: every Set updates the saved profile and the player's
    "PlayerData" replica together, so the client always mirrors saved state.

    Other modules wait for OnReady(player) instead of using InitProfileAsync
    directly: that guarantees migration has run and the replica exists
    before anyone reads or writes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Module = require(ReplicatedStorage.Shared.Module)
local SMProfile = require(ServerStorage.BCDKServer.SMProfile)
local ProfileConfig = require(ReplicatedStorage.Config.ProfileConfig)

local REPLICA_TOKEN = "PlayerData"

local tReady: { [Player]: boolean } = {}
local tReadyCallbacks: { (Player) -> () } = {}
local tMessageCallbacks: { (Player, any) -> () } = {}

local function DeepClone(v: any): any
    if typeof(v) ~= "table" then
        return v
    end
    local t = {}
    for k, vv in v do
        t[k] = DeepClone(vv)
    end
    return t
end

-- Brings an old profile up to the current schema. Add a branch per version bump.
local function Migrate(tData: { [string]: any })
    local iVersion = tData.SchemaVersion or 0
    if iVersion < 1 then
        -- v1 is the first schema; reconcile already filled defaults.
        tData.SchemaVersion = 1
    end
    -- Validate types defensively so a corrupt value can't break gameplay.
    if typeof(tData.Dinos) ~= "table" then tData.Dinos = {} end
    if typeof(tData.Power) ~= "number" or tData.Power ~= tData.Power then tData.Power = ProfileConfig.ProfileTemplate.Power end
    if typeof(tData.Cash) ~= "number" or tData.Cash ~= tData.Cash then tData.Cash = 0 end
    -- The single ExclusiveDino flag became a rotation set: keep what players already own.
    if typeof(tData.ExclusiveDinos) ~= "table" then tData.ExclusiveDinos = {} end
    if tData.ExclusiveDino == true then
        tData.ExclusiveDinos.CelestialRaptor = true
        tData.ExclusiveDino = false
    end
end

local mPlayerData = Module()

function mPlayerData.InitProfileAsync(self, oPlayer: Player, tProfile)
    Migrate(tProfile.Data)
    local tKeys = {}
    for sKey in ProfileConfig.ProfileTemplate do
        if sKey ~= "PurchaseIds" then -- server-only
            table.insert(tKeys, sKey)
        end
    end
    SMProfile:CreateReplica(oPlayer, REPLICA_TOKEN, tKeys)
    tReady[oPlayer] = true
    for _, fn in tReadyCallbacks do
        task.spawn(fn, oPlayer)
    end
    -- Cross-server profile messages (e.g. gifts bought for this player while offline).
    tProfile:MessageHandler(function(tMessage, fnProcessed)
        for _, fn in tMessageCallbacks do
            local bOk, sErr = pcall(fn, oPlayer, tMessage)
            if not bOk then
                warn("[PlayerData] message handler failed:", sErr)
                return -- leave it unprocessed so it is retried
            end
        end
        fnProcessed()
    end)
end

-- fn(player, message) runs for every ProfileStore message delivered to a loaded profile.
function mPlayerData.OnMessage(self, fn: (Player, any) -> ())
    table.insert(tMessageCallbacks, fn)
end

function mPlayerData.ProfileReleased(self, oPlayer: Player)
    tReady[oPlayer] = nil
end

function mPlayerData.PlayerRemoving(self, oPlayer: Player)
    -- Runs with the profile still writable (SMProfile.ReleaseProfile).
    self:Set(oPlayer, "LastOnline", os.time())
end

-- Calls fn(player) once that player's data is loaded, migrated and replicated
-- (immediately for players who are already ready).
function mPlayerData.OnReady(self, fn: (Player) -> ())
    table.insert(tReadyCallbacks, fn)
    for oPlayer in tReady do
        task.spawn(fn, oPlayer)
    end
end

function mPlayerData.IsReady(self, oPlayer: Player): boolean
    return tReady[oPlayer] == true and oPlayer.Parent == Players
end

function mPlayerData.Get(self, oPlayer: Player, sKey: string): any
    return SMProfile:GetAsync(oPlayer, sKey)
end

-- Replaces a top-level key. Tables are cloned so the replica never aliases profile data.
function mPlayerData.Set(self, oPlayer: Player, sKey: string, vValue: any)
    if not tReady[oPlayer] then
        return
    end
    SMProfile:ModifyAsync(oPlayer, sKey, function()
        return vValue
    end, REPLICA_TOKEN, function(oReplica, vNew)
        if sKey ~= "PurchaseIds" then
            oReplica:Set({ sKey }, DeepClone(vNew))
        end
    end)
end

-- Cash goes through BCDK's "CurrencyReplica" (created by SMCurrency) so LMCurrency
-- mirrors it. Same behaviour as SMCurrency:Add/Remove without its per-call print,
-- which would flood the output once income ticks every second.
local CURRENCY_TOKEN = "CurrencyReplica"

function mPlayerData.AddCash(self, oPlayer: Player, nAmount: number)
    if not tReady[oPlayer] or nAmount ~= nAmount or nAmount <= 0 then
        return
    end
    SMProfile:ModifyAsync(oPlayer, "Cash", function(nCurrent)
        return (nCurrent or 0) + nAmount
    end, CURRENCY_TOKEN, function(oReplica, nNew)
        oReplica:Set({ "Cash" }, nNew)
    end)
end

-- Removes cash only if the player can afford it. Returns whether it was spent.
function mPlayerData.SpendCash(self, oPlayer: Player, nAmount: number): boolean
    if not tReady[oPlayer] or nAmount ~= nAmount or nAmount < 0 then
        return false
    end
    local bSpent = false
    SMProfile:ModifyAsync(oPlayer, "Cash", function(nCurrent)
        nCurrent = nCurrent or 0
        if nCurrent >= nAmount then
            bSpent = true
            return nCurrent - nAmount
        end
        return nCurrent
    end, CURRENCY_TOKEN, function(oReplica, nNew)
        oReplica:Set({ "Cash" }, nNew)
    end)
    return bSpent
end

-- Read-modify-write helper: fn receives a deep copy and returns the new value.
function mPlayerData.Update(self, oPlayer: Player, sKey: string, fn: (any) -> any)
    local vCurrent = DeepClone(self:Get(oPlayer, sKey))
    self:Set(oPlayer, sKey, fn(vCurrent))
end

return mPlayerData
