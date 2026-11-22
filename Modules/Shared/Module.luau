--[[
    Module
    ------
    Thin wrapper around BCDK.CreateModule. On the server, BCDK's template
    warns for every lifecycle hook a module doesn't implement, and the
    Loader calls every hook it can index. This fills unimplemented hooks
    with silent no-ops so the output stays readable.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BCDK = require(ReplicatedStorage.BCDKShared.BCDK)

local tHooks = {
    "PreloadAsync", "StartAsync", "PreloadLobbyAsync", "StartLobbyAsync", "PreloadGameAsync", "StartGameAsync",
    "PlayerAdded", "InitProfileAsync", "InitReplicaAsync", "PlayerRemoving", "ReleaseProfile", "ProfileReleased",
}

local function NoOp() end

return function(tModule: { [string]: any }?)
    tModule = tModule or {}
    for _, sHook in tHooks do
        if rawget(tModule, sHook) == nil then
            rawset(tModule, sHook, NoOp)
        end
    end
    return BCDK.CreateModule(tModule)
end
