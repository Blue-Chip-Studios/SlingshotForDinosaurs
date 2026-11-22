--[[
    RetentionModals
    ---------------
    Builders for the retention screens, mounted by Gui/Modals:
      Rewards  7-day login streak + promo code box
      Quests   today's 3 daily quests + the weekly quest
      Rebirth  reset launch progress for a permanent bonus
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.fusion)
local Store = require(ReplicatedStorage.BCDKClient.LMGui.Store)
local Remote = require(ReplicatedStorage.BCDKShared.Remote)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Format = require(ReplicatedStorage.Shared.Format)
local QuestPicker = require(ReplicatedStorage.Shared.QuestPicker)
local RetentionConfig = require(ReplicatedStorage.Config.RetentionConfig)
local UI = require(script.Parent.UI)
local Nav = require(script.Parent.Nav)
local SoundController = require(ReplicatedStorage.ClientModules.SoundController)

local Children, Out, peek = Fusion.Children, Fusion.Out, Fusion.peek
local V = Store.Values
local oLocalPlayer = Players.LocalPlayer

local function Feedback(tResult, sOkPrefix: string)
    if tResult and tResult.Ok then
        SoundController:Play("Reveal")
        V.Toast:set("") -- clear
        local iId = os.clock() * 1000 // 1
        local tPush = table.clone(peek(V.Announcements))
        table.insert(tPush, { Id = iId, Text = sOkPrefix .. (tResult.Got or ""), Kind = "Purchase" })
        V.Announcements:set(tPush)
        task.delay(4, function()
            local tNow = table.clone(peek(V.Announcements))
            for i, t in tNow do
                if t.Id == iId then table.remove(tNow, i) break end
            end
            V.Announcements:set(tNow)
        end)
    else
        local tReasons = { Claimed = "Already claimed today!", NotDone = "Not finished yet!", Invalid = "That code doesn't exist.", Used = "You already used that code.", Cash = "Not enough cash yet!", Distance = "Reach the Ice Age first!" }
        V.Toast:set(tReasons[tResult and tResult.Reason or ""] or "Try again in a moment.")
    end
end

local function RewardLabel(t): string
    if t.Kind == "Cash" then return "Cash" end
    if t.Kind == "Reroll" then return `x{t.Amount} Reroll` end
    return `{t.Multiplier}x Luck {t.Minutes}m`
end

local M = {}

function M.Rewards(scope)
    local oClaim = Remote:GetFunction("ClaimDaily")
    local oCode = Remote:GetFunction("RedeemCode")
    local sCode = scope:Value("")
    local bClaimable = scope:Computed(function(use)
        use(V.Now)
        return use(V.LastDailyDay) ~= QuestPicker.Today()
    end)
    -- Which streak day a claim now would give (1..7).
    local iNextSlot = scope:Computed(function(use)
        use(V.Now)
        local iLast, iStreak = use(V.LastDailyDay), use(V.DailyStreak)
        local iToday = QuestPicker.Today()
        local iNext = if iLast == iToday then iStreak elseif iLast == iToday - 1 then iStreak + 1 else 1
        return ((math.max(iNext, 1) - 1) % #RetentionConfig.Daily) + 1
    end)
    local tDays = {}
    for i, t in RetentionConfig.Daily do
        tDays[i] = scope:New("Frame")({
            Name = "Day" .. i,
            LayoutOrder = i,
            Size = UDim2.fromOffset(118, 150),
            BackgroundColor3 = scope:Computed(function(use)
                return if use(iNextSlot) == i then Theme.Variants.Gold[1] else Theme.Panel
            end),
            [Children] = {
                UI.Corner(scope, Theme.Radius.Card),
                UI.Stroke(scope, 3),
                UI.Text(scope, { Text = `Day {i}`, TextSize = 24, Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 28) }),
                UI.Icon(scope, { Key = if t.Kind == "Cash" then "Icon_Cash" elseif t.Kind == "Reroll" then "Icon_Potion" else "Icon_Star", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 36), Size = UDim2.fromOffset(64, 64) }),
                UI.Text(scope, { Text = RewardLabel(t), TextSize = 18, TextScaled = true, Position = UDim2.new(0, 6, 1, -40), Size = UDim2.new(1, -12, 0, 32) }),
            },
        })
    end
    return UI.Modal(scope, {
        Name = "Rewards",
        Title = scope:Computed(function(use) return `🎁 Daily Rewards  (streak {use(V.DailyStreak)})` end),
        Variant = "Gold",
        Size = UDim2.fromOffset(980, 520),
        OnClose = Nav.Close,
        [Children] = {
            scope:New("Frame")({
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 160),
                [Children] = {
                    scope:New("UIListLayout")({ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
                    tDays,
                },
            }),
            UI.Button(scope, {
                Name = "Claim",
                Variant = "Green",
                Text = scope:Computed(function(use) return if use(bClaimable) then "CLAIM TODAY'S REWARD" else "COME BACK TOMORROW!" end),
                Disabled = scope:Computed(function(use) return not use(bClaimable) end),
                TextSize = 30,
                AnchorPoint = Vector2.new(0.5, 0),
                Position = UDim2.new(0.5, 0, 0, 176),
                Size = UDim2.fromOffset(520, 80),
                OnClick = function()
                    if peek(bClaimable) then Feedback(oClaim:InvokeServer(), "Daily reward: ") end
                end,
            }),
            UI.Text(scope, { Text = "Have a code?", TextSize = 26, Color = Theme.Ink, NoStroke = true, Position = UDim2.fromOffset(0, 286), Size = UDim2.new(1, 0, 0, 30) }),
            scope:New("TextBox")({
                Name = "CodeBox",
                PlaceholderText = "Enter code",
                Text = "",
                ClearTextOnFocus = false,
                FontFace = Theme.Display,
                TextSize = 30,
                TextColor3 = Theme.Ink,
                BackgroundColor3 = Color3.new(1, 1, 1),
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(0.5, 90, 0, 326),
                Size = UDim2.fromOffset(420, 70),
                [Out("Text")] = sCode,
                [Children] = { UI.Corner(scope, 14), UI.Stroke(scope, 3) },
            }),
            UI.Button(scope, {
                Name = "Redeem",
                Variant = "Purple",
                Text = "REDEEM",
                TextSize = 28,
                Position = UDim2.new(0.5, 104, 0, 326),
                Size = UDim2.fromOffset(200, 70),
                OnClick = function()
                    local s = peek(sCode)
                    if s ~= "" then Feedback(oCode:InvokeServer(s), "Code redeemed: ") end
                end,
            }),
        },
    })
end

local function QuestRow(scope, sId: string, sText: string, iGoal: number, fnProgress, fnClaimed, tReward, iOrder: number)
    local oClaim = Remote:GetFunction("ClaimQuest")
    local bDone = scope:Computed(function(use) return fnProgress(use) >= iGoal end)
    return scope:New("Frame")({
        Name = sId,
        LayoutOrder = iOrder,
        Size = UDim2.new(1, -8, 0, 96),
        BackgroundColor3 = Color3.new(1, 1, 1),
        [Children] = {
            UI.Corner(scope, Theme.Radius.Card),
            UI.Stroke(scope, 3),
            UI.Text(scope, { Text = sText:format(iGoal), TextSize = 26, Color = Theme.Ink, NoStroke = true, XAlign = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -260, 0, 32) }),
            UI.Text(scope, { Text = "Reward: " .. RewardLabel(tReward), TextSize = 20, Color = Theme.Variants.Purple[2], NoStroke = true, Font = Theme.Body, XAlign = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(16, 40), Size = UDim2.new(1, -260, 0, 22) }),
            -- Progress bar
            scope:New("Frame")({
                BackgroundColor3 = Theme.PanelDeep,
                Position = UDim2.fromOffset(16, 66),
                Size = UDim2.new(1, -260, 0, 18),
                [Children] = {
                    UI.Corner(scope, 9),
                    scope:New("Frame")({
                        BackgroundColor3 = Theme.Variants.Green[1],
                        Size = scope:Computed(function(use) return UDim2.fromScale(math.clamp(fnProgress(use) / iGoal, 0, 1), 1) end),
                        [Children] = UI.Corner(scope, 9),
                    }),
                    UI.Text(scope, { Text = scope:Computed(function(use) return `{fnProgress(use)}/{iGoal}` end), TextSize = 16, StrokeThickness = 2 }),
                },
            }),
            UI.Button(scope, {
                Variant = scope:Computed(function(use)
                    if fnClaimed(use) then return "Grey" end
                    return if use(bDone) then "Green" else "Grey"
                end),
                Text = scope:Computed(function(use)
                    if fnClaimed(use) then return "DONE" end
                    return if use(bDone) then "CLAIM" else "..."
                end),
                TextSize = 26,
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -14, 0.5, 0),
                Size = UDim2.fromOffset(200, 66),
                OnClick = function()
                    Feedback(oClaim:InvokeServer(sId), "Quest complete: ")
                end,
            }),
        },
    })
