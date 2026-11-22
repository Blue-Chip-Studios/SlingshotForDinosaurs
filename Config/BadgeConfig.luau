--[[
    BadgeConfig
    -----------
    Badges and when they're earned. Id = 0 means not created on Roblox yet
    (BadgeServer skips it). Assets/Blender/scripts/create_badges.sh creates
    the missing ones through Open Cloud (free daily quota only, never spends
    Robux) and prints the ids to paste here. Icon = file in Assets/Exports/Icons.
]]

return {
    FirstCatch = { Id = 0, Name = "First Catch!", Description = "Caught your very first dinosaur.", Icon = "Compy" },
    FirstMutation = { Id = 0, Name = "Mutant Hunter", Description = "Caught a mutated dinosaur.", Icon = "Icon_Star" },
    Biome_Swamp = { Id = 0, Name = "Into the Swamp", Description = "Launched bait all the way to the Swamp.", Icon = "Spinosaurus" },
    Biome_TarPits = { Id = 0, Name = "Tar Pit Explorer", Description = "Reached the Tar Pits.", Icon = "Triceratops" },
    Biome_IceAge = { Id = 0, Name = "Ice Age Survivor", Description = "Reached the frozen Ice Age.", Icon = "Brachiosaurus" },
    Biome_Volcano = { Id = 0, Name = "Volcano Conqueror", Description = "Reached the Volcano, the end of the canyon!", Icon = "TRex" },
    Legendary = { Id = 0, Name = "Legendary Catch", Description = "Caught a Legendary dinosaur.", Icon = "Parasaurolophus" },
    Colossal = { Id = 0, Name = "Colossal!", Description = "Caught a Colossal-size dinosaur.", Icon = "Giganotosaurus" },
    Cosmic = { Id = 0, Name = "Cosmic Discovery", Description = "Caught a Cosmic dinosaur, the rarest mutation.", Icon = "Icon_Meteor" },
    Rebirth = { Id = 0, Name = "Reborn", Description = "Rebirthed for the first time.", Icon = "Icon_Power" },
}
