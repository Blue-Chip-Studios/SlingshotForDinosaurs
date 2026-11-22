--[[
    Modals
    ------
    Every full-screen menu, one visible at a time (Store.Modal):
      Shop    slingshots / bait / slots with side-by-side Cash and Robux buttons
      Index   15 species x 6 mutations collection
      Passes  the four gamepasses + Auto-Launch / Auto-Replace toggles
      Offer   exclusive dino, starter pack, cash packs, reroll packs
      Reroll  pick a dino to reroll its mutation (odds shown first)
      Admin   developer-only live-event controls (server re-checks access)
    Gamepad B / Escape-style close is bound while a modal is open.
]]

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Fusion = require(ReplicatedStorage.Packages.fusion)
local Store = require(ReplicatedStorage.BCDKClient.LMGui.Store)
local Remote = require(ReplicatedStorage.BCDKShared.Remote)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Format = require(ReplicatedStorage.Shared.Format)
local DinoConfig = require(ReplicatedStorage.Config.DinoConfig)
local ShopConfig = require(ReplicatedStorage.Config.ShopConfig)
local MonetizationConfig = require(ReplicatedStorage.Config.MonetizationConfig)
local WeatherConfig = require(ReplicatedStorage.Config.WeatherConfig)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local UI = require(script.Parent.Components.UI)
local Nav = require(script.Parent.Components.Nav)
local SoundController = require(ReplicatedStorage.ClientModules.SoundController)

local Children, OnEvent, Out, peek = Fusion.Children, Fusion.OnEvent, Fusion.Out, Fusion.peek
local V = Store.Values

local IS_STUDIO = RunService:IsStudio()

-- A Robux item is purchasable if it exists on Roblox (Id ~= 0) or we're testing in Studio.
local function Purchasable(tItem): boolean
    return tItem ~= nil and (tItem.Id ~= 0 or IS_STUDIO)
end

local function Grid(scope, props)
    return scope:New("ScrollingFrame")({
        Name = props.Name or "Grid",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = props.Position,
        Size = props.Size or UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = props.Horizontal and Enum.AutomaticSize.X or Enum.AutomaticSize.Y,
        ScrollingDirection = props.Horizontal and Enum.ScrollingDirection.X or Enum.ScrollingDirection.Y,
        ScrollBarThickness = 8,
        ScrollBarImageColor3 = Theme.Ink,
        [Children] = {
            scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }),
            if props.Horizontal then scope:New("UIListLayout")({ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder })
            else scope:New("UIGridLayout")({ CellSize = props.CellSize or UDim2.fromOffset(250, 160), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
            props[Children],
        },
    })
end

local function Card(scope, props)
    return scope:New("Frame")({
        Name = props.Name or "Card",
        BackgroundColor3 = Color3.new(1, 1, 1),
        Size = props.Size or UDim2.fromOffset(250, 330),
        LayoutOrder = props.LayoutOrder,
        [Children] = {
            UI.Corner(scope, Theme.Radius.Card),
            scope:New("UIStroke")({ Thickness = props.Selected and scope:Computed(function(use) return if use(props.Selected) then 5 else 3 end) or 3,
                Color = props.Selected and scope:Computed(function(use) return if use(props.Selected) then Theme.Variants.Green[1] else Theme.Ink end) or Theme.Ink }),
            scope:New("UIGradient")({ Rotation = 90, Color = ColorSequence.new(Theme.Panel, Theme.PanelDeep) }),
            props[Children],
        },
    })
end

-- ===== Shop =====
local function TrackList(sKind: string)
    if sKind == "Slingshot" then return ShopConfig.Slingshots end
    if sKind == "Bait" then return ShopConfig.Bait end
    return nil
end

local function CurrentTier(use, sKind: string): number
    if sKind == "Slots" then return use(V.SlotTier) end
    local tList = TrackList(sKind) :: { any }
    local sId = use(if sKind == "Slingshot" then V.Slingshot else V.Bait)
    for i, t in tList do
        if t.Id == sId then return i end
    end
    return 1
end

