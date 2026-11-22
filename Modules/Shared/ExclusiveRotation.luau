--!strict
--[[
    ExclusiveRotation
    -----------------
    Which limited exclusive dino is on sale right now (shared by server and
    client so the offer card, the receipt and the timer always agree).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MonetizationConfig = require(ReplicatedStorage.Config.MonetizationConfig)

local ExclusiveRotation = {}

local tCfg = MonetizationConfig.ExclusiveRotation

-- Returns the current entry and the unix time its window ends.
function ExclusiveRotation.Current(nNow: number?): ({ [string]: any }, number)
    local nTime = nNow or os.time()
    local nPeriod = tCfg.PeriodDays * 86400
    local iWindow = math.max(0, math.floor((nTime - tCfg.AnchorUnix) / nPeriod))
    local tEntry = tCfg.List[(iWindow % #tCfg.List) + 1]
    return tEntry, tCfg.AnchorUnix + (iWindow + 1) * nPeriod
end

function ExclusiveRotation.Get(sId: string): { [string]: any }?
    for _, t in tCfg.List do
        if t.Id == sId then
            return t
        end
    end
    return nil
end

return ExclusiveRotation