end

function M.Quests(scope)
    -- Rebuild the daily rows when the (server-synced) UTC day rolls over.
    local iDay = scope:Computed(function(use) return math.floor(use(V.Now) / 86400) end)
    local tDaily = scope:Computed(function(use, innerScope)
        local tList = {}
        for i, tQuest in QuestPicker.Daily(oLocalPlayer.UserId, use(iDay)) do
            local sId = tQuest.Id
            tList[i] = QuestRow(innerScope, sId, tQuest.Text, tQuest.Goal,
                function(use2) return (use2(V.QuestProgress) or {})[sId] or 0 end,
                function(use2) return (use2(V.QuestClaimed) or {})[sId] == true end,
                tQuest.Reward, i)
        end
        return tList
    end)
    local tW = RetentionConfig.WeeklyQuest
    local tRows = { tDaily }
    tRows[2] = QuestRow(scope, tW.Id, "⭐ WEEKLY: " .. tW.Text, tW.Goal,
        function(use) return use(V.WeeklyProgress) or 0 end,
        function(use) return use(V.WeeklyClaimed) == true end,
        tW.Reward, 10)
    return UI.Modal(scope, {
        Name = "Quests",
        Title = "📜 Quests",
        Variant = "Blue",
        Size = UDim2.fromOffset(900, 560),
        OnClose = Nav.Close,
        [Children] = {
            UI.Text(scope, { Text = "New daily quests every day at midnight (UTC)", TextSize = 20, Color = Theme.Ink, NoStroke = true, Font = Theme.Body, Size = UDim2.new(1, 0, 0, 26) }),
            scope:New("Frame")({
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(0, 32),
                Size = UDim2.new(1, 0, 1, -32),
                [Children] = {
                    scope:New("UIListLayout")({ Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }),
                    tRows,
                },
            }),
        },
    })
