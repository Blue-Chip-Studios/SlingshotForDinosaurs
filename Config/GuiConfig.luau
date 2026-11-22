--[[
    GuiConfig
    ---------
    What LMGui mounts on startup and the shared Fusion Store values every
    screen can read (Store.Values.<Name>).

        ConstantGuis: screens auto-mounted on client start (props table).
        Values:       initial seeds for Store.Values.
        GuiFolder:    where LMGui finds screen modules (ReplicatedStorage.Gui).

    Saved player data (Cash, Power, Dinos, ...) is mirrored into the Store by
    DataClient; gameplay controllers write the transient UI state below.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Screens auto-mounted on client start: [sGuiName] = tProps
local tConstantGuis = {
    HUD = {},
    LaunchOverlay = {},
    Popups = {},
    Modals = {},
}

local tValues = {
    -- Mirrored from the PlayerData / Currency replicas
    Cash = 0,
    Power = 10,
    Slingshot = "Twig",
    Bait = "Berries",
    SlotTier = 1,
    Dinos = {},
    Index = {},
    BestDistance = 0,
    TotalLaunches = 0,
    FTUEStep = 0,
    PendingOffline = 0,
    Rerolls = 0,
    Passes = {},
    Settings = {},
    ExclusiveDino = false,
    StarterPackBought = false,
    DailyStreak = 0,
    LastDailyDay = 0,
    QuestDay = 0,
    QuestProgress = {},
    QuestClaimed = {},
    WeeklyProgress = 0,
    WeeklyClaimed = false,
    Rebirths = 0,
    LuckBoostMult = 1,
    LuckBoostEndsAt = 0,
    PerfectStreak = 0,
    ExclusiveDinos = {},
    GiftedPasses = {},
    GiftPass = "", -- pass key chosen in the Gift picker
    DataLoaded = false,

    -- Player attributes
    Income = 0,
    OnPad = 0,
    IsAdmin = false,
    FriendsHere = 0,
    GroupMember = false,

    -- Navigation
    Modal = "", -- "" | "Shop" | "Index" | "Passes" | "Offer" | "Admin" | "Reroll"
    ShopTab = "Slingshot", -- "Slingshot" | "Bait" | "Slots"
    ShopFocus = 0, -- tier to scroll to when opened from a pedestal

    -- Launch
    Charging = false,
    Charge = 0,
    Flying = false,
    PopupOpen = false, -- Welcome Back popup showing (blocks the HOLD button underneath)
    BounceWindowOpen = false,
    BounceFeedback = "", -- "Perfect" | "Good" | "OK" | "Miss" | ""
    LiveMeters = 0,
    LaunchHint = "",

    -- Popups
    Reveal = false, -- CatchResult payload while the reveal card is up
    Full = false, -- EnclosureFull payload while the choice is up
    Announcements = {}, -- queue of { Id, Text, Kind, Mutation }
    Toast = "",

    -- World / FTUE
    Hint = "",
    Weather = "Clear",
    WeatherEndsAt = 0,
    NextWeather = "MeteorStorm",
    NextWeatherAt = 0,
    ServerLuck = 1,
    ServerLuckEndsAt = 0,
    Now = 0, -- server time, ticked every 0.25s for countdowns
}

-- Add a typed field here for each entry in tValues.
export type Values = { [string]: any }

return {
    ConstantGuis = tConstantGuis,
    Values = tValues,
    GuiFolder = ReplicatedStorage.Gui,
}
