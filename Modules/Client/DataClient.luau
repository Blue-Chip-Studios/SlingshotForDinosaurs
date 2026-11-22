--[[
    DataClient
    ----------
    Mirrors the server's PlayerData and Currency replicas, plus a few player
    and world attributes, into the LMGui Store so every screen reads one
    source of truth. Also exposes Changed(key, fn) for gameplay controllers.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Module = require(ReplicatedStorage.Shared.Module)
local ReplicaClient = require(ReplicatedStorage.External.Replica.ReplicaClient)
local Store = require(ReplicatedStorage.BCDKClient.LMGui.Store)

local oLocalPlayer = Players.LocalPlayer
local tListeners: { [string]: { (any) -> () } } = {}
local tData: { [string]: any } = {}

local function Push(sKey: string, vValue: any)
    tData[sKey] = vValue
    local oValue = Store.Values[sKey]
    if oValue then
        -- Fusion treats tables by reference; pass a fresh copy so dependants update.
        oValue:set(if typeof(vValue) == "table" then table.clone(vValue) else vValue)
    end
    for _, fn in tListeners[sKey] or {} do
        task.spawn(fn, vValue)
    end
end

local mData = Module()

function mData.PreloadAsync(self)
    ReplicaClient.OnNew("PlayerData", function(oReplica)
        for sKey, vValue in oReplica.Data do
            Push(sKey, vValue)
        end
        Push("DataLoaded", true)
        oReplica:OnChange(function(_, tPath)
            local sKey = tPath[1]
            if typeof(sKey) == "string" then
                Push(sKey, oReplica.Data[sKey])
            end
        end)
    end)
    ReplicaClient.OnNew("CurrencyReplica", function(oReplica)
        Push("Cash", oReplica.Data.Cash or 0)
        oReplica:OnChange(function()
            Push("Cash", oReplica.Data.Cash or 0)
        end)
    end)

    local function MirrorAttribute(oInstance: Instance, sAttribute: string, sKey: string, vDefault: any)
        Push(sKey, oInstance:GetAttribute(sAttribute) or vDefault)
        oInstance:GetAttributeChangedSignal(sAttribute):Connect(function()
            Push(sKey, oInstance:GetAttribute(sAttribute) or vDefault)
        end)
    end
    MirrorAttribute(oLocalPlayer, "Income", "Income", 0)
    MirrorAttribute(oLocalPlayer, "OnPad", "OnPad", 0)
    MirrorAttribute(oLocalPlayer, "IsAdmin", "IsAdmin", false)
    MirrorAttribute(oLocalPlayer, "FriendsHere", "FriendsHere", 0)
    MirrorAttribute(oLocalPlayer, "GroupMember", "GroupMember", false)
    MirrorAttribute(Workspace, "Weather", "Weather", "Clear")
    MirrorAttribute(Workspace, "WeatherEndsAt", "WeatherEndsAt", 0)
    MirrorAttribute(Workspace, "NextWeather", "NextWeather", "MeteorStorm")
    MirrorAttribute(Workspace, "NextWeatherAt", "NextWeatherAt", 0)
    MirrorAttribute(Workspace, "ServerLuck", "ServerLuck", 1)
    MirrorAttribute(Workspace, "ServerLuckEndsAt", "ServerLuckEndsAt", 0)
end

function mData.StartAsync(self)
    while true do
        Store.Values.Now:set(Workspace:GetServerTimeNow())
        task.wait(0.25)
    end
end

function mData.Get(self, sKey: string): any
    return tData[sKey]
end

-- fn(value) runs on every change of sKey (and once now if already loaded).
function mData.Changed(self, sKey: string, fn: (any) -> ())
    tListeners[sKey] = tListeners[sKey] or {}
    table.insert(tListeners[sKey], fn)
    if tData[sKey] ~= nil then
        task.spawn(fn, tData[sKey])
    end
end

return mData
