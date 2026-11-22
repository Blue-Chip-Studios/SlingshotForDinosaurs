--[[
    WeatherServer
    -------------
    The 20-minute world cycle (15 min clear + 5 min event, alternating
    Meteor Storm / Ice Age), plus overrides from the Admin panel and the
    Server Meteor Storm product, and the admin server-luck boost.

    State replicates as Workspace attributes, using server time so every
    client's countdown agrees:
        Weather            "Clear" | "MeteorStorm" | "IceAge"
        WeatherEndsAt      server time the current event ends (0 when clear)
        NextWeather        type of the next scheduled event
        NextWeatherAt      server time the next scheduled event starts
        ServerLuck         admin luck multiplier (1 = none)
        ServerLuckEndsAt   server time the luck boost ends
        StormBuyer         display name credited for a purchased storm
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Module = require(ReplicatedStorage.Shared.Module)
local Remote = require(ReplicatedStorage.BCDKShared.Remote)
local WeatherConfig = require(ReplicatedStorage.Config.WeatherConfig)

local AnalyticsServer = require(ServerStorage.ServerModules.AnalyticsServer)

local tOverride: { sType: string, nEndsAt: number }? = nil
local nLuck, nLuckEndsAt = 1, 0
local sLastWeather = "Clear"
local oAnnounce

local function Now(): number
    return Workspace:GetServerTimeNow()
end

-- Scheduled (cycle) weather at a given time.
local function Scheduled(nTime: number): (string, number, string, number)
    local nCycle = WeatherConfig.CycleSeconds
    local iCycle = math.floor(nTime / nCycle)
    local nInCycle = nTime - iCycle * nCycle
    local nEventStart = nCycle - WeatherConfig.EventSeconds
    local sThis = WeatherConfig.Order[(iCycle % #WeatherConfig.Order) + 1]
    local sNext = WeatherConfig.Order[((iCycle + 1) % #WeatherConfig.Order) + 1]
    if nInCycle >= nEventStart then
        return sThis, iCycle * nCycle + nCycle, sNext, (iCycle + 1) * nCycle + nEventStart
    end
    return "Clear", 0, sThis, iCycle * nCycle + nEventStart
end

local mWeather = Module()

function mWeather.GetWeather(self): string
    return Workspace:GetAttribute("Weather") or "Clear"
end

function mWeather.GetMutationMultipliers(self): { [string]: number }?
    local tEvent = WeatherConfig.Events[self:GetWeather()]
    return tEvent and tEvent.MutationMultipliers
end

function mWeather.GetSizeLuck(self): number
    local tEvent = WeatherConfig.Events[self:GetWeather()]
    return tEvent and tEvent.SizeLuck or 1
end

function mWeather.GetServerLuck(self): number
    return if Now() < nLuckEndsAt then nLuck else 1
end

-- Starts (or extends) an event for nSeconds. sBuyer credits a purchase.
function mWeather.TriggerEvent(self, sType: string, nSeconds: number, sBuyer: string?)
    assert(WeatherConfig.Events[sType] or sType == "Clear", "unknown weather " .. sType)
    local nNow = Now()
    if tOverride and tOverride.sType == sType and tOverride.nEndsAt > nNow then
        tOverride.nEndsAt += nSeconds
    else
        tOverride = { sType = sType, nEndsAt = nNow + nSeconds }
    end
    Workspace:SetAttribute("StormBuyer", sBuyer or "")
    if sBuyer then
        oAnnounce:FireAllClients({ Text = `{sBuyer} started a METEOR STORM!`, Kind = "Event" })
    end
    self:Update()
end

function mWeather.SetServerLuck(self, nMultiplier: number, nSeconds: number)
    nLuck = math.clamp(nMultiplier, 1, 100)
    nLuckEndsAt = Now() + nSeconds
    Workspace:SetAttribute("ServerLuck", nLuck)
    Workspace:SetAttribute("ServerLuckEndsAt", nLuckEndsAt)
    oAnnounce:FireAllClients({ Text = `SERVER LUCK x{nLuck}!`, Kind = "Event" })
end

function mWeather.Update(self)
    local nNow = Now()
    local sType, nEndsAt, sNext, nNextAt = Scheduled(nNow)
    if tOverride then
        if tOverride.nEndsAt > nNow then
            sType, nEndsAt = tOverride.sType, tOverride.nEndsAt
        else
            tOverride = nil
            Workspace:SetAttribute("StormBuyer", "")
        end
    end
    if sType == "Clear" then
        nEndsAt = 0
    end
    Workspace:SetAttribute("Weather", sType)
    Workspace:SetAttribute("WeatherEndsAt", nEndsAt)
    Workspace:SetAttribute("NextWeather", sNext)
    Workspace:SetAttribute("NextWeatherAt", nNextAt)
    if nNow >= nLuckEndsAt and nLuck ~= 1 then
        nLuck = 1
        Workspace:SetAttribute("ServerLuck", 1)
    end
    if sType ~= sLastWeather then
        sLastWeather = sType
        if sType ~= "Clear" then
            oAnnounce:FireAllClients({ Text = `{WeatherConfig.Events[sType].Name:upper()}!`, Kind = "Event" })
            for _, oPlayer in Players:GetPlayers() do
                AnalyticsServer:Custom(oPlayer, "WeatherEventStarted", 1, AnalyticsServer:Fields(sType))
            end
        end
    end
end

function mWeather.PreloadAsync(self)
    oAnnounce = Remote:GetEvent("Announcement")
    Workspace:SetAttribute("ServerLuck", 1)
    Workspace:SetAttribute("ServerLuckEndsAt", 0)
    self:Update()
end

function mWeather.StartAsync(self)
    while true do
        task.wait(1)
        self:Update()
    end
end

return mWeather
