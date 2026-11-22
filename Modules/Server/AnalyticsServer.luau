--[[
    AnalyticsServer
    ---------------
    The single place analytics are logged (Roblox AnalyticsService). Event
    names must exist in Config/AnalyticsConfig. Client UI events arrive
    through one rate-limited remote and are validated here.
]]

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Module = require(ReplicatedStorage.Shared.Module)
local Remote = require(ReplicatedStorage.BCDKShared.Remote)
local AnalyticsConfig = require(ReplicatedStorage.Config.AnalyticsConfig)

local tOnboardingDone: { [Player]: { [number]: boolean } } = {}
local tUIBudget: { [Player]: { nCount: number, nWindowStart: number } } = {}
local tIncomeBatch: { [Player]: number } = {}

local function SafeCall(fn, ...)
    local bOk, sErr = pcall(fn, ...)
    if not bOk and RunService:IsStudio() then
        warn("[Analytics]", sErr)
    end
end

local mAnalytics = Module()

function mAnalytics.PreloadAsync(self)
    local oUIEvent = Remote:GetEvent("AnalyticsUI")
    oUIEvent:OnServerEvent(function(oPlayer: Player, tPayload)
        if typeof(tPayload) ~= "table" then return end
        local sName = tPayload.Name
        if typeof(sName) ~= "string" or not AnalyticsConfig.ClientUI[sName] then return end
        local tBudget = tUIBudget[oPlayer]
        local nNow = os.clock()
        if not tBudget or nNow - tBudget.nWindowStart > 60 then
            tBudget = { nCount = 0, nWindowStart = nNow }
            tUIBudget[oPlayer] = tBudget
        end
        tBudget.nCount += 1
        if tBudget.nCount > AnalyticsConfig.ClientUIMaxPerMinute then return end
        local sDetail = if typeof(tPayload.Detail) == "string" then tPayload.Detail:sub(1, 40) else nil
        self:Custom(oPlayer, sName, nil, sDetail and { [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = sDetail } or nil)
    end)
end

function mAnalytics.StartAsync(self)
    -- Flush batched enclosure income as one economy event per player per minute.
    while true do
        task.wait(AnalyticsConfig.IncomeBatchSeconds)
        for oPlayer, nAmount in tIncomeBatch do
            if nAmount > 0 and oPlayer.Parent == Players then
                self:Economy(oPlayer, Enum.AnalyticsEconomyFlowType.Source, "Cash", math.floor(nAmount), 0, Enum.AnalyticsEconomyTransactionType.Gameplay.Name, "EnclosureIncome")
            end
        end
        table.clear(tIncomeBatch)
    end
end


-- ===== Sessions & acquisition =====
-- Where a player came from, for comparing ads/links/invites in the dashboard:
--   * launchData "src:<source>:<campaign>"  -> e.g. src:tiktok:launch1 (put it on
--     external links: roblox.com/games/start?placeId=<id>&launchData=src%3Atiktok%3Alaunch1)
--   * a notification's launchData (its message name) -> "Notification"
--   * ReferredByPlayerId > 0 (invite / share link) -> "Invite"
--   * otherwise "Roblox" (home, search, sponsored ads: split in the Acquisition dashboard)
local tSession: { [Player]: { nStart: number, sSource: string, sCampaign: string } } = {}

local function JoinSource(oPlayer: Player): (string, string)
    local bOk, tJoin = pcall(oPlayer.GetJoinData, oPlayer)
    if not bOk or typeof(tJoin) ~= "table" then return "Roblox", "-" end
    local sLaunch = if typeof(tJoin.LaunchData) == "string" then tJoin.LaunchData:sub(1, 60) else ""
    local sSrc, sCampaign = sLaunch:match("^src:([%w_%-]+):?([%w_%-]*)")
    if sSrc then return sSrc, if sCampaign ~= "" then sCampaign else "-" end
    if sLaunch ~= "" then return "Notification", sLaunch:match("^[%w_]+") or "-" end
    if (tJoin.ReferredByPlayerId or 0) > 0 then return "Invite", "-" end
    if tJoin.SourcePlaceId and tJoin.SourcePlaceId ~= game.PlaceId then return "Teleport", tostring(tJoin.SourcePlaceId) end
    return "Roblox", "-"
end

local function LengthBucket(nMinutes: number): string
    if nMinutes < 2 then return "0-2m" elseif nMinutes < 5 then return "2-5m" elseif nMinutes < 15 then return "5-15m"
    elseif nMinutes < 30 then return "15-30m" elseif nMinutes < 60 then return "30-60m" end
    return "60m+"
end

function mAnalytics.PlayerAdded(self, oPlayer: Player)
    local sSource, sCampaign = JoinSource(oPlayer)
    tSession[oPlayer] = { nStart = os.clock(), sSource = sSource, sCampaign = sCampaign }
    oPlayer:SetAttribute("JoinSource", sSource)
    self:Custom(oPlayer, "SessionStart", 1, self:Fields(sSource, sCampaign))
end

function mAnalytics.GetSource(self, oPlayer: Player): string
    return tSession[oPlayer] and tSession[oPlayer].sSource or "Roblox"
end

local function EndSession(self, oPlayer: Player)
    local t = tSession[oPlayer]
    if not t then return end
    tSession[oPlayer] = nil
    local nMinutes = (os.clock() - t.nStart) / 60
    -- Value = minutes played; fields let the dashboard break playtime down by source.
    self:Custom(oPlayer, "SessionEnd", math.floor(nMinutes * 10 + 0.5) / 10, self:Fields(t.sSource, t.sCampaign, LengthBucket(nMinutes)))
end

function mAnalytics.PlayerRemoving(self, oPlayer: Player)
    EndSession(self, oPlayer)
    tOnboardingDone[oPlayer] = nil
    tUIBudget[oPlayer] = nil
    tIncomeBatch[oPlayer] = nil
end

-- Logs an FTUE step once per session (FTUEServer also persists progress).
function mAnalytics.Onboarding(self, oPlayer: Player, sStep: string)
    local iStep = AnalyticsConfig.OnboardingSteps[sStep]
    if not iStep then
        warn("[Analytics] unknown onboarding step", sStep)
        return
    end
    tOnboardingDone[oPlayer] = tOnboardingDone[oPlayer] or {}
    if tOnboardingDone[oPlayer][iStep] then return end
    tOnboardingDone[oPlayer][iStep] = true
    SafeCall(AnalyticsService.LogOnboardingFunnelStepEvent, AnalyticsService, oPlayer, iStep, sStep)
end

function mAnalytics.Funnel(self, oPlayer: Player, sFunnel: string, sSessionId: string?, iStep: number, sStep: string)
    SafeCall(AnalyticsService.LogFunnelStepEvent, AnalyticsService, oPlayer, sFunnel, sSessionId, iStep, sStep)
end

function mAnalytics.Economy(self, oPlayer: Player, eFlow: Enum.AnalyticsEconomyFlowType, sCurrency: string, nAmount: number, nEndingBalance: number, sTransactionType: string, sItemSku: string?)
    SafeCall(AnalyticsService.LogEconomyEvent, AnalyticsService, oPlayer, eFlow, sCurrency, nAmount, nEndingBalance, sTransactionType, sItemSku)
end

function mAnalytics.Progression(self, oPlayer: Player, sPath: string, eStatus: Enum.AnalyticsProgressionType, iLevel: number?, sLevelName: string?)
    SafeCall(AnalyticsService.LogProgressionEvent, AnalyticsService, oPlayer, sPath, eStatus, iLevel, sLevelName)
end

function mAnalytics.Custom(self, oPlayer: Player, sName: string, nValue: number?, tFields: { [string]: string }?)
    if not (AnalyticsConfig.Custom[sName] or AnalyticsConfig.ClientUI[sName]) then
        warn("[Analytics] unknown custom event", sName)
        return
    end
    SafeCall(AnalyticsService.LogCustomEvent, AnalyticsService, oPlayer, sName, nValue or 1, tFields)
end

function mAnalytics.AddIncome(self, oPlayer: Player, nAmount: number)
    tIncomeBatch[oPlayer] = (tIncomeBatch[oPlayer] or 0) + nAmount
end

-- Helper: AnalyticsService custom fields keyed by CustomField01..03.
function mAnalytics.Fields(self, s1: string?, s2: string?, s3: string?): { [string]: string }
    local t = {}
    if s1 then t[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = s1 end
    if s2 then t[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = s2 end
    if s3 then t[Enum.AnalyticsCustomFieldKeys.CustomField03.Name] = s3 end
    return t
end

return mAnalytics