local function ShopItemCard(scope, sKind: string, iTier: number, tItem)
    local bOwned = scope:Computed(function(use) return iTier <= CurrentTier(use, sKind) end)
    local bEquipped = scope:Computed(function(use) return iTier == CurrentTier(use, sKind) end)
    local bAfford = scope:Computed(function(use) return use(V.Cash) >= tItem.Price end)
    local bNextSlot = scope:Computed(function(use) return sKind ~= "Slots" or iTier == CurrentTier(use, "Slots") + 1 end)
    local tProduct = tItem.ProductKey and MonetizationConfig.Products[tItem.ProductKey]
    local bRobuxVisible = scope:Computed(function(use)
        local iCurrent = CurrentTier(use, sKind)
        return Purchasable(tProduct) and iTier > iCurrent and iTier <= iCurrent + ShopConfig.RobuxSkipAhead
    end)
    local sName = if sKind == "Slots" then `{tItem.Slots} Slots` else tItem.Name
    local sStat = if sKind == "Slingshot" then `{tItem.Multiplier}x Distance` elseif sKind == "Bait" then `{tItem.Luck}x Luck` else "Park capacity"
    local sIcon = if sKind == "Slingshot" then "🏹" elseif sKind == "Bait" then "🍖" else "🦕"
    return Card(scope, {
        Name = `Item{iTier}`,
        LayoutOrder = iTier,
        Selected = bEquipped,
        [Children] = {
            UI.Text(scope, { Text = sName, TextSize = 30, TextScaled = true, Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 40) }),
            UI.Text(scope, { Text = sStat, TextSize = 22, Color = Theme.Ink, NoStroke = true, Font = Theme.Body, Position = UDim2.fromOffset(10, 50), Size = UDim2.new(1, -20, 0, 26) }),
            if sKind == "Slots" then UI.Text(scope, { Text = sIcon, TextSize = 64, NoStroke = true, Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 0, 72) })
            else UI.Icon(scope, { Key = if sKind == "Bait" then "Bait_" .. tItem.Id else "SlingshotItem", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = UDim2.fromOffset(90, 84) }),
            UI.Chip(scope, { Text = `Tier {iTier}`, Color = Theme.Variants.Grey[1], AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 152), Height = 30, TextSize = 20 }),
            -- Cash button (state: Equipped / Owned / affordable / unaffordable)
            UI.Button(scope, {
                Name = "Cash",
                Variant = scope:Computed(function(use)
                    if use(bOwned) or not use(bNextSlot) then return "Grey" end
                    return if use(bAfford) then "Orange" else "Red"
                end),
                Text = scope:Computed(function(use)
                    if use(bEquipped) then return "EQUIPPED" end
                    if use(bOwned) then return "OWNED" end
                    if not use(bNextSlot) then return "LOCKED" end
                    return if tItem.Price == 0 then "FREE" else Format.Cash(tItem.Price)
                end),
                TextSize = 26,
                Position = UDim2.new(0, 10, 1, -126),
                Size = UDim2.new(1, -20, 0, 58),
                OnClick = function()
                    if peek(bOwned) or not peek(bNextSlot) then return end
                    local bOk, sReason = Nav.BuyWithCash(sKind, iTier)
                    if not bOk and sReason == "Cash" then
                        V.Toast:set("Not enough cash yet!")
                    end
                end,
            }),
            UI.Button(scope, {
                Name = "Robux",
                Variant = "Purple",
                Text = if tProduct then `R$ {tProduct.Price}` else "",
                TextSize = 24,
                Visible = bRobuxVisible,
                Position = UDim2.new(0, 10, 1, -64),
                Size = UDim2.new(1, -20, 0, 54),
                OnClick = function()
                    if tProduct then Nav.PromptProduct(tItem.ProductKey) end
                end,
            }),
        },
    })
end

