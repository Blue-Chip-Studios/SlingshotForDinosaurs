--!strict
--[[
    MonetizationConfig
    ------------------
    Gamepasses and developer products. Id = 0 means "not created on Roblox
    yet": the buy button is hidden in live servers, and in Studio a purchase
    is simulated so the grant path can be tested.
    Prices are the intended Robux prices (set on the Creator Dashboard /
    Open Cloud; the in-game label reads the live price when available).
]]

return {
    Passes = {
        DoubleCash = { Id = 2094102161, Price = 99, Name = "2x Cash", Description = "Doubles all enclosure income, online and offline." },
        DoublePower = { Id = 2096418101, Price = 149, Name = "2x Slingshot Power", Description = "Doubles Power from training." },
        AutoLaunch = { Id = 2092638260, Price = 199, Name = "Auto-Launch", Description = "Launches for you at full charge with Good bounces." },
        DoubleLuck = { Id = 2093460329, Price = 249, Name = "2x Luck", Description = "Doubles your luck: rarer species, bigger sizes and more mutations." },
        VIP = { Id = 2093292202, Price = 299, Name = "VIP Enclosure", Description = "+4 slots, golden fence, 12h offline cap, 1.25x income." },
    },

    Products = {
        MeteorStorm = { Id = 3734667473, Price = 149, Name = "Server Meteor Storm", Kind = "MeteorStorm" },
        Reroll1 = { Id = 3734667479, Price = 49, Name = "Mutation Reroll", Kind = "Reroll", Amount = 1 },
        Reroll3 = { Id = 3734667487, Price = 129, Name = "Mutation Reroll x3", Kind = "Reroll", Amount = 3 },
        ExclusiveDino = { Id = 3734667495, Price = 499, Name = "Celestial Raptor", Kind = "ExclusiveDino" },
        CashSmall = { Id = 3734667504, Price = 29, Name = "Cash Pouch", Kind = "Cash", Minutes = 10 },
        CashMedium = { Id = 3734667512, Price = 99, Name = "Cash Crate", Kind = "Cash", Minutes = 45 },
        CashLarge = { Id = 3734667525, Price = 249, Name = "Cash Vault", Kind = "Cash", Minutes = 150 },
        StarterPack = { Id = 3734667534, Price = 99, Name = "Starter Pack", Kind = "StarterPack", OneTime = true },
        LuckPotion = { Id = 3734723453, Price = 39, Name = "Luck Potion", Kind = "Luck", Multiplier = 2, Minutes = 15 },
        SuperLuckPotion = { Id = 3734723473, Price = 99, Name = "Super Luck Potion", Kind = "Luck", Multiplier = 5, Minutes = 15 },

        Slingshot_Bamboo = { Id = 3734667545, Price = 29, Name = "Bamboo Slingshot", Kind = "Slingshot", Item = "Bamboo" },
        Slingshot_Bone = { Id = 3734667556, Price = 49, Name = "Bone Slingshot", Kind = "Slingshot", Item = "Bone" },
        Slingshot_TarRubber = { Id = 3734667565, Price = 99, Name = "Tar-Rubber Slingshot", Kind = "Slingshot", Item = "TarRubber" },
        Slingshot_MammothTusk = { Id = 3734667575, Price = 199, Name = "Mammoth Tusk Slingshot", Kind = "Slingshot", Item = "MammothTusk" },
        Slingshot_Obsidian = { Id = 3734667581, Price = 399, Name = "Obsidian Slingshot", Kind = "Slingshot", Item = "Obsidian" },
        Slingshot_Meteorite = { Id = 3734667589, Price = 799, Name = "Meteorite Slingshot", Kind = "Slingshot", Item = "Meteorite" },

        Bait_Fish = { Id = 3734667597, Price = 29, Name = "Fish Bait", Kind = "Bait", Item = "Fish" },
        Bait_Steak = { Id = 3734667604, Price = 79, Name = "Raw Steak Bait", Kind = "Bait", Item = "Steak" },
        Bait_GoldenEgg = { Id = 3734667613, Price = 149, Name = "Golden Egg Bait", Kind = "Bait", Item = "GoldenEgg" },
        Bait_AmberMosquito = { Id = 3734667622, Price = 299, Name = "Amber Mosquito Bait", Kind = "Bait", Item = "AmberMosquito" },
        Bait_MeteorMeat = { Id = 3734667631, Price = 599, Name = "Meteor Meat Bait", Kind = "Bait", Item = "MeteorMeat" },
    },

    -- Exclusive dino shown in the offer slot while this window is open (unix seconds; 0 = always).
    ExclusiveDinoWindow = { StartsAt = 0, EndsAt = 0 },
    ExclusiveDino = { Species = "Velociraptor", Name = "Celestial Raptor", Mutation = "Cosmic", Size = "Huge" },
}
