--[[
    CurrencyConfig
    --------------
    Currencies handled by BCDK SMCurrency / LMCurrency.
]]

local eCurrency = {
    Cash = 1,
}

return {
    eCurrency = eCurrency,
    eCurrencyProfiles = {
        [eCurrency.Cash] = { sKey = "Cash", nDefaultAmount = 0, sName = "Cash" },
    },
}