local function Shop(scope)
    local tTabs = { { "Slingshot", "Slingshots", "Green" }, { "Bait", "Bait", "Orange" }, { "Slots", "Park Slots", "Blue" } }
    local tTabChildren = {}
    for i, t in tTabs do
        tTabChildren[i] = UI.Button(scope, {
            Name = t[1],
            Variant = scope:Computed(function(use) return if use(V.ShopTab) == t[1] then t[3] else "Grey" end),
            Text = t[2],
            TextSize = 26,
            Size = UDim2.fromOffset(210, 60),
            LayoutOrder = i,
            OnClick = function()
                V.ShopTab:set(t[1])
                SoundController:Play("Click")
            end,
        })
    end
    local function TabGrid(sKind: string)
        local tCards = {}
        local tList = TrackList(sKind) or ShopConfig.Slots
        for iTier, tItem in tList do
            tCards[iTier] = ShopItemCard(scope, sKind, iTier, tItem)
        end
        return Grid(scope, {
            Name = sKind .. "Grid",
            Horizontal = true,
            Position = UDim2.fromOffset(0, 76),
            Size = UDim2.new(1, 0, 1, -76),
            [Children] = tCards,
        })
    end
    local tGrids = {}
    for _, t in tTabs do
        local oGrid = TabGrid(t[1])
        oGrid.Visible = false
        table.insert(tGrids, oGrid)
        scope:Observer(V.ShopTab):onBind(function()
            oGrid.Visible = peek(V.ShopTab) == t[1]
        end)
    end
    return UI.Modal(scope, {
        Name = "Shop",
        Title = "🛒 Shop",
        Variant = "Green",
        Size = UDim2.fromOffset(1000, 600),
        OnClose = Nav.Close,
        [Children] = {
            scope:New("Frame")({
                Name = "Tabs",
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 66),
                [Children] = {
                    scope:New("UIListLayout")({ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
                    tTabChildren,
                },
            }),
            tGrids,
        },
    })
end

-- ===== Index =====
local function Index(scope)
    local tCards = {}
    local iOrder = 0
    for _, tBiome in DinoConfig.Biomes do
        for _, sSpecies in tBiome.Species do
            iOrder += 1
            local tSpecies = DinoConfig.Species[sSpecies]
            local tDots = {}
            for i, tMut in DinoConfig.Mutations do
                tDots[i] = scope:New("Frame")({
                    Size = UDim2.fromOffset(26, 26),
                    LayoutOrder = i,
                    BackgroundColor3 = scope:Computed(function(use)
                        return if use(V.Index)[`{sSpecies}:{tMut.Id}`] then Theme.Mutation[tMut.Id] else Theme.PanelDeep
                    end),
                    [Children] = { UI.Corner(scope, 13), UI.Stroke(scope, 2) },
                })
            end
            local bFound = scope:Computed(function(use)
                for _, tMut in DinoConfig.Mutations do
                    if use(V.Index)[`{sSpecies}:{tMut.Id}`] then return true end
                end
                return false
            end)
            tCards[iOrder] = Card(scope, {
                LayoutOrder = iOrder,
                [Children] = {
                    -- Portrait; undiscovered species show as a dark silhouette.
                    UI.Icon(scope, { Key = sSpecies, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 30), Size = UDim2.fromOffset(84, 84),
                        Tint = scope:Computed(function(use) return if use(bFound) then Color3.new(1, 1, 1) else Color3.fromHex("2A2638") end) }),
                    UI.Text(scope, {
                        Text = scope:Computed(function(use)
                            for _, tMut in DinoConfig.Mutations do
                                if use(V.Index)[`{sSpecies}:{tMut.Id}`] then return tSpecies.Name end
                            end
                            return "???"
                        end),
                        TextSize = 26, TextScaled = true, Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 34),
                    }),
                    UI.Text(scope, { Text = `{tBiome.Name} · {tSpecies.Rarity}`, TextSize = 18, Color = Theme.Ink, NoStroke = true, Font = Theme.Body,
                        Position = UDim2.fromOffset(8, 44), Size = UDim2.new(1, -100, 0, 22), XAlign = Enum.TextXAlignment.Left }),
                    UI.Text(scope, { Text = Format.Cash(tSpecies.Income) .. "/s base", TextSize = 22, Color = Theme.Cash, Position = UDim2.fromOffset(8, 72), Size = UDim2.new(1, -100, 0, 26), XAlign = Enum.TextXAlignment.Left }),
                    scope:New("Frame")({
                        BackgroundTransparency = 1,
                        Position = UDim2.new(0, 8, 1, -40),
                        Size = UDim2.new(1, -16, 0, 30),
                        [Children] = {
                            scope:New("UIListLayout")({ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
                            tDots,
                        },
                    }),
                },
            })
        end
    end
    return UI.Modal(scope, {
        Name = "Index",
        Title = scope:Computed(function(use)
            local n = 0
            for _ in use(V.Index) do n += 1 end
            return `📖 Dino Index  {n}/{15 * #DinoConfig.Mutations}`
        end),
        Variant = "Blue",
        Size = UDim2.fromOffset(1000, 600),
        OnClose = Nav.Close,
        [Children] = Grid(scope, { CellSize = UDim2.fromOffset(230, 150), [Children] = tCards }),
    })
end

-- ===== Passes =====
local function Toggle(scope, sKey: string, sLabel: string, bNeedsPass: string?)
    local bOn = scope:Computed(function(use) return (use(V.Settings) or {})[sKey] == true end)
    return UI.Button(scope, {
        Variant = scope:Computed(function(use) return if use(bOn) then "Green" else "Grey" end),
        Text = scope:Computed(function(use) return sLabel .. (if use(bOn) then ": ON" else ": OFF") end),
        TextSize = 24,
        Size = UDim2.fromOffset(300, 60),
        Visible = if bNeedsPass then scope:Computed(function(use) return (use(V.Passes) or {})[bNeedsPass] == true end) else nil,
        OnClick = function()
            Nav.SetSetting(sKey, not peek(bOn))
            SoundController:Play("Click")
        end,
    })
end

local function Passes(scope)
    local tCards = {}
    local tOrder = { "DoubleCash", "DoublePower", "AutoLaunch", "VIP" }
    local tIcons = { DoubleCash = "💵", DoublePower = "⚡", AutoLaunch = "🤖", VIP = "👑" }
    for i, sKey in tOrder do
        local tPass = MonetizationConfig.Passes[sKey]
        local bOwned = scope:Computed(function(use) return (use(V.Passes) or {})[sKey] == true end)
        tCards[i] = Card(scope, {
            LayoutOrder = i,
            [Children] = {
                UI.Text(scope, { Text = tIcons[sKey], TextSize = 64, NoStroke = true, Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 70) }),
                UI.Text(scope, { Text = tPass.Name, TextSize = 28, TextScaled = true, Position = UDim2.fromOffset(10, 80), Size = UDim2.new(1, -20, 0, 36) }),
                UI.Text(scope, { Text = tPass.Description, TextSize = 19, Color = Theme.Ink, NoStroke = true, Font = Theme.Body, TextWrapped = true,
                    Position = UDim2.fromOffset(10, 118), Size = UDim2.new(1, -20, 0, 90), YAlign = Enum.TextYAlignment.Top }),
                UI.Button(scope, {
                    Variant = scope:Computed(function(use) return if use(bOwned) then "Grey" else "Purple" end),
                    Text = scope:Computed(function(use) return if use(bOwned) then "OWNED" else `R$ {tPass.Price}` end),
                    TextSize = 28,
                    Visible = Purchasable(tPass),
                    Position = UDim2.new(0, 10, 1, -70),
                    Size = UDim2.new(1, -20, 0, 60),
                    OnClick = function()
                        if not peek(bOwned) then Nav.PromptPass(sKey) end
                    end,
                }),
            },
        })
    end
    return UI.Modal(scope, {
        Name = "Passes",
        Title = "⭐ Passes",
        Variant = "Gold",
        Size = UDim2.fromOffset(1100, 560),
        OnClose = Nav.Close,
        [Children] = {
            scope:New("Frame")({
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, -76),
                [Children] = {
                    scope:New("UIListLayout")({ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 14), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
                    tCards,
                },
            }),
            scope:New("Frame")({
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(0, 1),
                Position = UDim2.fromScale(0, 1),
                Size = UDim2.new(1, 0, 0, 64),
                [Children] = {
                    scope:New("UIListLayout")({ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 14), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
                    Toggle(scope, "AutoReplace", "Auto-Replace weaker"),
                    Toggle(scope, "AutoLaunch", "Auto-Launch", "AutoLaunch"),
                },
            }),
        },
    })
end

-- ===== Offers =====
local function OfferCard(scope, props)
    local tProduct = MonetizationConfig.Products[props.Key]
    return Card(scope, {
        LayoutOrder = props.LayoutOrder,
        Size = props.Size or UDim2.fromOffset(250, 330),
        [Children] = {
            UI.Text(scope, { Text = props.Icon, TextSize = 70, NoStroke = true, Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 80) }),
            UI.Text(scope, { Text = tProduct.Name, TextSize = 28, TextScaled = true, Position = UDim2.fromOffset(10, 86), Size = UDim2.new(1, -20, 0, 36) }),
            UI.Text(scope, { Text = props.Description, TextSize = 19, Color = Theme.Ink, NoStroke = true, Font = Theme.Body, TextWrapped = true,
                Position = UDim2.fromOffset(10, 124), Size = UDim2.new(1, -20, 0, 120), YAlign = Enum.TextYAlignment.Top }),
            UI.Button(scope, {
                Variant = "Purple",
                Text = `R$ {tProduct.Price}`,
                TextSize = 28,
                Position = UDim2.new(0, 10, 1, -70),
                Size = UDim2.new(1, -20, 0, 60),
                Visible = props.Visible,
                OnClick = function() Nav.PromptProduct(props.Key) end,
            }),
        },
    })
