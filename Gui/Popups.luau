--[[
    Popups
    ------
    Moment-to-moment cards:
      * Reveal: the catch card ("NEW!" sticker, species, size/mutation chips, $/s).
      * EnclosureFull: replace the weakest dino or sell the new one.
      * WelcomeBack: offline earnings to collect.
      * Announcements: top-centre toasts (rare catches, events, purchases).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.fusion)
local Store = require(ReplicatedStorage.BCDKClient.LMGui.Store)
local Remote = require(ReplicatedStorage.BCDKShared.Remote)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Format = require(ReplicatedStorage.Shared.Format)
local DinoConfig = require(ReplicatedStorage.Config.DinoConfig)
local UI = require(script.Parent.Components.UI)
local SoundController = require(ReplicatedStorage.ClientModules.SoundController)

local Children = Fusion.Children
local peek = Fusion.peek
local V = Store.Values

local function DinoName(t): string
    local tSize = DinoConfig.GetSize(t.Size)
    local tMut = DinoConfig.GetMutation(t.Mutation)
    return (if tSize.Default then "" else tSize.Name .. " ") .. (if tMut.Default then "" else tMut.Name .. " ") .. DinoConfig.Species[t.Species].Name
end

local function RevealCard(scope)
    local nOpen = scope:Spring(scope:Computed(function(use)
        return if use(V.Reveal) ~= false then 1 else 0.6
    end), 22, 0.55)
    local function Field(fn, vDefault)
        return scope:Computed(function(use)
            local t = use(V.Reveal)
            if t == false then return if typeof(vDefault) == "nil" then "" else vDefault end
            return fn(t)
        end)
    end
    return scope:New("Frame")({
        Name = "Reveal",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Visible = scope:Computed(function(use) return use(V.Reveal) ~= false end),
        [Children] = {
            scope:New("Frame")({
                Name = "Card",
                AnchorPoint = Vector2.new(0.5, 1),
                Position = UDim2.new(0.5, 0, 1, -24),
                Size = UDim2.fromOffset(560, 300),
                BackgroundColor3 = Theme.Panel,
                [Children] = {
                    scope:New("UIScale")({ Scale = nOpen }),
                    UI.Corner(scope, Theme.Radius.Modal),
                    UI.Stroke(scope, Theme.Stroke.Modal),
                    -- Blender portrait popping out of the card's top-left corner.
                    UI.Icon(scope, {
                        Key = Field(function(t) return t.Dino.Species end, ""),
                        AnchorPoint = Vector2.new(1, 1),
                        Position = UDim2.fromOffset(40, 40),
                        Size = UDim2.fromOffset(180, 180),
                        ZIndex = 4,
                    }),
                    -- "NEW!" sticker: orange tag with the label inside it (child renders above parent).
                    scope:New("Frame")({
                        Name = "Sticker",
                        BackgroundColor3 = Theme.Variants.Orange[1],
                        Rotation = -8,
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        Position = UDim2.new(1, -60, 0, 6),
                        Size = UDim2.fromOffset(170, 56),
                        ZIndex = 3,
                        [Children] = {
                            UI.Corner(scope, 14),
                            UI.Stroke(scope, 4),
                            UI.Text(scope, {
                                Text = Field(function(t) return if t.NewIndex then "NEW!" else "CAUGHT!" end),
                                TextSize = 40,
                                ZIndex = 3,
                            }),
                        },
                    }),
                    UI.Text(scope, {
                        Text = Field(function(t) return DinoName(t.Dino) end),
                        TextSize = 48,
                        StrokeThickness = 4,
                        TextScaled = true,
                        Color = Field(function(t)
                            return if t.Dino.Mutation == "Normal" then Theme.White else Theme.Mutation[t.Dino.Mutation]
                        end, Theme.White),
                        Position = UDim2.fromOffset(20, 20),
                        Size = UDim2.new(1, -40, 0, 60),
                    }),
                    scope:New("Frame")({
                        Name = "Chips",
                        BackgroundTransparency = 1,
                        Position = UDim2.fromOffset(20, 92),
                        Size = UDim2.new(1, -40, 0, 40),
                        [Children] = {
                            scope:New("UIListLayout")({ FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10) }),
                            UI.Chip(scope, { Text = Field(function(t) return DinoConfig.Species[t.Dino.Species].Rarity end),
                                Color = Field(function(t) return Theme.Rarity[DinoConfig.Species[t.Dino.Species].Rarity] end, Theme.White) }),
                            UI.Chip(scope, { Text = Field(function(t) return t.Dino.Size end), Color = Field(function(t) return Theme.Size[t.Dino.Size] end, Theme.White) }),
                            UI.Chip(scope, { Text = Field(function(t) return t.Dino.Mutation end), Color = Field(function(t) return Theme.Mutation[t.Dino.Mutation] end, Theme.White) }),
                        },
                    }),
                    UI.Text(scope, {
                        Text = Field(function(t) return "+" .. Format.Cash(t.Income) .. "/s" end),
                        TextSize = 52,
                        Color = Theme.Cash,
                        Position = UDim2.fromOffset(20, 140),
                        Size = UDim2.new(1, -40, 0, 56),
                    }),
                    UI.Text(scope, {
                        Text = Field(function(t)
                            local s = Format.Meters(t.Meters) .. " · " .. DinoConfig.GetBiome(t.Meters).Name
                            if t.NewBest then s ..= " · NEW BEST!" end
                            return s
                        end),
                        TextSize = 24,
                        Color = Theme.Ink,
                        NoStroke = true,
                        Position = UDim2.fromOffset(20, 194),
                        Size = UDim2.new(1, -40, 0, 26),
                    }),
                    UI.Button(scope, {
                        Name = "Awesome",
                        Variant = "Green",
                        Text = "AWESOME!",
                        TextSize = 34,
                        AnchorPoint = Vector2.new(0.5, 1),
                        Position = UDim2.new(0.5, 0, 1, -14),
                        Size = UDim2.fromOffset(280, 70),
                        OnClick = function()
                            V.Reveal:set(false)
                            SoundController:Play("Click")
                        end,
                    }),
                },
            }),
        },
    })
