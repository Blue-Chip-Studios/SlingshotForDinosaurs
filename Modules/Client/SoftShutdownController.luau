--[[
    SoftShutdownController
    ----------------------
    Full-screen "updating" overlay while SoftShutdownServer moves players to an
    updated server, also used as the teleport loading screen and shown in the
    temporary holding server.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Module = require(ReplicatedStorage.Shared.Module)
local Remote = require(ReplicatedStorage.BCDKShared.Remote)
local Theme = require(ReplicatedStorage.Shared.Theme)

local oScreen: ScreenGui? = nil

local function Build(sText: string): ScreenGui
    local o = Instance.new("ScreenGui")
    o.Name = "SoftShutdown"
    o.IgnoreGuiInset = true
    o.DisplayOrder = 1000
    o.ResetOnSpawn = false
    local oBg = Instance.new("Frame")
    oBg.Size = UDim2.fromScale(1, 1)
    oBg.BackgroundColor3 = Color3.fromHex("1B1430")
    oBg.Parent = o
    local oGradient = Instance.new("UIGradient")
    oGradient.Color = ColorSequence.new(Color3.fromHex("3B1F6E"), Color3.fromHex("FF7A2F"))
    oGradient.Rotation = 90
    oGradient.Parent = oBg
    local oLabel = Instance.new("TextLabel")
    oLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    oLabel.Position = UDim2.fromScale(0.5, 0.5)
    oLabel.Size = UDim2.fromScale(0.8, 0.15)
    oLabel.BackgroundTransparency = 1
    oLabel.FontFace = Theme.Display
    oLabel.TextScaled = true
    oLabel.TextColor3 = Color3.new(1, 1, 1)
    oLabel.Text = "🦖 " .. sText
    local oStroke = Instance.new("UIStroke")
    oStroke.Thickness = 3
    oStroke.Color = Theme.Ink
    oStroke.Parent = oLabel
    oLabel.Parent = oBg
    return o
end

local function Show(sText: string)
    local oGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    if oScreen then oScreen:Destroy() end
    oScreen = Build(sText)
    oScreen.Parent = oGui
    -- Same screen during the teleport itself.
    pcall(TeleportService.SetTeleportGui, TeleportService, Build(sText))
end

local mSoftShutdown = Module()

function mSoftShutdown.PreloadAsync(self)
    if Workspace:GetAttribute("SoftShutdownLobby") then
        Show("Updating the game... back in a moment!")
    end
    Remote:GetEvent("ServerUpdating"):OnClientEvent(function(tPayload)
        Show(typeof(tPayload) == "table" and tostring(tPayload.Text) or "Updating...")
    end)
end

return mSoftShutdown
