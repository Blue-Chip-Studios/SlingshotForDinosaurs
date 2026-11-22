--!strict
--[[
    AnalyticsConfig
    ---------------
    Typed event catalogue. AnalyticsServer only logs names listed here, so
    a typo is caught (warned) instead of silently creating a new event.
]]

return {
    OnboardingSteps = {
        Joined = 1,
        FirstCharge = 2,
        FirstLaunch = 3,
        FirstBounce = 4,
        FirstCatch = 5,
        FirstPlacement = 6,
        FirstTrain = 7,
        FirstUpgrade = 8,
    },

    -- Custom events (LogCustomEvent)
    Custom = {
        Launch = true,
        Bounce = true,
        Catch = true,
        EnclosureFullChoice = true,
        WeatherEventStarted = true,
        AdminAction = true,
        WelcomeBackCollected = true,
        Reroll = true,
    },

    -- Client-reported UI events allowed through the UI remote
    ClientUI = {
        ShopOpened = true,
        IndexOpened = true,
        PassesOpened = true,
        OfferOpened = true,
        ProductViewed = true,
        ButtonClicked = true,
    },

    ClientUIMaxPerMinute = 40,
    IncomeBatchSeconds = 60, -- enclosure income economy events are batched
}
