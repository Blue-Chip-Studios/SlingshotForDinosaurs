--[[
    TrainingServer
    --------------
    Power training on the rim pads (DECISIONS #6). Standing on an unlocked
    pad gains Power every TrainTickSeconds; tapping TRAIN adds up to
    TrainTapMaxPerSecond extra trains. Position and pad unlocks are checked
    on the server; the 2x Slingshot Power pass doubles every gain.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Module = require(ReplicatedStorage.Shared.Module)
local Remote = require(ReplicatedStorage.BCDKShared.Remote)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local ShopConfig = require(ReplicatedStorage.Config.ShopConfig)

local PlayerDataServer = require(ServerStorage.ServerModules.PlayerDataServer)
local AnalyticsServer = require(ServerStorage.ServerModules.AnalyticsServer)
local FTUEServer = require(ServerStorage.ServerModules.FTUEServer)

local tTapWindow: { [Player]: { nStart: number, nCount: number } } = {}
local tUnlockedLogged: { [Player]: { [number]: boolean } } = {}

local function PadFor(oPlayer: Player): number?
    local oCharacter = oPlayer.Character
    local oRoot = oCharacter and oCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not oRoot then return nil end
    return WorldLayout.PadAt(oRoot.Position - Vector3.new(0, 3, 0))
end

local function Train(oPlayer: Player, iPad: number): boolean
    local tPad = ShopConfig.Pads[iPad]
    local nPower = PlayerDataServer:Get(oPlayer, "Power") or 0
    if nPower < tPad.RequiredPower then
        return false
    end
    local tPasses = PlayerDataServer:Get(oPlayer, "Passes") or {}
    local nGain = tPad.PowerPerTick * (if tPasses.DoublePower then 2 else 1)
    PlayerDataServer:Set(oPlayer, "Power", nPower + nGain)
    FTUEServer:Reach(oPlayer, "FirstTrain")
    -- Log pad unlocks once (the moment Power crosses a pad's requirement).
    for i, t in ShopConfig.Pads do
        if t.RequiredPower > 0 and nPower < t.RequiredPower and nPower + nGain >= t.RequiredPower then
            tUnlockedLogged[oPlayer] = tUnlockedLogged[oPlayer] or {}
            if not tUnlockedLogged[oPlayer][i] then
                tUnlockedLogged[oPlayer][i] = true
                AnalyticsServer:Progression(oPlayer, "TrainingPad", Enum.AnalyticsProgressionType.Complete, i, t.Id)
            end
        end
    end
    return true
end

local mTraining = Module()

function mTraining.PreloadAsync(self)
    Remote:GetEvent("TrainTap"):OnServerEvent(function(oPlayer: Player)
        if not PlayerDataServer:IsReady(oPlayer) then return end
        local nNow = os.clock()
        local tWindow = tTapWindow[oPlayer]
        if not tWindow or nNow - tWindow.nStart >= 1 then
            tWindow = { nStart = nNow, nCount = 0 }
            tTapWindow[oPlayer] = tWindow
        end
        if tWindow.nCount >= GameConfig.TrainTapMaxPerSecond then return end
        local iPad = PadFor(oPlayer)
        if iPad and Train(oPlayer, iPad) then
            tWindow.nCount += 1
        end
    end)
end

function mTraining.StartAsync(self)
    Players.PlayerRemoving:Connect(function(oPlayer)
        tTapWindow[oPlayer] = nil
        tUnlockedLogged[oPlayer] = nil
    end)
    while true do
        task.wait(GameConfig.TrainTickSeconds)
        for _, oPlayer in Players:GetPlayers() do
            if PlayerDataServer:IsReady(oPlayer) then
                local iPad = PadFor(oPlayer)
                oPlayer:SetAttribute("OnPad", iPad or 0)
                if iPad then
                    Train(oPlayer, iPad)
                end
            end
        end
    end
end

return mTraining
