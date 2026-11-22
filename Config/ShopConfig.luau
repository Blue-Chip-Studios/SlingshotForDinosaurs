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

    Slingshots = {
        { Id = "Twig", Name = "Twig Slingshot", Multiplier = 3, Price = 0 },
        { Id = "Bamboo", Name = "Bamboo Slingshot", Multiplier = 8, Price = 150, ProductKey = "Slingshot_Bamboo" },
        { Id = "Bone", Name = "Bone Slingshot", Multiplier = 20, Price = 2500, ProductKey = "Slingshot_Bone" },
        { Id = "TarRubber", Name = "Tar-Rubber Slingshot", Multiplier = 50, Price = 40000, ProductKey = "Slingshot_TarRubber" },
        { Id = "MammothTusk", Name = "Mammoth Tusk Slingshot", Multiplier = 140, Price = 600000, ProductKey = "Slingshot_MammothTusk" },
        { Id = "Obsidian", Name = "Obsidian Slingshot", Multiplier = 400, Price = 9000000, ProductKey = "Slingshot_Obsidian" },
        { Id = "Meteorite", Name = "Meteorite Slingshot", Multiplier = 1200, Price = 150000000, ProductKey = "Slingshot_Meteorite" },
    },

    Bait = {
        { Id = "Berries", Name = "Berries", Luck = 1.0, Price = 0, Color = Color3.fromHex("C2185B") },
        { Id = "Fish", Name = "Fish", Luck = 1.5, Price = 500, ProductKey = "Bait_Fish", Color = Color3.fromHex("4FC3F7") },
        { Id = "Steak", Name = "Raw Steak", Luck = 2.5, Price = 8000, ProductKey = "Bait_Steak", Color = Color3.fromHex("E53935") },
        { Id = "GoldenEgg", Name = "Golden Egg", Luck = 4, Price = 120000, ProductKey = "Bait_GoldenEgg", Color = Color3.fromHex("FFC531") },
        { Id = "AmberMosquito", Name = "Amber Mosquito", Luck = 7, Price = 2000000, ProductKey = "Bait_AmberMosquito", Color = Color3.fromHex("FF9800") },
        { Id = "MeteorMeat", Name = "Meteor Meat", Luck = 12, Price = 40000000, ProductKey = "Bait_MeteorMeat", Color = Color3.fromHex("8E44FF") },
    },

    Slots = {
        { Slots = 6, Price = 0 },
        { Slots = 8, Price = 1000 },
        { Slots = 10, Price = 25000 },
        { Slots = 12, Price = 500000 },
        { Slots = 15, Price = 10000000 },
        { Slots = 18, Price = 250000000 },
    },
    VIPExtraSlots = 4,

    Pads = {
        { Id = "Pebble", Name = "Pebble Pad", RequiredPower = 0, PowerPerTick = 1, Color = Color3.fromHex("B0BEC5") },
        { Id = "Boulder", Name = "Boulder Pad", RequiredPower = 500, PowerPerTick = 5, Color = Color3.fromHex("8D6E63") },
        { Id = "Fossil", Name = "Fossil Pad", RequiredPower = 10000, PowerPerTick = 40, Color = Color3.fromHex("FFD54F") },
        { Id = "Lava", Name = "Lava Pad", RequiredPower = 250000, PowerPerTick = 400, Color = Color3.fromHex("FF6A1A") },
    },
}
