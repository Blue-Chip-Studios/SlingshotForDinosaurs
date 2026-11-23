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
        Perfect = { Window = 0.15, Bonus = 0.35 },
        Good = { Window = 0.30, Bonus = 0.20 },
        OK = { Window = 0.45, Bonus = 0.10 },
        MinGap = 1.0, -- seconds between geysers (before bounce extensions; each bounce adds BounceExtraTime), so each tap is readable
        ApproachTime = 0.9, -- the TAP ring starts shrinking this long before the perfect moment (shorter than MinGap: one ring at a time)
        ThreeBounceStuds = 700, -- flights this long get three geysers...
        ThreeBounceMinTime = 3.4, -- ...and last at least this long so all three fit MinGap apart
        EarlyMissFrom = 0.75, -- a tap this far (or less) early but outside OK burns the window
        AfterBounceGrace = 0.35, -- taps this soon after a successful bounce are ignored (double-click safety)
        LuckPerBounce = 0.10,
        ServerClockTolerance = 0.35, -- allowed gap between client-reported and server-measured time
        MaxWindowFraction = 0.85, -- no geysers in the last 15% of a flight
    },

    -- Running (SprintController): Shift, a full stick push, or the left-stick click
    Sprint = {
        Walk = 16,
        Run = 28,
        Ease = 8,        -- how quickly speed changes (higher = snappier)
        TiltDelay = 0.5, -- seconds of full stick push before an analogue run kicks in
    },

    -- Training
    TrainTickSeconds = 1.0, -- passive gain interval while standing on a pad
    TrainTapMaxPerSecond = 5, -- extra tap trains per second (server rate limit)
    TrainTapFraction = 0.2, -- each tap gives this share of a pad tick (tapping speeds training up, never dominates it)

    -- Enclosure
    SellSecondsOfIncome = 60, -- selling a catch pays this many seconds of its income
    IncomeTickSeconds = 1,

    -- Offline earnings
    OfflineRate = 0.25, -- offline earns a quarter rate: a welcome-back boost, not a skip
    OfflineCapSeconds = 4 * 3600,
    OfflineCapSecondsVIP = 8 * 3600,
    OfflineMinSecondsToShow = 60,

    -- Landing deeper into an area (towards the next gate) raises catch luck by up to this much,
    -- so extra distance always helps, even past the last gate.
    DepthLuckBonus = 0.6,

    -- Exclusive dino: earns this multiple of the best other dino's income
    ExclusiveDinoMultiplier = 10,

    -- Server
    MaxPlayers = 8,
    PlotCount = 8,
}
