--!strict
--[[
    ShopConfig
    ----------
    Upgrade tracks. Each track has exactly one job:
        Slingshots = distance multiplier
        Bait       = luck multiplier
        Slots      = enclosure capacity
        Pads       = training power per tick (unlocked by Power, free)
    Robux = developer product price for the skip; the shop only offers a
    Robux skip for the next RobuxSkipAhead tiers. ProductKey names a
    MonetizationConfig product.
]]

return {
    RobuxSkipAhead = 2,

    -- Slingshots step ~1.3x each so every tier reaches about one more area (never skipping several).
    -- Prices are ~10-15 minutes of income at the area where that tier is needed (progression simulator).
    Slingshots = {
        { Id = "Twig", Name = "Twig Slingshot", Multiplier = 3, Price = 0 },
        { Id = "Bamboo", Name = "Bamboo Slingshot", Multiplier = 4, Price = 250, ProductKey = "Slingshot_Bamboo" },
        { Id = "Bone", Name = "Bone Slingshot", Multiplier = 5, Price = 4000, ProductKey = "Slingshot_Bone" },
        { Id = "TarRubber", Name = "Tar-Rubber Slingshot", Multiplier = 6.5, Price = 50000, ProductKey = "Slingshot_TarRubber" },
        { Id = "MammothTusk", Name = "Mammoth Tusk Slingshot", Multiplier = 8.5, Price = 800000, ProductKey = "Slingshot_MammothTusk" },
        { Id = "Obsidian", Name = "Obsidian Slingshot", Multiplier = 11, Price = 12000000, ProductKey = "Slingshot_Obsidian" },
        { Id = "Meteorite", Name = "Meteorite Slingshot", Multiplier = 14, Price = 200000000, ProductKey = "Slingshot_Meteorite" },
        { Id = "Crystal", Name = "Crystal Slingshot", Multiplier = 18, Price = 4000000000, ProductKey = "Slingshot_Crystal" },
        { Id = "Celestial", Name = "Celestial Slingshot", Multiplier = 23, Price = 80000000000, ProductKey = "Slingshot_Celestial" },
    },

    Bait = {
        { Id = "Berries", Name = "Berries", Luck = 1.0, Price = 0, Color = Color3.fromHex("C2185B") },
        { Id = "Fish", Name = "Fish", Luck = 1.5, Price = 1500, ProductKey = "Bait_Fish", Color = Color3.fromHex("4FC3F7") },
        { Id = "Steak", Name = "Raw Steak", Luck = 2.5, Price = 30000, ProductKey = "Bait_Steak", Color = Color3.fromHex("E53935") },
        { Id = "GoldenEgg", Name = "Golden Egg", Luck = 4, Price = 600000, ProductKey = "Bait_GoldenEgg", Color = Color3.fromHex("FFC531") },
        { Id = "AmberMosquito", Name = "Amber Mosquito", Luck = 7, Price = 15000000, ProductKey = "Bait_AmberMosquito", Color = Color3.fromHex("FF9800") },
        { Id = "MeteorMeat", Name = "Meteor Meat", Luck = 12, Price = 500000000, ProductKey = "Bait_MeteorMeat", Color = Color3.fromHex("8E44FF") },
    },

    Slots = {
        { Slots = 6, Price = 0 },
        { Slots = 8, Price = 2500 },
        { Slots = 10, Price = 60000 },
        { Slots = 12, Price = 2000000 },
        { Slots = 15, Price = 60000000 },
        { Slots = 18, Price = 2000000000 },
    },
    VIPExtraSlots = 4,

    -- Power per tick while standing on a pad (taps add GameConfig.TrainTapFraction of this each).
    -- Power is the main gate all game: each area needs ~2.5x the previous Power.
    Pads = {
        { Id = "Pebble", Name = "Pebble Pad", RequiredPower = 0, PowerPerTick = 1, Color = Color3.fromHex("B0BEC5") },
        { Id = "Boulder", Name = "Boulder Pad", RequiredPower = 250, PowerPerTick = 3, Color = Color3.fromHex("8D6E63") },
        { Id = "Fossil", Name = "Fossil Pad", RequiredPower = 3000, PowerPerTick = 8, Color = Color3.fromHex("FFD54F") },
        { Id = "Lava", Name = "Lava Pad", RequiredPower = 18000, PowerPerTick = 20, Color = Color3.fromHex("FF6A1A") },
        { Id = "Crystal", Name = "Crystal Pad", RequiredPower = 75000, PowerPerTick = 50, Color = Color3.fromHex("C27BFF") },
    },
}