end

function M.Rebirth(scope)
    local oRebirth = Remote:GetFunction("Rebirth")
    local tCfg = RetentionConfig.Rebirth
    local nCost = scope:Computed(function(use) return tCfg.BaseCost * tCfg.CostGrowth ^ use(V.Rebirths) end)
    local bReady = scope:Computed(function(use) return use(V.BestDistance) >= tCfg.RequiredMeters and use(V.Cash) >= use(nCost) end)
    return UI.Modal(scope, {
        Name = "Rebirth",
        Title = scope:Computed(function(use) return `♻️ Rebirth  (x{use(V.Rebirths)})` end),
        Variant = "Purple",
        Size = UDim2.fromOffset(760, 480),
        OnClose = Nav.Close,
        [Children] = {
            UI.Text(scope, {
                Text = scope:Computed(function(use)
                    local n = use(V.Rebirths)
                    return `Bonus now: +{n * tCfg.BonusPerRebirth * 100}% Power & distance\nAfter rebirth: +{(n + 1) * tCfg.BonusPerRebirth * 100}%`
                end),
                TextSize = 30, Color = Theme.Ink, NoStroke = true, Size = UDim2.new(1, 0, 0, 80),
            }),
            UI.Text(scope, {
                Text = "Resets cash, Power, slingshot and bait.\nYou KEEP all dinos, the Index, park slots and passes.",
                TextSize = 22, Color = Theme.Ink, NoStroke = true, Font = Theme.Body, Position = UDim2.fromOffset(0, 90), Size = UDim2.new(1, 0, 0, 60),
            }),
            UI.Text(scope, {
                Text = scope:Computed(function(use)
                    return `Needs: reach {Format.Meters(tCfg.RequiredMeters)} (best {Format.Meters(use(V.BestDistance))}) and {Format.Cash(use(nCost))}`
                end),
                TextSize = 22, Color = Theme.Variants.Red[2], NoStroke = true, Position = UDim2.fromOffset(0, 160), Size = UDim2.new(1, 0, 0, 30),
            }),
            UI.Button(scope, {
                Variant = scope:Computed(function(use) return if use(bReady) then "Purple" else "Grey" end),
                Text = "REBIRTH",
                TextSize = 34,
                AnchorPoint = Vector2.new(0.5, 1),
                Position = UDim2.new(0.5, 0, 1, -6),
                Size = UDim2.fromOffset(360, 84),
                OnClick = function()
                    local t = oRebirth:InvokeServer()
                    if t and t.Ok then
                        Feedback({ Ok = true, Got = `Rebirth {t.Rebirths}!` }, "")
                        Nav.Close()
                    else
                        Feedback(t, "")
                    end
                end,
            }),
        },
    })
