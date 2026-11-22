--[[
    SocialConfig
    ------------
    Friends, community group and favourite prompt tuning.
]]

return {
    -- Playing with friends: +10% luck per friend in the server, up to 3 friends.
    FriendLuckPerFriend = 0.10,
    FriendLuckMaxFriends = 3,

    -- Community group (owns the game): members earn +10% income.
    GroupId = 144483796,
    GroupIncomeBonus = 0.10,
    GroupPromptAfterLaunches = 15, -- one automatic join prompt per player

    -- Favourite prompt: once, on the first mutated catch after this many launches.
    FavoritePromptAfterLaunches = 8,
}
