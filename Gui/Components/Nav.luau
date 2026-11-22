--[[
    Nav
    ---
    Opening/closing modals and the client-side calls screens make (purchase
    prompts, analytics). Keeps remote names out of individual screens.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remote = require(ReplicatedStorage.BCDKShared.Remote)
local Store = require(ReplicatedStorage.BCDKClient.LMGui.Store)
local SoundController = require(ReplicatedStorage.ClientModules.SoundController)

local Nav = {}

local tOpenEvents = {
    Shop = "ShopOpened",
    Index = "IndexOpened",
    Passes = "PassesOpened",
    Offer = "OfferOpened",
}

function Nav.Track(sName: string, sDetail: string?)
    Remote:GetEvent("AnalyticsUI"):FireServer({ Name = sName, Detail = sDetail })
end

function Nav.Open(sModal: string)
    Store.Values.Modal:set(sModal)
    SoundController:Play("Click")
    if tOpenEvents[sModal] then
        Nav.Track(tOpenEvents[sModal])
    end
end

function Nav.Close()
    Store.Values.Modal:set("")
    SoundController:Play("Click")
end

function Nav.PromptProduct(sKey: string)
    Nav.Track("ProductViewed", sKey)
    Remote:GetEvent("PromptPurchase"):FireServer({ Kind = "Product", Key = sKey })
end

function Nav.PromptPass(sKey: string)
    Nav.Track("ProductViewed", sKey)
    Remote:GetEvent("PromptPurchase"):FireServer({ Kind = "Pass", Key = sKey })
end

function Nav.BuyWithCash(sKind: string, iTier: number): (boolean, string?)
    local tResult = Remote:GetFunction("BuyWithCash"):InvokeServer({ Kind = sKind, Tier = iTier })
    if tResult and tResult.Ok then
        SoundController:Play("Coin")
        return true
    end
    SoundController:Play("Error")
    return false, tResult and tResult.Reason
end

function Nav.SetSetting(sKey: string, bValue: boolean)
    Remote:GetEvent("SetSetting"):FireServer({ Key = sKey, Value = bValue })
end

return Nav
