local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.BCDKShared.Loader)
local ReplicaClient = require(ReplicatedStorage.External.Replica.ReplicaClient)

local BCDKClientModules = Loader:GetModules(ReplicatedStorage.BCDKClient)
local ClientModules = Loader:GetModules(ReplicatedStorage.ClientModules)

local PlaceManager = require(ReplicatedStorage.Shared.PlaceManager)

Loader:RunAll(
    BCDKClientModules,
    "PreloadAsync"
)

Loader:RunAll(
    ClientModules,
    "PreloadAsync"
)

Loader:RunAll(
    ClientModules,
    PlaceManager.GetPreloadPredicate()
)

Loader:SpawnAll(
    BCDKClientModules,
    "StartAsync"
)

Loader:SpawnAll(
    ClientModules,
    "StartAsync"
)

Loader:SpawnAll(
    ClientModules,
    PlaceManager.GetStartPredicate()
)

ReplicaClient.RequestData()

-- Signals that every client module has started (e.g. for a ReplicatedFirst loading screen).
game:GetService("Players").LocalPlayer:SetAttribute("ClientReady", true)