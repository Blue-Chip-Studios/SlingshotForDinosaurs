local PlaceManager = {}

-- Place ids for multi-place setups. Leave empty for a single-place game;
-- the predicates below then return nil and only PreloadAsync/StartAsync run.
local Lobbies = {
}

local Games = {
}

-- [UniverseId] = { Game = PlaceId, Lobby = PlaceId }
local mappedPlacesToUniverseId = {
}

local function GetPreloadPredicate()
    local oPlaceId = game.PlaceId
    if table.find(Lobbies, oPlaceId) then
        return "PreloadLobbyAsync"
    elseif table.find(Games, oPlaceId) then
        return "PreloadGameAsync"
    end
end

local function GetStartPredicate()
    local oPlaceId = game.PlaceId
    if table.find(Lobbies, oPlaceId) then
        return "StartLobbyAsync"
    elseif table.find(Games, oPlaceId) then
        return "StartGameAsync"
    end
end

local function IsLobby(): boolean
    return table.find(Lobbies, game.PlaceId) ~= nil
end

local function GetPlaceId(placeType: string)
    local tPlaces = mappedPlacesToUniverseId[game.GameId]
    if not tPlaces then
        return nil
    end
    if placeType == "Lobby" then
        return tPlaces.Lobby
    elseif placeType == "Game" then
        return tPlaces.Game
    end
end

return {
    GetPreloadPredicate = GetPreloadPredicate,
    GetStartPredicate = GetStartPredicate,
    GetPlaceId = GetPlaceId,
    IsLobby = IsLobby,
}