end

local function EnclosureFull(scope)
    local oResolve = Remote:GetEvent("ResolveFull")
    local function Field(fn)
        return scope:Computed(function(use)
            local t = use(V.Full)
            if t == false then return "" end
            return fn(t)
        end)
    end
    local function Choose(sChoice: string)
        oResolve:FireServer(sChoice)
        V.Full:set(false)
        SoundController:Play("Coin")
    end
    return scope:New("Frame")({
        Name = "Full",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Visible = scope:Computed(function(use) return use(V.Full) ~= false and use(V.Reveal) == false end),
        [Children] = {
            UI.Backdrop(scope, { OnClick = function() end }),
            UI.Modal(scope, {
                Title = "Park Full!",
                Variant = "Orange",
                Size = UDim2.fromOffset(720, 400),
                [Children] = {
                    UI.Text(scope, {
                        Text = Field(function(t) return "You caught a " .. DinoName(t.New) .. " (+" .. Format.Cash(DinoConfig.GetIncome(t.New)) .. "/s)" end),
                        TextSize = 30, Color = Theme.Ink, NoStroke = true, TextWrapped = true,
                        Size = UDim2.new(1, 0, 0, 80),
                    }),
                    UI.Button(scope, {
                        Variant = "Green",
                        Text = Field(function(t) return if t.Weakest then "Replace " .. DinoConfig.Species[t.Weakest.Species].Name else "Replace" end),
                        TextSize = 28,
                        Position = UDim2.fromOffset(0, 110),
                        Size = UDim2.new(0.5, -10, 0, 90),
                        OnClick = function() Choose("Replace") end,
                    }),
                    UI.Button(scope, {
                        Variant = "Orange",
                        Text = Field(function(t) return "Sell for " .. Format.Cash(t.SellValue) end),
                        TextSize = 28,
                        Position = UDim2.new(0.5, 10, 0, 110),
                        Size = UDim2.new(0.5, -10, 0, 90),
                        OnClick = function() Choose("Sell") end,
                    }),
                    UI.Text(scope, {
                        Text = "Tip: buy more slots in the Shop, or turn on Auto-Replace.",
                        TextSize = 22, Color = Theme.Ink, NoStroke = true, Font = Theme.Body,
                        Position = UDim2.fromOffset(0, 220), Size = UDim2.new(1, 0, 0, 30),
                    }),
                },
            }),
        },
    })
