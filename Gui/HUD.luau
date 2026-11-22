--[[
    HUD
    ---
    Always-on screen (DesignSystem "Layout"): left menu stack, right offer
    column, currency pills bottom-left, event timer bottom-right, FTUE hint
    and best distance top-centre, and the contextual LAUNCH / TRAIN buttons
    bottom-centre. The centre of the screen stays clear for launching.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.fusion)
local Store = require(ReplicatedStorage.BCDKClient.LMGui.Store)
local Remote = require(ReplicatedStorage.BCDKShared.Remote)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Format = require(ReplicatedStorage.Shared.Format)
local ShopConfig = require(ReplicatedStorage.Config.ShopConfig)
local WeatherConfig = require(ReplicatedStorage.Config.WeatherConfig)
local UI = require(script.Parent.Components.UI)
local Nav = require(script.Parent.Components.Nav)
local LaunchController = require(ReplicatedStorage.ClientModules.LaunchController)

local Children = Fusion.Children
local V = Store.Values

local function NextAffordable(use): boolean
    local nCash = use(V.Cash)
    local function Check(tList, sCurrent)
        for i, t in tList do
            if t.Id == sCurrent then
                local tNext = tList[i + 1]
                return tNext ~= nil and nCash >= tNext.Price
            end
        end
        return false
    end
    local tNextSlot = ShopConfig.Slots[use(V.SlotTier) + 1]
    return Check(ShopConfig.Slingshots, use(V.Slingshot)) or Check(ShopConfig.Bait, use(V.Bait)) or (tNextSlot ~= nil and nCash >= tNextSlot.Price)
end

local function Pill(scope, props)
    return scope:New("Frame")({
        Name = props.Name,
        BackgroundColor3 = Theme.Ink,
        BackgroundTransparency = 0.25,
        Size = UDim2.fromOffset(300, 64),
        LayoutOrder = props.LayoutOrder,
        [Children] = {
            UI.Corner(scope, 999),
            UI.Icon(scope, { Key = props.Icon, Size = UDim2.fromOffset(60, 60), Position = UDim2.fromOffset(4, 2) }),
            UI.Text(scope, {
                Text = props.Text,
                TextSize = 44,
                Color = props.Color,
                XAlign = Enum.TextXAlignment.Left,
                Position = UDim2.fromOffset(66, 0),
                Size = UDim2.new(1, -120, 1, 0),
            }),
            props[Children],
        },
    })
end

return function(scope, props)
    local tTrainEvent = Remote:GetEvent("TrainTap")

    local bLaunchVisible = scope:Computed(function(use)
        return use(V.DataLoaded) and not use(V.Flying) and use(V.Modal) == "" and use(V.Reveal) == false and use(V.OnPad) == 0
    end)

    return UI.Screen(scope, {
        Name = "HUD",
        Parent = props.Parent,
        Enabled = scope:Computed(function(use)
            return not use(V.Flying)
        end),
        [Children] = UI.ScaledRoot(scope, {
            [Children] = {
                -- Left menu stack
                scope:New("Frame")({
                    Name = "LeftStack",
                    BackgroundTransparency = 1,
                    AnchorPoint = Vector2.new(0, 0.5),
                    Position = UDim2.new(0, 16, 0.45, 0),
                    Size = UDim2.fromOffset(220, 340),
                    [Children] = {
                        scope:New("UIListLayout")({ Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
                        UI.Button(scope, { Name = "Shop", Variant = "Green", IconKey = "Icon_Bag", Text = "Shop", Size = UDim2.fromOffset(210, 74), LayoutOrder = 1,
                            Badge = scope:Computed(NextAffordable), OnClick = function() Nav.Open("Shop") end }),
                        UI.Button(scope, { Name = "Index", Variant = "Blue", IconKey = "Icon_Book", Text = "Index", Size = UDim2.fromOffset(210, 74), LayoutOrder = 2,
                            OnClick = function() Nav.Open("Index") end }),
                        UI.Button(scope, { Name = "Passes", Variant = "Gold", IconKey = "Icon_Star", Text = "Passes", Size = UDim2.fromOffset(210, 74), LayoutOrder = 3,
                            OnClick = function() Nav.Open("Passes") end }),
                        UI.Button(scope, { Name = "Admin", Variant = "Purple", IconKey = "Icon_Wrench", IconSize = 44, Text = "Admin", Size = UDim2.fromOffset(210, 64), TextSize = 24, LayoutOrder = 4,
                            Visible = V.IsAdmin, OnClick = function() Nav.Open("Admin") end }),
                    },
                }),

                -- Right offer column
                scope:New("Frame")({
                    Name = "RightStack",
                    BackgroundTransparency = 1,
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -16, 0.45, 0),
                    Size = UDim2.fromOffset(96, 330),
                    [Children] = {
                        scope:New("UIListLayout")({ Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right }),
                        UI.Button(scope, { Name = "Offer", Variant = "Purple", IconKey = "Velociraptor", IconSize = 80, Size = UDim2.fromOffset(92, 92), LayoutOrder = 1,
                            Badge = scope:Computed(function(use) return not use(V.ExclusiveDino) end),
                            OnClick = function() Nav.Open("Offer") end }),
                        UI.Button(scope, { Name = "Storm", Variant = "Red", IconKey = "Icon_Meteor", IconSize = 76, Size = UDim2.fromOffset(92, 92), LayoutOrder = 2,
                            OnClick = function() Nav.PromptProduct("MeteorStorm") end }),
                        UI.Button(scope, { Name = "Reroll", Variant = "Blue", IconKey = "Icon_Potion", IconSize = 72, Size = UDim2.fromOffset(92, 92), LayoutOrder = 3,
                            OnClick = function() Nav.Open("Reroll") end,
                            [Children] = UI.Text(scope, {
                                Text = scope:Computed(function(use) return "x" .. use(V.Rerolls) end),
                                TextSize = 22, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 1, -8), Size = UDim2.fromOffset(40, 24), ZIndex = 4,
                            }) }),
                    },
                }),

                -- Currency pills (bottom-left)
                scope:New("Frame")({
                    Name = "Currencies",
                    BackgroundTransparency = 1,
                    AnchorPoint = Vector2.new(0, 1),
                    Position = UDim2.new(0, 16, 1, -16),
                    Size = UDim2.fromOffset(320, 200),
                    [Children] = {
                        scope:New("UIListLayout")({ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom }),
                        UI.Text(scope, {
                            Name = "Income",
                            Text = scope:Computed(function(use) return "+" .. Format.Cash(use(V.Income)) .. "/s" end),
                            TextSize = 28, Color = Theme.Cash, XAlign = Enum.TextXAlignment.Left,
                            Size = UDim2.fromOffset(300, 30), LayoutOrder = 1,
                        }),
                        Pill(scope, { Name = "Cash", Icon = "Icon_Cash", Color = Theme.Cash, LayoutOrder = 2,
                            Text = scope:Computed(function(use) return Format.Cash(use(V.Cash)) end),
                            [Children] = UI.Button(scope, { Name = "BuyCash", Variant = "Purple", Text = "+", TextSize = 34, Size = UDim2.fromOffset(52, 52),
                                AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), OnClick = function() Nav.Open("Offer") end }) }),
                        Pill(scope, { Name = "Power", Icon = "Icon_Power", Color = Theme.Power, LayoutOrder = 3,
                            Text = scope:Computed(function(use) return Format.Number(use(V.Power)) end) }),
                    },
                }),

                -- Event timer (bottom-right)
                scope:New("Frame")({
                    Name = "Weather",
                    BackgroundColor3 = Theme.Ink,
                    BackgroundTransparency = 0.3,
                    AnchorPoint = Vector2.new(1, 1),
                    -- On touch devices Roblox's jump button owns the bottom-right corner; sit above it.
                    Position = scope:Computed(function(use)
                        return if use(UI.IsTouch) then UI.TouchWeatherPosition else UDim2.new(1, -16, 1, -16)
                    end),
                    Size = UDim2.fromOffset(340, 96),
                    [Children] = {
                        UI.Corner(scope, 18),
                        UI.Text(scope, {
                            Text = scope:Computed(function(use)
                                local sWeather = use(V.Weather)
                                if sWeather ~= "Clear" then
                                    return "🔥 " .. WeatherConfig.Events[sWeather].Name .. "!"
                                end
                                return "☄️ " .. (WeatherConfig.Events[use(V.NextWeather)] or WeatherConfig.Events.MeteorStorm).Name
                            end),
                            TextSize = 30, Size = UDim2.new(1, -16, 0.5, 0), Position = UDim2.fromOffset(8, 4),
                        }),
                        UI.Text(scope, {
                            Text = scope:Computed(function(use)
                                local nNow = use(V.Now)
                                if use(V.Weather) ~= "Clear" then
                                    return "ends in " .. Format.Duration(use(V.WeatherEndsAt) - nNow)
                                end
                                return "in " .. Format.Duration(use(V.NextWeatherAt) - nNow)
                            end),
                            TextSize = 34, Color = Theme.Power, Size = UDim2.new(1, -16, 0.5, 0), Position = UDim2.new(0, 8, 0.5, -4),
                        }),
                    },
                }),

                -- Server luck banner
                UI.Chip(scope, {
                    Text = scope:Computed(function(use) return "🍀 SERVER LUCK x" .. use(V.ServerLuck) end),
                    Color = Theme.Variants.Green[2],
                    AnchorPoint = Vector2.new(0.5, 0),
                    Position = UDim2.new(0.5, 0, 0, 150),
                    Visible = scope:Computed(function(use) return use(V.ServerLuck) > 1 and use(V.ServerLuckEndsAt) > use(V.Now) end),
                }),

                -- Top centre: FTUE hint + best distance
                scope:New("Frame")({
                    Name = "Top",
                    BackgroundTransparency = 1,
                    AnchorPoint = Vector2.new(0.5, 0),
                    Position = UDim2.new(0.5, 0, 0, 12),
                    Size = UDim2.fromOffset(760, 130),
                    [Children] = {
                        scope:New("UIListLayout")({ Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
                        UI.Chip(scope, {
                            LayoutOrder = 1,
                            Color = Theme.Variants.Blue[2],
                            Text = scope:Computed(function(use) return "🏆 Best: " .. Format.Meters(use(V.BestDistance)) end),
                        }),
                        UI.Text(scope, {
                            LayoutOrder = 2,
                            Text = V.Hint,
                            TextSize = 40,
                            Size = UDim2.fromOffset(760, 50),
                            Color = Theme.Power,
                            StrokeThickness = 4,
                            Visible = scope:Computed(function(use) return use(V.Hint) ~= "" end),
                        }),
                    },
                }),

                -- LAUNCH (hold) button with charge bar
                scope:New("Frame")({
                    Name = "LaunchArea",
                    BackgroundTransparency = 1,
                    AnchorPoint = Vector2.new(0.5, 1),
                    Position = UDim2.new(0.5, 0, 1, -20),
                    Size = UDim2.fromOffset(300, 170),
                    Visible = bLaunchVisible,
                    [Children] = {
                        scope:New("Frame")({
                            Name = "ChargeBar",
                            BackgroundColor3 = Theme.Ink,
                            Size = UDim2.fromOffset(300, 30),
                            Visible = V.Charging,
                            [Children] = {
                                UI.Corner(scope, 999),
                                scope:New("Frame")({
                                    BackgroundColor3 = Color3.new(1, 1, 1),
                                    Position = UDim2.fromOffset(4, 4),
                                    Size = scope:Computed(function(use)
                                        return UDim2.new(use(V.Charge), -8 * use(V.Charge), 1, -8)
                                    end),
                                    [Children] = {
                                        UI.Corner(scope, 999),
                                        scope:New("UIGradient")({ Color = ColorSequence.new(Theme.Variants.Gold[1], Theme.Variants.Red[1]) }),
                                    },
                                }),
                            },
                        }),
                        UI.Button(scope, {
                            Name = "Launch",
                            Variant = "Orange",
                            IconKey = "Icon_Target", IconSize = 70,
                            Text = scope:Computed(function(use) return if use(V.Charging) then "LET GO!" else "HOLD" end),
                            TextSize = 44,
                            Size = UDim2.fromOffset(300, 120),
                            Position = UDim2.fromOffset(0, 40),
                            OnDown = function() LaunchController:BeginCharge() end,
                            OnUp = function() LaunchController:Release() end,
                        }),
                    },
                }),

                -- TRAIN (tap) when standing on a pad
                UI.Button(scope, {
                    Name = "Train",
                    Variant = "Gold",
                    IconKey = "Icon_Muscle", IconSize = 70,
                    Text = "TRAIN!",
                    TextSize = 44,
                    Size = UDim2.fromOffset(300, 120),
                    AnchorPoint = Vector2.new(0.5, 1),
                    Position = UDim2.new(0.5, 0, 1, -20),
                    Visible = scope:Computed(function(use) return use(V.OnPad) > 0 and use(V.Modal) == "" end),
                    OnClick = function() tTrainEvent:FireServer() end,
                }),
            },
        }),
    })
end
