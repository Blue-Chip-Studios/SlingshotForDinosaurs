--!strict
--[[
    GameConfig
    ----------
    Every tunable number for the core loop. Live-ops: change values here
    (or override server-side) instead of touching gameplay code.
    See Docs/GDD/GDD.html sections 8-12 for the reasoning behind each value.
]]

return {
    -- Launch
    StartingPower = 10,
    ChargeTime = 1.2, -- seconds to full charge
    MinCharge = 0.5, -- charge multiplier at an instant tap
    LaunchCooldownGrace = 0.4, -- extra seconds after landing before the next launch is accepted

    -- Flight timing (seconds), derived from world distance in studs
    FlightBaseTime = 1.6,
    FlightTimePerStud = 1 / 650,
    FlightMaxTime = 5.0,
    BounceExtraTime = 0.55, -- each successful bounce extends the flight

    -- Mid-air bounce windows (seconds either side of the geyser pass)
    Bounce = {
        Perfect = { Window = 0.12, Bonus = 0.35 },
        Good = { Window = 0.25, Bonus = 0.20 },
        OK = { Window = 0.40, Bonus = 0.10 },
        LuckPerBounce = 0.10,
        ServerClockTolerance = 0.35, -- allowed gap between client-reported and server-measured time
        MaxWindowFraction = 0.85, -- no geysers in the last 15% of a flight
    },

    -- Training
    TrainTickSeconds = 1.0, -- passive gain interval while standing on a pad
    TrainTapMaxPerSecond = 5, -- extra tap trains per second (server rate limit)

    -- Enclosure
    SellSecondsOfIncome = 60, -- selling a catch pays this many seconds of its income
    IncomeTickSeconds = 1,

    -- Offline earnings
    OfflineRate = 0.5,
    OfflineCapSeconds = 8 * 3600,
    OfflineCapSecondsVIP = 12 * 3600,
    OfflineMinSecondsToShow = 60,

    -- Exclusive dino: earns this multiple of the best other dino's income
    ExclusiveDinoMultiplier = 10,

    -- Server
    MaxPlayers = 8,
    PlotCount = 8,
}
