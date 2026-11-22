--[[
    ProfileConfig
    -------------
    ProfileStore settings and the saved-data template used by BCDK SMProfile.
    Every key in ProfileTemplate is created for new players and reconciled
    into existing profiles. Bump SchemaVersion and add a migration in
    PlayerDataServer when a key's meaning changes.

    Cash is added by SMCurrency from CurrencyConfig.
]]

return {
    StoreName = "SlingshotForDinosaurs_Store",
    Prefix = "P_",
    SchemaVersion = 1,
    ProfileTemplate = {
        SchemaVersion = 1,
        Power = 10,
        Slingshot = "Twig",
        Bait = "Berries",
        SlotTier = 1,
        Dinos = {}, -- array of { Id, Species, Size, Mutation, CaughtAt }
        NextDinoId = 1,
        ExclusiveDino = false,
        Index = {}, -- ["Species:Mutation"] = true
        BestDistance = 0,
        TotalLaunches = 0,
        BiomesReached = {}, -- [BiomeId] = true
        FTUEStep = 0,
        LastOnline = 0,
        PendingOffline = 0,
        Rerolls = 0,
        Passes = {}, -- refreshed from Roblox each join
        PurchaseIds = {}, -- [PurchaseId] = unix time, receipt idempotency
        StarterPackBought = false,
        Settings = { AutoReplace = false, AutoLaunch = false },
    },
}
