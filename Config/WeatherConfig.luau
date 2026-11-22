--!strict
--[[
    WeatherConfig
    -------------
    20-minute world cycle: CycleSeconds long, the event fills the last
    EventSeconds. Event types alternate by cycle index. Mutation multipliers
    are applied to the base chance before luck.
]]

return {
    CycleSeconds = 20 * 60,
    EventSeconds = 5 * 60,
    Order = { "MeteorStorm", "IceAge" },
    PurchasedStormSeconds = 5 * 60,

    Events = {
        MeteorStorm = {
            Name = "Meteor Storm",
            MutationMultipliers = { Golden = 3, Frost = 3, Magma = 5, Toxic = 3, Cosmic = 5 },
            SizeLuck = 1,
        },
        IceAge = {
            Name = "Ice Age",
            MutationMultipliers = { Frost = 6 },
            SizeLuck = 2,
        },
    },
}