end

local function Offer(scope)
    local bExclusiveOpen = (function()
        local t = MonetizationConfig.ExclusiveDinoWindow
        local nNow = os.time()
        return (t.StartsAt == 0 or nNow >= t.StartsAt) and (t.EndsAt == 0 or nNow < t.EndsAt)
    end)()
    local tCards = {
        OfferCard(scope, { Key = "ExclusiveDino", Icon = "🦖", LayoutOrder = 1,
            Description = `Limited! A Huge Cosmic raptor that earns {GameConfig.ExclusiveDinoMultiplier * 100}% of your best dino's income. One per player.`,
            Visible = scope:Computed(function(use) return bExclusiveOpen and not use(V.ExclusiveDino) and Purchasable(MonetizationConfig.Products.ExclusiveDino) end) }),
        OfferCard(scope, { Key = "StarterPack", Icon = "🎁", LayoutOrder = 2,
            Description = "Bone Slingshot + Raw Steak bait + 1 Mutation Reroll. One time only.",
            Visible = scope:Computed(function(use) return not use(V.StarterPackBought) and Purchasable(MonetizationConfig.Products.StarterPack) end) }),
        OfferCard(scope, { Key = "CashSmall", Icon = "💰", LayoutOrder = 3, Description = "10 minutes of your current income, instantly.", Visible = Purchasable(MonetizationConfig.Products.CashSmall) }),
        OfferCard(scope, { Key = "CashMedium", Icon = "💰", LayoutOrder = 4, Description = "45 minutes of your current income, instantly.", Visible = Purchasable(MonetizationConfig.Products.CashMedium) }),
        OfferCard(scope, { Key = "CashLarge", Icon = "🏦", LayoutOrder = 5, Description = "150 minutes of your current income, instantly.", Visible = Purchasable(MonetizationConfig.Products.CashLarge) }),
        OfferCard(scope, { Key = "MeteorStorm", Icon = "☄️", LayoutOrder = 6, Description = "Start a 5-minute Meteor Storm for EVERYONE. Mutations x3!", Visible = Purchasable(MonetizationConfig.Products.MeteorStorm) }),
    }
    return UI.Modal(scope, {
        Name = "Offer",
        Title = "🎁 Offers",
        Variant = "Purple",
        Size = UDim2.fromOffset(1000, 520),
        OnClose = Nav.Close,
        [Children] = Grid(scope, { Horizontal = true, [Children] = tCards }),
    })
