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

function mAnalytics.PlayerRemoving(self, oPlayer: Player)
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
