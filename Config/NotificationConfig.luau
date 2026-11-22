--[[
    NotificationConfig
    ------------------
    Roblox Experience Notifications (13+ users who opted in).

    MessageIds come from Creator Dashboard > Engagement > Notifications (or the
    create-notification Open Cloud endpoint). Leave an id "" and that
    notification is simply not sent.

    Sending needs an Open Cloud API key with the "notifications"
    (user.user-notification:write) permission, stored as a Roblox Secret named
    SecretName (Creator Dashboard > Secrets). No secret = sending is disabled.
]]

return {
    SecretName = "NotificationsKey",
    UniverseId = 10778444607,

    -- Ask for opt-in once the player is invested (not on first join).
    PromptAfterLaunches = 10,

    Messages = {
        -- "🎁 {giver} gifted you the {pass} pass! Hop in to use it."
        GiftReceived = { MessageId = "", Params = { "giver", "pass" } },
    },
}