end

local function WelcomeBack(scope)
    local bDismissed = scope:Value(false)
    local oCollect = Remote:GetEvent("CollectOffline")
    return scope:New("Frame")({
        Name = "WelcomeBack",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Visible = scope:Computed(function(use)
            return use(V.PendingOffline) > 0 and not use(bDismissed) and not use(V.Flying)
        end),
        [Children] = {
            UI.Backdrop(scope, { OnClick = function() end }),
            UI.Modal(scope, {
                Title = "Welcome Back!",
                Variant = "Gold",
                Size = UDim2.fromOffset(620, 380),
                [Children] = {
                    UI.Text(scope, { Text = "Your dinos earned while you were away:", TextSize = 28, Color = Theme.Ink, NoStroke = true, Size = UDim2.new(1, 0, 0, 40) }),
                    UI.Text(scope, {
                        Text = scope:Computed(function(use) return Format.Cash(use(V.PendingOffline)) end),
                        TextSize = 80, Color = Theme.Cash, StrokeThickness = 5,
                        Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 100),
                    }),
                    UI.Button(scope, {
                        Name = "Collect",
                        Variant = "Green",
                        Icon = "💵",
                        Text = "COLLECT",
                        TextSize = 40,
                        AnchorPoint = Vector2.new(0.5, 1),
                        Position = UDim2.new(0.5, 0, 1, 0),
                        Size = UDim2.fromOffset(340, 90),
                        OnClick = function()
                            oCollect:FireServer()
                            bDismissed:set(true)
                            SoundController:Play("Coin")
                            task.delay(2, function() bDismissed:set(false) end)
                        end,
                    }),
                },
            }),
        },
    })
end

local function Announcements(scope)
    return scope:New("Frame")({
        Name = "Announcements",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 190),
        Size = UDim2.fromOffset(820, 200),
        [Children] = {
            scope:New("UIListLayout")({ Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
            scope:ForValues(V.Announcements, function(use, innerScope, t)
                local cColor = if t.Mutation and Theme.Mutation[t.Mutation] and t.Mutation ~= "Normal" then Theme.Mutation[t.Mutation]
                    elseif t.Kind == "Event" then Theme.Variants.Orange[1]
                    elseif t.Kind == "Toast" then Theme.Variants.Red[1]
                    else Theme.White
                return innerScope:New("Frame")({
                    BackgroundColor3 = Theme.Ink,
                    BackgroundTransparency = 0.25,
                    Size = UDim2.fromOffset(0, 50),
                    AutomaticSize = Enum.AutomaticSize.X,
                    LayoutOrder = t.Id,
                    [Children] = {
                        UI.Corner(innerScope, 999),
                        innerScope:New("UIPadding")({ PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20) }),
                        UI.Text(innerScope, { Text = t.Text, TextSize = 30, Color = cColor, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X }),
                    },
                })
            end),
        },
    })
end

return function(scope, props)
    -- EnclosureFull arrives from the server; show it once the reveal is closed.
    Remote:GetEvent("EnclosureFull"):OnClientEvent(function(t)
        V.Full:set(t)
    end)

    return UI.Screen(scope, {
        Name = "Popups",
        Parent = props.Parent,
        DisplayOrder = 10,
        [Children] = UI.ScaledRoot(scope, {
            [Children] = {
                Announcements(scope),
                WelcomeBack(scope),
                EnclosureFull(scope),
                RevealCard(scope),
            },
        }),
    })
end
