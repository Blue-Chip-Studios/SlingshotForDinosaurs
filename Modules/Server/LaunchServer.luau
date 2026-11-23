--[[
    LaunchServer
    ------------
    Server-authoritative launches (DECISIONS #5).

    1. Client invokes RequestLaunch({ Charge, Aim }). The server validates the
       player (on the rim, not already flying, cooldown), computes the base
       distance, the landing point, the flight time and the bounce windows,
       and returns the plan.
    2. The client animates the arc and fires Bounce({ FlightId, T }) on a tap.
       The server matches the tap against its own windows and clock, and
       replies with BounceResult (new distance + landing).
    3. When the server's flight timer ends it finalises: rolls species, size
       and mutation, saves, places the dino and fires CatchResult.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Module = require(ReplicatedStorage.Shared.Module)
local Remote = require(ReplicatedStorage.BCDKShared.Remote)
local CanyonMath = require(ReplicatedStorage.Shared.CanyonMath)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local DinoConfig = require(ReplicatedStorage.Config.DinoConfig)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local ShopConfig = require(ReplicatedStorage.Config.ShopConfig)

local PlayerDataServer = require(ServerStorage.ServerModules.PlayerDataServer)
local AnalyticsServer = require(ServerStorage.ServerModules.AnalyticsServer)
local EnclosureServer = require(ServerStorage.ServerModules.EnclosureServer)
local WeatherServer = require(ServerStorage.ServerModules.WeatherServer)
local FTUEServer = require(ServerStorage.ServerModules.FTUEServer)
local CatchRoller = require(ServerStorage.ServerModules.CatchRoller)
local RetentionServer = require(ServerStorage.ServerModules.RetentionServer)
local BadgeServer = require(ServerStorage.ServerModules.BadgeServer)

type Flight = {
    Id: number,
    StartedAt: number,
    EndsAt: number,
    BaseMeters: number,
    Bonus: number,
    Bounces: number,
    Windows: { number },
    WindowState: { string }, -- "Open" | "Used" | "Missed"
    Origin: Vector3,
    Aim: number,
    Tutorial: boolean,
    LastTap: number,
    LastBounceAt: number?,
}

local tFlights: { [Player]: Flight } = {}
local tNextLaunchAt: { [Player]: number } = {}
local iNextFlightId = 0
local tForceRare: { [Player]: boolean } = {} -- set by the Admin panel, consumed on the next catch

local oRequestLaunch, oBounce, oBounceResult, oCatchResult, oAnnounce, oFlightBroadcast

local function FindShopItem(tList, sId)
    for i, t in tList do
        if t.Id == sId then
            return t, i
        end
    end
    return tList[1], 1
end

local function LandingFor(tFlight: Flight): (number, Vector3)
    local nMeters = math.min(tFlight.BaseMeters * (1 + tFlight.Bonus), DinoConfig.MaxMeters)
    return nMeters, CanyonMath.LandingPoint(tFlight.Origin, nMeters, tFlight.Aim)
end

local function IsRare(tDino): boolean
    local tSpecies = DinoConfig.Species[tDino.Species]
    return tSpecies.Rarity == "Legendary" or tDino.Size == "Huge" or tDino.Size == "Colossal"
        or (tDino.Mutation ~= "Normal" and tDino.Mutation ~= "Golden")
end

-- Celebration tier: "Mythic" (Cosmic, or Colossal and Legendary / top mutation) gets the full show
-- and blesses the server; "Epic" (any rare) gets a big client celebration; otherwise none.
local MYTHIC_LUCK, MYTHIC_SECONDS = 2, 120
local function CatchTier(tDino): string?
    local bLegendary = DinoConfig.Species[tDino.Species].Rarity == "Legendary"
    local bTopMutation = tDino.Mutation == "Cosmic" or tDino.Mutation == "Toxic" or tDino.Mutation == "Magma"
    if tDino.Mutation == "Cosmic" or (tDino.Size == "Colossal" and (bLegendary or bTopMutation)) then
        return "Mythic"
    end
    return if IsRare(tDino) then "Epic" else nil
end

local mLaunch = Module()

local function Finalise(oPlayer: Player, tFlight: Flight)
    if tFlights[oPlayer] ~= tFlight then return end
    tFlights[oPlayer] = nil
    tNextLaunchAt[oPlayer] = os.clock() + GameConfig.LaunchCooldownGrace
    if not PlayerDataServer:IsReady(oPlayer) then return end

    local nMeters = LandingFor(tFlight)
    local tBiome = DinoConfig.GetBiome(nMeters)
    local tBait = FindShopItem(ShopConfig.Bait, PlayerDataServer:Get(oPlayer, "Bait"))
    -- Depth: how far past this area's gate the bait landed (0 at the gate, ~1 at the next gate).
    local nDepth = (CanyonMath.MetersToStuds(nMeters) % CanyonMath.BiomeLength) / CanyonMath.BiomeLength
    local nLuck = tBait.Luck * (1 + GameConfig.Bounce.LuckPerBounce * tFlight.Bounces) * WeatherServer:GetServerLuck() * RetentionServer:GetLuckMultiplier(oPlayer)
        * (1 + GameConfig.DepthLuckBonus * nDepth)

    local sSpecies, sSize, sMutation
    local bFirstCatch = (PlayerDataServer:Get(oPlayer, "TotalLaunches") or 0) == 0
    if bFirstCatch then
        -- FTUE: the first catch is always a Big Velociraptor (GDD 6).
        sSpecies, sSize, sMutation = "Velociraptor", "Big", "Normal"
    else
        local bForce = tForceRare[oPlayer] == true
        tForceRare[oPlayer] = nil
        sSpecies = CatchRoller.RollSpecies(tBiome.Id, nLuck, bForce)
        sSize = CatchRoller.RollSize(nLuck * WeatherServer:GetSizeLuck())
        sMutation = CatchRoller.RollMutation(nLuck, WeatherServer:GetMutationMultipliers())
        if bForce and sMutation == "Normal" then
            sMutation = "Golden"
        end
    end

    local tDino = EnclosureServer:NewDino(oPlayer, sSpecies, sSize, sMutation)
    local bNewIndex = EnclosureServer:MarkIndex(oPlayer, sSpecies, sMutation)

    -- Stats and progression
    PlayerDataServer:Set(oPlayer, "TotalLaunches", (PlayerDataServer:Get(oPlayer, "TotalLaunches") or 0) + 1)
    local bNewBest = nMeters > (PlayerDataServer:Get(oPlayer, "BestDistance") or 0)
    if bNewBest then
        PlayerDataServer:Set(oPlayer, "BestDistance", nMeters)
    end
    local tReached = PlayerDataServer:Get(oPlayer, "BiomesReached") or {}
    local bNewBiome = not tReached[tBiome.Id]
    if bNewBiome then
        PlayerDataServer:Update(oPlayer, "BiomesReached", function(t)
            t[tBiome.Id] = true
            return t
        end)
        AnalyticsServer:Progression(oPlayer, "Biome", Enum.AnalyticsProgressionType.Complete, DinoConfig.GetBiomeIndex(nMeters), tBiome.Id)
    end

    local tPlacement = EnclosureServer:AddDino(oPlayer, tDino)
    FTUEServer:Reach(oPlayer, "FirstCatch")
    if tPlacement.Status == "Placed" or tPlacement.Status == "Replaced" then
        FTUEServer:Reach(oPlayer, "FirstPlacement")
    end

    RetentionServer:Track(oPlayer, "Launch", 1)
    if DinoConfig.Species[sSpecies].Rarity ~= "Common" then RetentionServer:Track(oPlayer, "Rare", 1) end
    if sMutation ~= "Normal" then RetentionServer:Track(oPlayer, "Mutated", 1) end

    -- Badges
    BadgeServer:Award(oPlayer, "FirstCatch")
    if sMutation ~= "Normal" then BadgeServer:Award(oPlayer, "FirstMutation") end
    if sMutation == "Cosmic" then BadgeServer:Award(oPlayer, "Cosmic") end
    if sSize == "Colossal" then BadgeServer:Award(oPlayer, "Colossal") end
    if DinoConfig.Species[sSpecies].Rarity == "Legendary" then BadgeServer:Award(oPlayer, "Legendary") end
    for _, t in DinoConfig.Biomes do
        if t.MinMeters > 0 and nMeters >= t.MinMeters then BadgeServer:Award(oPlayer, "Biome_" .. t.Id) end
    end
    if sSize == "Big" or sSize == "Huge" or sSize == "Colossal" then RetentionServer:Track(oPlayer, "Big", 1) end
    AnalyticsServer:Custom(oPlayer, "Catch", DinoConfig.GetIncome(tDino), AnalyticsServer:Fields(DinoConfig.Species[sSpecies].Rarity, sSize, sMutation))
    AnalyticsServer:Custom(oPlayer, "Launch", nMeters, AnalyticsServer:Fields(tBiome.Id, tostring(tFlight.Bounces)))

    local sTier = CatchTier(tDino)
    oCatchResult:FireClient(oPlayer, {
        FlightId = tFlight.Id,
        Dino = tDino,
        Meters = nMeters,
        Biome = tBiome.Id,
        Income = DinoConfig.GetIncome(tDino),
        NewIndex = bNewIndex,
        NewBest = bNewBest,
        NewBiome = bNewBiome,
        Placement = tPlacement,
        Tier = sTier,
    })

    if sTier then
        local tSize = DinoConfig.GetSize(sSize)
        local tMut = DinoConfig.GetMutation(sMutation)
        local sPrefix = (if tSize.Default then "" else tSize.Name .. " ") .. (if tMut.Default then "" else tMut.Name .. " ")
        local sName = sPrefix .. DinoConfig.Species[sSpecies].Name
        if sTier == "Mythic" then
            -- The whole server shares the moment: big banner and a luck blessing for everyone.
            if WeatherServer:GetServerLuck() < MYTHIC_LUCK then
                WeatherServer:SetServerLuck(MYTHIC_LUCK, MYTHIC_SECONDS)
            end
            oAnnounce:FireAllClients({ Text = `MYTHIC! {oPlayer.DisplayName} caught a {sName}! Everyone gets 2x luck for 2 minutes!`, Kind = "Mythic", Mutation = sMutation, UserId = oPlayer.UserId })
            AnalyticsServer:Custom(oPlayer, "MythicCatch", DinoConfig.GetIncome(tDino), AnalyticsServer:Fields(sSpecies, sSize, sMutation))
        else
            oAnnounce:FireAllClients({ Text = `{oPlayer.DisplayName} caught a {sName}!`, Kind = "Catch", Mutation = sMutation })
        end
    end
end

local function Plan(oPlayer: Player, tPayload): { [string]: any }
    if not PlayerDataServer:IsReady(oPlayer) then
        return { Ok = false, Reason = "Loading" }
    end
    if tFlights[oPlayer] then
        return { Ok = false, Reason = "Flying" }
    end
    if os.clock() < (tNextLaunchAt[oPlayer] or 0) then
        return { Ok = false, Reason = "Cooldown" }
    end
    local oCharacter = oPlayer.Character
    local oRoot = oCharacter and oCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
    local oHumanoid = oCharacter and oCharacter:FindFirstChildOfClass("Humanoid")
    if not (oRoot and oHumanoid and oHumanoid.Health > 0) then
        return { Ok = false, Reason = "NoCharacter" }
    end
    if not WorldLayout.IsOnRim(oRoot.Position) then
        return { Ok = false, Reason = "NotOnRim" }
    end
    if typeof(tPayload) ~= "table" then
        return { Ok = false, Reason = "Bad" }
    end
    local nCharge = if typeof(tPayload.Charge) == "number" and tPayload.Charge == tPayload.Charge then math.clamp(tPayload.Charge, 0, 1) else 0
    local nAim = if typeof(tPayload.Aim) == "number" and tPayload.Aim == tPayload.Aim then math.clamp(tPayload.Aim, -1, 1) else 0

    local tSling = FindShopItem(ShopConfig.Slingshots, PlayerDataServer:Get(oPlayer, "Slingshot"))
    local nPower = PlayerDataServer:Get(oPlayer, "Power") or GameConfig.StartingPower
    local nChargeMult = GameConfig.MinCharge + (1 - GameConfig.MinCharge) * nCharge
    local nBase = math.max(1, nPower * tSling.Multiplier * nChargeMult)

    iNextFlightId += 1
    local vOrigin = oRoot.Position + Vector3.new(0, 3, -3)
    local tFlight: Flight = {
        Id = iNextFlightId,
        StartedAt = os.clock(),
        EndsAt = 0,
        BaseMeters = nBase,
        Bonus = 0,
        Bounces = 0,
        Windows = {},
        WindowState = {},
        Origin = vOrigin,
        Aim = nAim,
        Tutorial = (PlayerDataServer:Get(oPlayer, "TotalLaunches") or 0) == 0,
        LastTap = 0,
    }
    local _, vLanding = LandingFor(tFlight)
    local nDuration = CanyonMath.FlightTime(vOrigin, vLanding)
    local nSeed = math.random(1, 2 ^ 30)
    tFlight.Windows = CanyonMath.BounceWindows(nSeed, (vLanding - vOrigin).Magnitude, nDuration)
    for i in tFlight.Windows do
        tFlight.WindowState[i] = "Open"
    end
    tFlight.EndsAt = tFlight.StartedAt + nDuration
    tFlights[oPlayer] = tFlight

    FTUEServer:Reach(oPlayer, "FirstCharge")
    FTUEServer:Reach(oPlayer, "FirstLaunch")

    task.spawn(function()
        while tFlights[oPlayer] == tFlight and os.clock() < tFlight.EndsAt do
            task.wait(math.max(0.03, tFlight.EndsAt - os.clock()))
        end
        Finalise(oPlayer, tFlight)
    end)

    -- Light broadcast so other clients can draw this launch's arc locally.
    oFlightBroadcast:FireAllClients({ UserId = oPlayer.UserId, Origin = vOrigin, Landing = vLanding, Duration = nDuration })

    return {
        Ok = true,
        FlightId = tFlight.Id,
        BaseMeters = nBase,
        Origin = vOrigin,
        Landing = vLanding,
        Duration = nDuration,
        Windows = tFlight.Windows,
        Tutorial = tFlight.Tutorial,
        BaitColor = FindShopItem(ShopConfig.Bait, PlayerDataServer:Get(oPlayer, "Bait")).Color,
    }
end

local function HandleBounce(oPlayer: Player, tPayload)
    local tFlight = tFlights[oPlayer]
    if not tFlight or typeof(tPayload) ~= "table" or tPayload.FlightId ~= tFlight.Id then return end
    local nNow = os.clock()
    if nNow - tFlight.LastTap < 0.12 then return end -- tap spam guard
    tFlight.LastTap = nNow
    -- Double-click safety: a second tap right after a successful bounce never burns the next window.
    if nNow - (tFlight.LastBounceAt or -1e9) < GameConfig.Bounce.AfterBounceGrace then return end
    local nServerT = nNow - tFlight.StartedAt
    local nClientT = if typeof(tPayload.T) == "number" and tPayload.T == tPayload.T then tPayload.T else nServerT
    -- Trust the client's timestamp for quality only when it agrees with the server clock.
    local nT = if math.abs(nClientT - nServerT) <= GameConfig.Bounce.ServerClockTolerance then nClientT else nServerT
    local nOK = GameConfig.Bounce.OK.Window
    local nExtra = GameConfig.BounceExtraTime

    for i, nWindow in tFlight.Windows do
        if tFlight.WindowState[i] == "Open" then
            local nExpected = nWindow + nExtra * tFlight.Bounces
            if nT > nExpected + nOK then
                tFlight.WindowState[i] = "Missed" -- passed without a tap
            else
                local nError = nT - nExpected
                local sQuality = CanyonMath.BounceQuality(nError)
                if tFlight.Tutorial and nError > -1.2 then
                    sQuality = "Perfect"
                end
                if sQuality then
                    tFlight.WindowState[i] = "Used"
                    tFlight.Bounces += 1
                    tFlight.LastBounceAt = nNow
                    tFlight.Bonus += GameConfig.Bounce[sQuality].Bonus
                    tFlight.EndsAt += nExtra
                    local nMeters, vLanding = LandingFor(tFlight)
                    oBounceResult:FireClient(oPlayer, { FlightId = tFlight.Id, Window = i, Quality = sQuality, Meters = nMeters, Landing = vLanding, EndsIn = tFlight.EndsAt - nNow })
                    FTUEServer:Reach(oPlayer, "FirstBounce")
                    RetentionServer:OnBounce(oPlayer, sQuality)
                    AnalyticsServer:Custom(oPlayer, "Bounce", 1, AnalyticsServer:Fields(sQuality))
                elseif nError < -nOK and nError > -GameConfig.Bounce.EarlyMissFrom then
                    -- Early tap: this window is lost (stops tap-spamming through every window).
                    tFlight.WindowState[i] = "Missed"
                    oBounceResult:FireClient(oPlayer, { FlightId = tFlight.Id, Window = i, Quality = "Miss" })
                    RetentionServer:OnBounce(oPlayer, "Miss")
                end
                return
            end
        end
    end
end

function mLaunch.PreloadAsync(self)
    oRequestLaunch = Remote:GetFunction("RequestLaunch")
    oBounce = Remote:GetEvent("Bounce")
    oBounceResult = Remote:GetEvent("BounceResult")
    oCatchResult = Remote:GetEvent("CatchResult")
    oAnnounce = Remote:GetEvent("Announcement")
    oFlightBroadcast = Remote:GetEvent("FlightBroadcast")

    oRequestLaunch:OnServerInvoke(Plan)
    oBounce:OnServerEvent(HandleBounce)
end

function mLaunch.StartAsync(self)
    Players.PlayerRemoving:Connect(function(oPlayer)
        tFlights[oPlayer] = nil
        tNextLaunchAt[oPlayer] = nil
        tForceRare[oPlayer] = nil
    end)
end

-- Admin: the next launch of every current player rolls a Legendary with at least Golden.
function mLaunch.ForceRareForAll(self)
    for _, oPlayer in Players:GetPlayers() do
        tForceRare[oPlayer] = true
    end
end

function mLaunch.IsFlying(self, oPlayer: Player): boolean
    return tFlights[oPlayer] ~= nil
end

return mLaunch
