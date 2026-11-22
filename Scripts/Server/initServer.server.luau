local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local Loader = require(ReplicatedStorage.BCDKShared.Loader)

local BCDKServerModules = Loader:GetModules(ServerStorage.BCDKServer)
local ServerModules = Loader:GetModules(ServerStorage.ServerModules)

local PlaceManager = require(ReplicatedStorage.Shared.PlaceManager)

Loader:RunAll(
    BCDKServerModules,
    "PreloadAsync"
)

Loader:RunAll(
    ServerModules,
    "PreloadAsync"
)

Loader:RunAll(
    ServerModules,
    PlaceManager.GetPreloadPredicate()
)

Loader:SpawnAll(
    BCDKServerModules,
    "StartAsync"
)

Loader:SpawnAll(
    ServerModules,
    "StartAsync"
)

Loader:SpawnAll(
    ServerModules,
    PlaceManager.GetStartPredicate()
)

Players.PlayerAdded:Connect(function(oPlayer: Player)
    Loader:RunAll(BCDKServerModules, "PlayerAdded", oPlayer)
    Loader:RunAll(ServerModules, "PlayerAdded", oPlayer)
end)

for _, oPlayer in ipairs(Players:GetPlayers()) do
    task.spawn(function()
        Loader:RunAll(BCDKServerModules, "PlayerAdded", oPlayer)
        Loader:RunAll(ServerModules, "PlayerAdded", oPlayer)
    end)
end

-- Ends the ProfileStore session (runs every module's PlayerRemoving hook
-- with data still writable, then saves). Without this, sessions stay locked
-- until the server closes.
local SMProfile = require(ServerStorage.BCDKServer.SMProfile)
Players.PlayerRemoving:Connect(function(oPlayer: Player)
    SMProfile:ReleaseProfile(oPlayer)
end)