end

-- ===== Reroll =====
local function MutationOdds(): { { Id: string, Chance: number } }
    -- Mirrors CatchRoller.MutationOdds at luck 1 with the current weather (disclosure before purchase).
    local tEvent = WeatherConfig.Events[peek(V.Weather)]
    local tMult = tEvent and tEvent.MutationMultipliers or {}
    local tOut, nTotal = {}, 0
    for _, t in DinoConfig.Mutations do
        if not t.Default then
            local p = math.clamp(t.Chance * (tMult[t.Id] or 1), 0, 1)
            nTotal += p
            table.insert(tOut, { Id = t.Id, Chance = p })
        end
    end
    table.insert(tOut, 1, { Id = "Normal", Chance = math.max(0, 1 - nTotal) })
    return tOut
end

local function Reroll(scope)
    local oReroll = Remote:GetFunction("RerollMutation")
    local bBusy = scope:Value(false)
    local sOdds = scope:Computed(function(use)
        use(V.Weather)
        local tParts = {}
        for _, t in MutationOdds() do
            table.insert(tParts, string.format("%s %.1f%%", t.Id, t.Chance * 100))
        end
        return "Odds: " .. table.concat(tParts, " · ")
    end)
    return UI.Modal(scope, {
        Name = "Reroll",
        Title = scope:Computed(function(use) return `🧪 Mutation Reroll  (x{use(V.Rerolls)})` end),
        Variant = "Blue",
        Size = UDim2.fromOffset(1000, 600),
        OnClose = Nav.Close,
        [Children] = {
            UI.Text(scope, { Text = sOdds, TextSize = 20, Color = Theme.Ink, NoStroke = true, Font = Theme.Body, TextWrapped = true, Size = UDim2.new(1, 0, 0, 46) }),
            scope:New("Frame")({
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(0, 50),
                Size = UDim2.new(1, 0, 0, 64),
                Visible = scope:Computed(function(use) return use(V.Rerolls) <= 0 end),
                [Children] = {
                    scope:New("UIListLayout")({ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
                    UI.Button(scope, { Variant = "Purple", Text = `Buy 1 · R$ {MonetizationConfig.Products.Reroll1.Price}`, TextSize = 24, Size = UDim2.fromOffset(300, 60),
                        Visible = Purchasable(MonetizationConfig.Products.Reroll1), OnClick = function() Nav.PromptProduct("Reroll1") end }),
                    UI.Button(scope, { Variant = "Purple", Text = `Buy 3 · R$ {MonetizationConfig.Products.Reroll3.Price}`, TextSize = 24, Size = UDim2.fromOffset(300, 60),
                        Visible = Purchasable(MonetizationConfig.Products.Reroll3), OnClick = function() Nav.PromptProduct("Reroll3") end }),
                },
            }),
            Grid(scope, {
                Position = UDim2.fromOffset(0, 120),
                Size = UDim2.new(1, 0, 1, -120),
                CellSize = UDim2.fromOffset(230, 140),
                [Children] = scope:ForValues(V.Dinos, function(use, innerScope, tDino)
                    local tMut = DinoConfig.GetMutation(tDino.Mutation)
                    local tSize = DinoConfig.GetSize(tDino.Size)
                    return Card(innerScope, {
                        LayoutOrder = tDino.Id,
                        [Children] = {
                            UI.Text(innerScope, { Text = DinoConfig.Species[tDino.Species].Name, TextSize = 24, TextScaled = true, Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 0, 30) }),
                            UI.Text(innerScope, { Text = `{tSize.Name} · {tMut.Name}`, TextSize = 22, Color = if tMut.Default then Theme.White else tMut.Color,
                                Position = UDim2.fromOffset(8, 38), Size = UDim2.new(1, -16, 0, 26) }),
                            UI.Button(innerScope, {
                                Variant = "Blue",
                                Text = "REROLL",
                                TextSize = 24,
                                Position = UDim2.new(0, 8, 1, -62),
                                Size = UDim2.new(1, -16, 0, 54),
                                Disabled = innerScope:Computed(function(use2) return use2(V.Rerolls) <= 0 or use2(bBusy) end),
                                OnClick = function()
                                    if peek(bBusy) or peek(V.Rerolls) <= 0 then return end
                                    bBusy:set(true)
                                    local tResult = oReroll:InvokeServer(tDino.Id)
                                    bBusy:set(false)
                                    if tResult and tResult.Ok then
                                        SoundController:Play("Reveal")
                                    end
                                end,
                            }),
                        },
                    })
                end),
            }),
        },
    })
end

-- ===== Admin =====
local function Admin(scope)
    local oAction = Remote:GetEvent("AdminAction")
    local sText = scope:Value("")
    local function Do(t)
        oAction:FireServer(t)
        SoundController:Play("Click")
    end
    local tButtons = {
        { "☄️ Meteor Storm 5m", "Red", { Action = "MeteorStorm", Minutes = 5 } },
        { "❄️ Ice Age 5m", "Blue", { Action = "IceAge", Minutes = 5 } },
        { "☀️ Clear sky", "Grey", { Action = "Clear" } },
        { "🍀 Luck x2 15m", "Green", { Action = "Luck", Multiplier = 2, Minutes = 15 } },
        { "🍀 Luck x5 15m", "Green", { Action = "Luck", Multiplier = 5, Minutes = 15 } },
        { "🍀 Luck x10 5m", "Gold", { Action = "Luck", Multiplier = 10, Minutes = 5 } },
        { "🦖 Rare spawn (all)", "Purple", { Action = "RareSpawn" } },
    }
    local tChildren = {}
    for i, t in tButtons do
        tChildren[i] = UI.Button(scope, { Variant = t[2], Text = t[1], TextSize = 24, Size = UDim2.fromOffset(300, 64), LayoutOrder = i, OnClick = function() Do(t[3]) end })
    end
    return UI.Modal(scope, {
        Name = "Admin",
        Title = "🛠 Admin Abuse",
        Variant = "Purple",
        Size = UDim2.fromOffset(1000, 520),
        OnClose = Nav.Close,
        [Children] = {
            scope:New("Frame")({
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 240),
                [Children] = {
                    scope:New("UIGridLayout")({ CellSize = UDim2.fromOffset(300, 64), CellPadding = UDim2.fromOffset(14, 14), SortOrder = Enum.SortOrder.LayoutOrder }),
                    tChildren,
                },
            }),
            scope:New("TextBox")({
                Name = "AnnounceText",
                PlaceholderText = "Server announcement...",
                Text = "",
                ClearTextOnFocus = false,
                FontFace = Theme.Body,
                TextSize = 24,
                TextColor3 = Theme.Ink,
                BackgroundColor3 = Color3.new(1, 1, 1),
                Position = UDim2.fromOffset(0, 270),
                Size = UDim2.new(1, -330, 0, 64),
                [Out("Text")] = sText,
                [Children] = { UI.Corner(scope, 12), UI.Stroke(scope, 3), scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 12) }) },
            }),
            UI.Button(scope, { Variant = "Orange", Text = "📢 Announce", TextSize = 24, Position = UDim2.new(1, -310, 0, 270), Size = UDim2.fromOffset(310, 64),
                OnClick = function()
                    local s = peek(sText)
                    if s ~= "" then Do({ Action = "Announce", Text = s }) end
                end }),
        },
    })
