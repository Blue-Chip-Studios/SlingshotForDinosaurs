--!strict
--[[
    QuestPicker
    -----------
    Deterministic daily quest selection (same answer on server and client):
    seeded by the player's UserId and the UTC day, so everyone gets a
    different but stable set that rolls over at midnight UTC.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RetentionConfig = require(ReplicatedStorage.Config.RetentionConfig)

local QuestPicker = {}

function QuestPicker.Today(): number
    -- Server-synced clock on both sides (a phone's own clock can be wrong).
    return math.floor(workspace:GetServerTimeNow() / 86400)
end

function QuestPicker.Week(): number
    return math.floor((QuestPicker.Today() + 3) / 7) -- weeks start Monday
end

-- Returns today's quest definitions for a user.
function QuestPicker.Daily(iUserId: number, iDay: number?): { any }
    local iSeed = (iUserId % 1000003) * 7919 + (iDay or QuestPicker.Today())
    local oRandom = Random.new(iSeed)
    local tPool = table.clone(RetentionConfig.QuestPool)
    local tOut = {}
    for _ = 1, math.min(RetentionConfig.DailyQuestCount, #tPool) do
        local i = oRandom:NextInteger(1, #tPool)
        table.insert(tOut, table.remove(tPool, i))
    end
    return tOut
end

return QuestPicker
