--[[
    LaunchOverlay
    -------------
    Shown only while the bait is flying: live distance + biome at the top,
    a full-screen tap catcher (tap ANYWHERE to bounce), the giant TAP!
    prompt during a bounce window, and PERFECT / GOOD / OK / MISS feedback.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.fusion)
local Store = require(ReplicatedStorage.BCDKClient.LMGui.Store)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Format = require(ReplicatedStorage.Shared.Format)
local DinoConfig = require(ReplicatedStorage.Config.DinoConfig)
local UI = require(script.Parent.Components.UI)
local LaunchController = require(ReplicatedStorage.ClientModules.LaunchController)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent
local V = Store.Values

local FEEDBACK = {
    Perfect = { "PERFECT!", Theme.Variants.Gold[1] },
    Good = { "GOOD!", Theme.Variants.Green[1] },
    OK = { "OK", Theme.Variants.Blue[1] },
    Miss = { "TOO EARLY!", Theme.Variants.Red[1] },
}

return function(scope, props)
    local nPulse = scope:Value(0)
    task.spawn(function()
        while true do
            nPulse:set(os.clock())
            task.wait(1 / 30)
        end
    end)

    return UI.Screen(scope, {
        Name = "LaunchOverlay",
        Parent = props.Parent,
        DisplayOrder = 5,
        IgnoreGuiInset = true,
        Enabled = V.Flying,
        [Children] = {
            -- Tap anywhere to bounce
            scope:New("TextButton")({
                Name = "TapCatcher",
                Text = "",
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                Selectable = false,
                [OnEvent("MouseButton1Down")] = function()
                    LaunchController:Tap()
                end,
            }),
            UI.ScaledRoot(scope, {
                [Children] = {
                    UI.Text(scope, {
                        Name = "Distance",
                        Text = scope:Computed(function(use) return Format.Meters(use(V.LiveMeters)) end),
                        TextSize = 72,
                        StrokeThickness = 5,
                        AnchorPoint = Vector2.new(0.5, 0),
                        Position = UDim2.new(0.5, 0, 0, 40),
                        Size = UDim2.fromOffset(600, 80),
                    }),
                    UI.Text(scope, {
                        Name = "Biome",
                        Text = scope:Computed(function(use) return DinoConfig.GetBiome(use(V.LiveMeters)).Name:upper() end),
                        Color = scope:Computed(function(use) return DinoConfig.GetBiome(use(V.LiveMeters)).Color:Lerp(Color3.new(1, 1, 1), 0.35) end),
                        TextSize = 40,
                        AnchorPoint = Vector2.new(0.5, 0),
                        Position = UDim2.new(0.5, 0, 0, 120),
                        Size = UDim2.fromOffset(600, 46),
                    }),
                    -- TAP! prompt with a pulsing ring
                    scope:New("Frame")({
                        Name = "TapPrompt",
                        BackgroundTransparency = 1,
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        Position = UDim2.fromScale(0.5, 0.62),
                        Size = UDim2.fromOffset(260, 260),
                        Visible = V.BounceWindowOpen,
                        [Children] = {
                            scope:New("Frame")({
                                Name = "Ring",
                                AnchorPoint = Vector2.new(0.5, 0.5),
                                Position = UDim2.fromScale(0.5, 0.5),
                                BackgroundTransparency = 1,
                                Size = scope:Computed(function(use)
                                    local n = 0.75 + 0.25 * math.abs(math.sin(use(nPulse) * 8))
                                    return UDim2.fromScale(n, n)
                                end),
                                [Children] = {
                                    UI.Corner(scope, 999),
                                    UI.Stroke(scope, 10, Theme.White),
                                },
                            }),
                            UI.Text(scope, { Text = "TAP!", TextSize = 96, StrokeThickness = 6, Color = Theme.Power }),
                        },
                    }),
                    UI.Text(scope, {
                        Name = "Feedback",
                        Text = scope:Computed(function(use)
                            local t = FEEDBACK[use(V.BounceFeedback)]
                            return t and t[1] or ""
                        end),
                        Color = scope:Computed(function(use)
                            local t = FEEDBACK[use(V.BounceFeedback)]
                            return t and t[2] or Theme.White
                        end),
                        TextSize = 84,
                        StrokeThickness = 6,
                        Rotation = -6,
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        Position = UDim2.fromScale(0.5, 0.38),
                        Size = UDim2.fromOffset(700, 100),
                    }),
                },
            }),
        },
    })
end
