--!strict
--[[
    PetConfig
    ---------
    Buyable baby-dino pets: a plush mini dino that follows its owner and gives one perk.
    Owned pets are saved (Pets = { [Id] = true }); one is equipped at a time (EquippedPet).

    Price.Cash pets are bought in the shop. Price.Robux pets use a developer product
    (MonetizationConfig.Products[ProductKey]); Id = 0 there means "not created on Roblox
    yet" (hidden live, simulated in Studio).

    Perks multiply one stat while the pet is equipped:
        Cash  = enclosure income (online and offline)
        Power = Power from training
        Luck  = catch luck (rarer species, sizes, mutations)
]]

export type Pet = {
    Id: string, Name: string, Species: string, Mutation: string?, Rarity: string,
    Perk: string, Bonus: number, Price: { Cash: number?, Robux: number? }, ProductKey: string?,
    Scale: number?, Flies: boolean?,
}

local PetConfig = {}

PetConfig.Rarities = {
    Common = { Order = 1, Color = Color3.fromHex("B0BEC5") },
    Rare = { Order = 2, Color = Color3.fromHex("4FC3F7") },
    Epic = { Order = 3, Color = Color3.fromHex("B97CFF") },
    Legendary = { Order = 4, Color = Color3.fromHex("FFC531") },
    Mythic = { Order = 5, Color = Color3.fromHex("FF5EDB") },
}

PetConfig.Perks = {
    Cash = { Label = "Cash", Icon = "Icon_Cash" },
    Power = { Label = "Power", Icon = "Icon_Power" },
    Luck = { Label = "Luck", Icon = "Icon_Star" },
}

-- Cash prices sit beside the matching slingshot tiers so each pet is a real goal at its stage.
PetConfig.List = {
    { Id = "BabyCompy", Name = "Baby Compy", Species = "Compy", Rarity = "Common", Perk = "Cash", Bonus = 0.05, Price = { Cash = 2500 } },
    { Id = "BabyProto", Name = "Baby Protoceratops", Species = "Protoceratops", Rarity = "Common", Perk = "Power", Bonus = 0.05, Price = { Cash = 4000 } },
    { Id = "BabyTrike", Name = "Baby Triceratops", Species = "Triceratops", Rarity = "Rare", Perk = "Cash", Bonus = 0.10, Price = { Cash = 250000 } },
    { Id = "BabyStego", Name = "Baby Stegosaurus", Species = "Stegosaurus", Rarity = "Rare", Perk = "Power", Bonus = 0.10, Price = { Cash = 400000 } },
    { Id = "BabySpino", Name = "Baby Spinosaurus", Species = "Spinosaurus", Rarity = "Epic", Perk = "Luck", Bonus = 0.15, Price = { Cash = 25000000 } },
    { Id = "BabyBrachio", Name = "Baby Brachiosaurus", Species = "Brachiosaurus", Rarity = "Epic", Perk = "Cash", Bonus = 0.20, Price = { Cash = 40000000 } },
    { Id = "BabyRex", Name = "Baby T-Rex", Species = "TRex", Rarity = "Legendary", Perk = "Cash", Bonus = 0.30, Price = { Cash = 3000000000 } },
    { Id = "GoldenRex", Name = "Golden Baby Rex", Species = "TRex", Mutation = "Golden", Rarity = "Mythic", Perk = "Cash", Bonus = 0.50, Price = { Robux = 399 }, ProductKey = "Pet_GoldenRex" },
    { Id = "CosmicPtero", Name = "Cosmic Pterodactyl", Species = "Pteranodon", Mutation = "Cosmic", Rarity = "Mythic", Perk = "Luck", Bonus = 0.25, Price = { Robux = 299 }, ProductKey = "Pet_CosmicPtero", Flies = true },
} :: { Pet }

local tById: { [string]: Pet } = {}
for _, t in PetConfig.List do
    tById[t.Id] = t
end

function PetConfig.Get(sId: string?): Pet?
    return if sId then tById[sId] else nil
end

-- Multiplier for one perk from the equipped pet (1 when none or a different perk).
function PetConfig.Multiplier(sEquipped: string?, sPerk: string): number
    local t = PetConfig.Get(sEquipped)
    if t and t.Perk == sPerk then
        return 1 + t.Bonus
    end
    return 1
end

return PetConfig
