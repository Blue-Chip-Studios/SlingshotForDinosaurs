--[[
    SoftShutdownServer
    ------------------
    When a public server shuts down (e.g. "Restart servers for updates"),
    players are not just kicked:
      1. clients get "ServerUpdating" and show an updating screen,
      2. everyone is teleported to a temporary reserved server,
      3. that server sends them straight back to the place, landing on a
         fresh server running the new version.
    ProfileStore saves on close, and the next server waits for the session lock,
    so progress carries over.

    Skipped in Studio and in player-owned private servers (VIP servers), where
    sending players to a public server would be wrong; they simply rejoin.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Module = require(ReplicatedStorage.Shared.Module)
local Remote = require(ReplicatedStorage.BCDKShared.Remote)

local LOBBY_FLAG = "SFDSoftShutdown"

local function IsTempLobby(): boolean
    return game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
end

local function Teleport(tPlayers: { Player }, oOptions: TeleportOptions?)
    if #tPlayers == 0 then return end
    local bOk, sErr = pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, tPlayers, oOptions)
    if not bOk then
        warn("[SoftShutdown] teleport failed:", sErr)
    end
end

local mSoftShutdown = Module()

function mSoftShutdown.PreloadAsync(self)
    local oUpdating = Remote:GetEvent("ServerUpdating")

    if IsTempLobby() then
        -- Temporary holding server: send every arrival back to a fresh public server.
        Workspace:SetAttribute("SoftShutdownLobby", true)
        local function Send(oPlayer: Player)
            local tData = oPlayer:GetJoinData().TeleportData
            if typeof(tData) == "table" and tData[LOBBY_FLAG] then
                task.wait(2) -- let the old server finish saving
                for iTry = 1, 3 do
                    if oPlayer.Parent ~= Players then return end
                    Teleport({ oPlayer })
                    task.wait(4 * iTry) -- a successful teleport removes them before this ends
                end
                if oPlayer.Parent == Players then
                    oPlayer:Kick("The game just updated! Please rejoin to keep playing.")
                end
            end
        end
        Players.PlayerAdded:Connect(function(oPlayer)
            task.spawn(Send, oPlayer)
        end)
        for _, oPlayer in Players:GetPlayers() do
            task.spawn(Send, oPlayer)
        end
        return
    end

    if RunService:IsStudio() or game.PrivateServerOwnerId ~= 0 then return end

    game:BindToClose(function()
        local tPlayers = Players:GetPlayers()
        if #tPlayers == 0 then return end
        oUpdating:FireAllClients({ Text = "New update! Moving you to an updated server..." })
        task.wait(1.5)
        local bOk, sCode = pcall(TeleportService.ReserveServer, TeleportService, game.PlaceId)
        if not bOk then
            warn("[SoftShutdown] ReserveServer failed:", sCode)
            return
        end
        local oOptions = Instance.new("TeleportOptions")
        oOptions.ReservedServerAccessCode = sCode
        oOptions:SetTeleportData({ [LOBBY_FLAG] = true })
        Teleport(Players:GetPlayers(), oOptions)
        -- Keep the server alive while teleports leave (BindToClose allows ~30 s).
        local nDeadline = os.clock() + 20
        while #Players:GetPlayers() > 0 and os.clock() < nDeadline do
            task.wait(1)
        end
    end)
end

return mSoftShutdown