end

return function(scope, props)
    local tBuilders = { Shop = Shop, Index = Index, Passes = Passes, Offer = Offer, Reroll = Reroll, Admin = Admin }
    local tModals = {}
    for sName, fnBuild in tBuilders do
        local oModal = fnBuild(scope)
        oModal.Visible = false
        tModals[sName] = oModal
    end
    scope:Observer(V.Modal):onBind(function()
        local sOpen = peek(V.Modal)
        for sName, oModal in tModals do
            oModal.Visible = sName == sOpen
        end
        if tModals[sOpen] then
            UI.FocusForGamepad(tModals[sOpen]:FindFirstChildWhichIsA("ImageButton", true))
            ContextActionService:BindAction("SFD_CloseModal", function(_, eState)
                if eState == Enum.UserInputState.Begin then Nav.Close() end
                return Enum.ContextActionResult.Sink
            end, false, Enum.KeyCode.ButtonB)
        else
            ContextActionService:UnbindAction("SFD_CloseModal")
        end
    end)

    return UI.Screen(scope, {
        Name = "Modals",
        Parent = props.Parent,
        DisplayOrder = 8,
        Enabled = scope:Computed(function(use) return use(V.Modal) ~= "" end),
        [Children] = UI.ScaledRoot(scope, {
            [Children] = {
                UI.Backdrop(scope, { OnClick = Nav.Close }),
                tModals,
            },
        }),
    })
end