end

-- Gift picker: choose who in this server receives the pass selected in Store.GiftPass.
function M.Gift(scope)
    local MonetizationConfig = require(ReplicatedStorage.Config.MonetizationConfig)
    local tOthers = scope:Value({})
    local function RefreshPlayers()
        local t = {}
        for _, o in Players:GetPlayers() do
            if o ~= oLocalPlayer then table.insert(t, o) end
        end
        tOthers:set(t)
    end
    RefreshPlayers()
    table.insert(scope, Players.PlayerAdded:Connect(RefreshPlayers))
    table.insert(scope, Players.PlayerRemoving:Connect(function() task.defer(RefreshPlayers) end))
    return UI.Modal(scope, {
        Name = "Gift",
        Title = scope:Computed(function(use)
            local tPass = MonetizationConfig.Passes[use(V.GiftPass)]
            return "🎁 Gift " .. (tPass and tPass.Name or "a pass")
        end),
        Variant = "Orange",
        Size = UDim2.fromOffset(760, 520),
        OnClose = Nav.Close,
        [Children] = {
            UI.Text(scope, {
                Text = scope:Computed(function(use)
                    return if #use(tOthers) == 0 then "Nobody else is in this server yet. Invite a friend!" else "Pick who gets it. It's delivered even if they leave."
                end),
                TextSize = 22, Color = Theme.Ink, NoStroke = true, Font = Theme.Body, Size = UDim2.new(1, 0, 0, 30),
            }),
            scope:New("ScrollingFrame")({
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Position = UDim2.fromOffset(0, 40),
                Size = UDim2.new(1, 0, 1, -40),
                CanvasSize = UDim2.new(),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollBarThickness = 8,
                [Children] = {
                    scope:New("UIListLayout")({ Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.Name }),
                    scope:ForValues(tOthers, function(use, innerScope, oPlayer)
                        return UI.Button(innerScope, {
                            Name = oPlayer.Name,
                            Variant = "Blue",
                            IconKey = "Icon_Gift",
                            IconSize = 40,
                            Text = oPlayer.DisplayName,
                            TextSize = 28,
                            Size = UDim2.fromOffset(560, 72),
                            OnClick = function()
                                local sPass = peek(V.GiftPass)
                                if sPass ~= "" then
                                    Nav.PromptGift(sPass, oPlayer.UserId)
                                end
                            end,
                        })
                    end),
                },
            }),
        },
    })
end

return M
