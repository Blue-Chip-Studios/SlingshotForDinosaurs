--!strict
--[[
    Format
    ------
    Number and time formatting shared by UI and server messages.
]]

local Format = {}

local tSuffixes = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx" }

-- 1234 -> "1.23K", 12345678 -> "12.3M". Below 1,000 shows whole numbers.
function Format.Number(n: number): string
    if n ~= n then
        return "0"
    end
    local bNegative = n < 0
    n = math.abs(n)
    if n < 1000 then
        local s = tostring(math.floor(n))
        return if bNegative then "-" .. s else s
    end
    local iTier = math.min(math.floor(math.log10(n) / 3), #tSuffixes - 1)
    local nScaled = n / 10 ^ (iTier * 3)
    local sNumber
    if nScaled >= 100 then
        sNumber = string.format("%d", math.floor(nScaled))
    elseif nScaled >= 10 then
        sNumber = string.format("%.1f", math.floor(nScaled * 10) / 10)
    else
        sNumber = string.format("%.2f", math.floor(nScaled * 100) / 100)
    end
    -- Trim trailing zeros only after a decimal point ("1.50" -> "1.5", "2.00" -> "2"), never "500" -> "5".
    if sNumber:find("%.") then
        sNumber = (sNumber:gsub("0+$", ""):gsub("%.$", ""))
    end
    return (if bNegative then "-" else "") .. sNumber .. tSuffixes[iTier + 1]
end

function Format.Cash(n: number): string
    return "$" .. Format.Number(n)
end

function Format.Meters(n: number): string
    return Format.Number(n) .. " m"
end

-- 3725 -> "1h 2m", 125 -> "2m 5s", 9 -> "9s"
function Format.Duration(nSeconds: number): string
    nSeconds = math.max(0, math.floor(nSeconds))
    local h = nSeconds // 3600
    local m = (nSeconds % 3600) // 60
    local s = nSeconds % 60
    if h > 0 then
        return string.format("%dh %dm", h, m)
    elseif m > 0 then
        return string.format("%dm %ds", m, s)
    end
    return string.format("%ds", s)
end

return Format
