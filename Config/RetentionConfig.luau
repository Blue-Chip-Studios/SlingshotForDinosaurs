--!strict
--[[
    RetentionConfig
    ---------------
    Live-tunable values for daily rewards, quests, promo codes, rebirth,
    the perfect-bounce streak, luck boosts and the Premium bonus.
    Reward kinds:
        Cash      Minutes = minutes of current income (Min = floor)
        Reroll    Amount
        Luck      Multiplier, Minutes (timed personal luck boost)
]]

return {
    -- 7-day login streak (resets if a day is missed). Day index = UTC day.
    Daily = {
        { Kind = "Cash", Minutes = 3, Min = 500, Label = "Cash" },
        { Kind = "Luck", Multiplier = 2, Minutes = 10, Label = "2x Luck" },
        { Kind = "Reroll", Amount = 1, Label = "Reroll" },
        { Kind = "Cash", Minutes = 8, Min = 2000, Label = "Cash" },
        { Kind = "Luck", Multiplier = 2, Minutes = 20, Label = "2x Luck" },
        { Kind = "Cash", Minutes = 15, Min = 5000, Label = "Big Cash" },
        { Kind = "Reroll", Amount = 2, Label = "2 Rerolls", Bonus = { Kind = "Luck", Multiplier = 5, Minutes = 10 } },
    },

    -- Daily quests: 3 picked per UTC day from the pool (seeded per player+day).
    DailyQuestCount = 3,
    QuestPool = {
        { Id = "Launch", Text = "Launch %d times", Goal = 15, Reward = { Kind = "Cash", Minutes = 4, Min = 800 } },
        { Id = "Perfect", Text = "Hit %d Perfect bounces", Goal = 6, Reward = { Kind = "Luck", Multiplier = 2, Minutes = 10 } },
        { Id = "Rare", Text = "Catch %d Rare or Legendary dinos", Goal = 4, Reward = { Kind = "Cash", Minutes = 6, Min = 1500 } },
        { Id = "Mutated", Text = "Catch %d mutated dinos", Goal = 2, Reward = { Kind = "Reroll", Amount = 1 } },
        { Id = "Train", Text = "Train %d times", Goal = 80, Reward = { Kind = "Cash", Minutes = 3, Min = 600 } },
        { Id = "Big", Text = "Catch %d Big or larger dinos", Goal = 5, Reward = { Kind = "Cash", Minutes = 5, Min = 1000 } },
    },
    -- One weekly quest (UTC week).
    WeeklyQuest = { Id = "WeeklyMutated", Track = "Mutated", Text = "Catch %d mutated dinos this week", Goal = 12, Reward = { Kind = "Reroll", Amount = 3 } },

    -- Promo codes: each redeemable once per player. Expires = unix seconds (0 = never).
    Codes = {
        LAUNCH = { Rewards = { { Kind = "Reroll", Amount = 1 }, { Kind = "Luck", Multiplier = 2, Minutes = 15 } }, Expires = 0 },
        DINOPARK = { Rewards = { { Kind = "Cash", Minutes = 10, Min = 2500 } }, Expires = 0 },
    },

    -- Rebirth: reset Cash, Power, Slingshot and Bait (dinos, Index and slots are kept)
    -- for a permanent multiplier on Power gain and launch distance.
    Rebirth = {
        RequiredMeters = 8000, -- must have reached the Ice Age
        BaseCost = 1000000,
        CostGrowth = 3, -- cost = BaseCost * CostGrowth^rebirths
        BonusPerRebirth = 0.25, -- +25% power gain and distance per rebirth
    },

    -- Consecutive Perfect bounces across launches add luck (reset on any non-Perfect bounce).
    PerfectStreak = { LuckPerStep = 0.05, MaxSteps = 10 },

    PremiumIncomeBonus = 0.10, -- Roblox Premium members earn +10%
}
