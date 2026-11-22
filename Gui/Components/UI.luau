--[[
    UI
    --
    Fusion 0.3 component library implementing Docs/UI/DesignSystem.md:
    outlined display text, chunky gradient buttons with a dark "lip",
    panels/modals, chips, currency pills, and a shared responsive UIScale.
    Screens compose these; they never hand-roll a button.
]]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Fusion = require(ReplicatedStorage.Packages.fusion)
local Theme = require(ReplicatedStorage.Shared.Theme)

local Children, OnEvent, peek = Fusion.Children, Fusion.OnEvent, Fusion.peek

local UI = {}

-- ===== Responsive scale (one shared Value for every screen) =====
local tRootScope = Fusion.scoped(Fusion)
UI.Scale = tRootScope:Value(1)
UI.IsTouch = tRootScope:Value(UserInputService.TouchEnabled)
local function IsGamepadInput(e: Enum.UserInputType): boolean
    return e.Name:sub(1, 7) == "Gamepad"
end
-- True while the player's last input came from a controller (prompts switch to R2 / A / D-pad).
UI.IsGamepad = tRootScope:Value(IsGamepadInput(UserInputService:GetLastInputType()) or GuiService:IsTenFootInterface())
-- Bottom-right widgets move above Roblox's touch jump button (~120px tall at design scale).
-- Sits left of the right-hand button column and above the jump button, so short phones (0.5 scale) don't overlap.
UI.TouchWeatherPosition = UDim2.new(1, -124, 1, -200)

local function UpdateScale()
    local oCamera = Workspace.CurrentCamera
    if not oCamera then return end
    local v = oCamera.ViewportSize
    -- Designed at 1280x720; phones land around 0.55-0.75, consoles ~1.1 on a 1080p TV.
    local n = math.min(v.X / 1280, v.Y / 720)
    if GuiService:IsTenFootInterface() then
        n *= 1.1
    end
    UI.Scale:set(math.clamp(n, 0.5, 1.4))
end
task.spawn(function()
    while not Workspace.CurrentCamera do task.wait() end
    UpdateScale()
    Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateScale)
end)
UserInputService.LastInputTypeChanged:Connect(function(eType)
    UI.IsTouch:set(eType == Enum.UserInputType.Touch)
    if eType == Enum.UserInputType.Touch or eType.Name:sub(1, 5) == "Mouse" or eType == Enum.UserInputType.Keyboard then
        UI.IsGamepad:set(false)
    elseif IsGamepadInput(eType) then
        UI.IsGamepad:set(true)
    end
end)

-- Standard ScreenGui with safe-area insets and the shared scale.
function UI.Screen(scope, props)
    return scope:New("ScreenGui")({
        Name = props.Name,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
        DisplayOrder = props.DisplayOrder or 0,
        IgnoreGuiInset = props.IgnoreGuiInset or false,
        Enabled = props.Enabled,
        Parent = props.Parent,
        [Children] = props[Children],
    })
end

-- A full-size frame carrying the UIScale; put screen content inside it.
function UI.ScaledRoot(scope, props)
    local tChildren = { scope:New("UIScale")({ Scale = UI.Scale }) }
    -- TV overscan: consoles can crop ~5% of each edge, so keep the HUD inside a 4% margin.
    if GuiService:IsTenFootInterface() then
        table.insert(tChildren, scope:New("UIPadding")({
            PaddingLeft = UDim.new(0.04, 0), PaddingRight = UDim.new(0.04, 0),
            PaddingTop = UDim.new(0.04, 0), PaddingBottom = UDim.new(0.04, 0),
        }))
    end
    table.insert(tChildren, props[Children])
    return scope:New("Frame")({
        Name = "Root",
        BackgroundTransparency = 1,
        Size = scope:Computed(function(use)
            local n = use(UI.Scale)
            return UDim2.fromScale(1 / n, 1 / n)
        end),
        [Children] = tChildren,
    })
end

function UI.Corner(scope, nRadius: number)
    return scope:New("UICorner")({ CornerRadius = UDim.new(0, nRadius) })
end

function UI.Stroke(scope, nThickness: number, cColor: Color3?, eMode: Enum.ApplyStrokeMode?)
    return scope:New("UIStroke")({
        Thickness = nThickness,
        Color = cColor or Theme.Ink,
        ApplyStrokeMode = eMode or Enum.ApplyStrokeMode.Border,
        LineJoinMode = Enum.LineJoinMode.Round,
    })
end

-- Display text: white (or Color) with a dark outline.
function UI.Text(scope, props)
    return scope:New("TextLabel")({
        Name = props.Name or "Text",
        BackgroundTransparency = 1,
        Size = props.Size or UDim2.fromScale(1, 1),
        Position = props.Position,
        AnchorPoint = props.AnchorPoint,
        AutomaticSize = props.AutomaticSize,
        Text = props.Text,
        RichText = props.RichText,
        FontFace = props.Font or Theme.Display,
        TextSize = props.TextSize or 28,
        TextScaled = props.TextScaled or false,
        TextWrapped = props.TextWrapped or false,
        TextColor3 = props.Color or Theme.White,
        TextXAlignment = props.XAlign or Enum.TextXAlignment.Center,
        TextYAlignment = props.YAlign or Enum.TextYAlignment.Center,
        TextTransparency = props.Transparency,
        Rotation = props.Rotation,
        ZIndex = props.ZIndex,
        LayoutOrder = props.LayoutOrder,
        Visible = props.Visible,
        [Children] = {
            if props.NoStroke then nil else scope:New("UIStroke")({ Thickness = props.StrokeThickness or Theme.Stroke.Text, Color = Theme.Ink, Transparency = props.Transparency }),
            props[Children],
        },
    })
end

--[[
    Button: chunky gradient face on a dark lip.
    props: Variant (state or string), Text, Icon (emoji/text), Size, Position,
    AnchorPoint, OnClick, Badge (state<boolean>), TextSize, LayoutOrder,
    Visible, Disabled (state<boolean>), OnDown/OnUp (for hold buttons).
]]
function UI.Button(scope, props)
    local bPressed = scope:Value(false)
    local bHover = scope:Value(false)
    local fnVariant = function(use)
        local v = props.Variant or "Green"
        if typeof(v) ~= "string" then v = use(v) end
        if props.Disabled and use(props.Disabled) then v = "Grey" end
        return Theme.Variants[v] or Theme.Variants.Green
    end
    local nLip = Theme.Lip
    local oFaceOffset = scope:Spring(scope:Computed(function(use)
        return if use(bPressed) then nLip - 2 else 0
    end), 40, 0.7)
    local nScale = scope:Spring(scope:Computed(function(use)
        return if use(bPressed) then 0.96 elseif use(bHover) then 1.04 else 1
    end), 30, 0.6)
    local fnClick = props.OnClick

    return scope:New("ImageButton")({
        Name = props.Name or "Button",
        BackgroundTransparency = 1,
        Image = "",
        Size = props.Size or UDim2.fromOffset(200, 72),
        Position = props.Position,
        AnchorPoint = props.AnchorPoint,
        LayoutOrder = props.LayoutOrder,
        Visible = props.Visible,
        ZIndex = props.ZIndex,
        Selectable = true,
        SelectionImageObject = nil,
        [OnEvent("MouseEnter")] = function() bHover:set(true) end,
        [OnEvent("MouseLeave")] = function()
            bHover:set(false)
            if peek(bPressed) and props.OnUp then props.OnUp() end
            bPressed:set(false)
        end,
        [OnEvent("MouseButton1Down")] = function()
            bPressed:set(true)
            if props.OnDown then props.OnDown() end
        end,
        [OnEvent("MouseButton1Up")] = function()
            bPressed:set(false)
            if props.OnUp then props.OnUp() end
        end,
        [OnEvent("Activated")] = function()
            if props.Disabled and peek(props.Disabled) and not props.ClickWhenDisabled then return end
            if fnClick then fnClick() end
        end,
        [Children] = {
            scope:New("UIScale")({ Scale = nScale }),
            -- Lip
            scope:New("Frame")({
                Name = "Lip",
                BackgroundColor3 = Theme.Ink,
                Size = UDim2.new(1, 0, 1, -nLip),
                Position = UDim2.fromOffset(0, nLip),
                [Children] = { UI.Corner(scope, Theme.Radius.Button) },
            }),
            -- Face
            scope:New("Frame")({
                Name = "Face",
                BackgroundColor3 = Color3.new(1, 1, 1),
                Size = UDim2.new(1, 0, 1, -nLip),
                Position = scope:Computed(function(use)
                    return UDim2.fromOffset(0, use(oFaceOffset))
                end),
                [Children] = {
                    UI.Corner(scope, Theme.Radius.Button),
                    UI.Stroke(scope, Theme.Stroke.Button),
                    scope:New("UIGradient")({
                        Rotation = 90,
                        Color = scope:Computed(function(use)
                            local t = fnVariant(use)
                            return ColorSequence.new(t[1], t[2])
                        end),
                    }),
                    -- Top shine
                    scope:New("Frame")({
                        Name = "Shine",
                        BackgroundColor3 = Color3.new(1, 1, 1),
                        BackgroundTransparency = 0.75,
                        Size = UDim2.new(1, -12, 0.28, 0),
                        Position = UDim2.fromOffset(6, 4),
                        [Children] = { UI.Corner(scope, 8) },
                    }),
                    scope:New("Frame")({
                        Name = "Content",
                        BackgroundTransparency = 1,
                        Size = UDim2.fromScale(1, 1),
                        [Children] = {
                            scope:New("UIListLayout")({
                                FillDirection = Enum.FillDirection.Horizontal,
                                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                                VerticalAlignment = Enum.VerticalAlignment.Center,
                                Padding = UDim.new(0, 8),
                                SortOrder = Enum.SortOrder.LayoutOrder,
                            }),
                            if props.IconKey then scope:New("ImageLabel")({
                                Name = "IconImage",
                                BackgroundTransparency = 1,
                                Image = (function()
                                    local iId = require(ReplicatedStorage.Config.AssetConfig).Images[props.IconKey]
                                    return if iId then "rbxassetid://" .. iId else ""
                                end)(),
                                ScaleType = Enum.ScaleType.Fit,
                                Size = UDim2.fromOffset(props.IconSize or 52, props.IconSize or 52),
                                LayoutOrder = 1,
                            }) elseif props.Icon then UI.Text(scope, {
                                Name = "Icon",
                                Text = props.Icon,
                                TextSize = props.IconSize or (props.TextSize or 28) + 4,
                                Size = UDim2.new(0, 0, 1, 0),
                                AutomaticSize = Enum.AutomaticSize.X,
                                LayoutOrder = 1,
                                NoStroke = true,
                            }) else nil,
                            if props.Text then UI.Text(scope, {
                                Name = "Label",
                                Text = props.Text,
                                TextSize = props.TextSize or 28,
                                Size = UDim2.new(0, 0, 1, 0),
                                AutomaticSize = Enum.AutomaticSize.X,
                                StrokeThickness = 2.5,
                                LayoutOrder = 2,
                            }) else nil,
                        },
                    }),
                },
            }),
            -- Notification badge
            if props.Badge then scope:New("Frame")({
                Name = "Badge",
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(1, -4, 0, 4),
                Size = UDim2.fromOffset(30, 30),
                BackgroundColor3 = Theme.Variants.Red[1],
                Visible = props.Badge,
                ZIndex = 3,
                [Children] = {
                    UI.Corner(scope, 15),
                    UI.Stroke(scope, 3),
                    UI.Text(scope, { Text = "!", TextSize = 24, ZIndex = 3 }),
                },
            }) else nil,
            props[Children],
        },
    })
end

-- Rounded panel with optional coloured header bar and red close button.
function UI.Modal(scope, props)
    local tVariant = Theme.Variants[props.Variant or "Blue"]
    return scope:New("Frame")({
        Name = props.Name or "Modal",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = props.Size or UDim2.fromOffset(900, 560),
        BackgroundColor3 = Theme.Panel,
        [Children] = {
            UI.Corner(scope, Theme.Radius.Modal),
            UI.Stroke(scope, Theme.Stroke.Modal),
            scope:New("UIScale")({ Scale = props.OpenScale }),
            scope:New("Frame")({
                Name = "Header",
                Size = UDim2.new(1, 0, 0, 72),
                BackgroundColor3 = Color3.new(1, 1, 1),
                [Children] = {
                    UI.Corner(scope, Theme.Radius.Modal),
                    UI.Stroke(scope, Theme.Stroke.Modal),
                    scope:New("UIGradient")({ Rotation = 90, Color = ColorSequence.new(tVariant[1], tVariant[2]) }),
                    UI.Text(scope, {
                        Text = props.Title,
                        TextSize = 44,
                        XAlign = Enum.TextXAlignment.Left,
                        Size = UDim2.new(1, -120, 1, 0),
                        Position = UDim2.fromOffset(24, 0),
                        StrokeThickness = 4,
                    }),
                    if props.OnClose then UI.Button(scope, {
                        Name = "Close",
                        Variant = "Red",
                        Text = "X",
                        TextSize = 34,
                        Size = UDim2.fromOffset(68, 68),
                        AnchorPoint = Vector2.new(1, 0.5),
                        Position = UDim2.new(1, -10, 0.5, 0),
                        OnClick = props.OnClose,
                    }) else nil,
                },
            }),
            scope:New("Frame")({
                Name = "Body",
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(16, 84),
                Size = UDim2.new(1, -32, 1, -100),
                [Children] = props[Children],
            }),
        },
    })
end

-- Small rounded label for size / mutation / rarity.
function UI.Chip(scope, props)
    return scope:New("Frame")({
        Name = "Chip",
        BackgroundColor3 = props.Color or Theme.Variants.Blue[1],
        Size = UDim2.fromOffset(0, props.Height or 34),
        AutomaticSize = Enum.AutomaticSize.X,
        LayoutOrder = props.LayoutOrder,
        Visible = props.Visible,
        Position = props.Position,
        AnchorPoint = props.AnchorPoint,
        [Children] = {
            UI.Corner(scope, 999),
            UI.Stroke(scope, 3),
            scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }),
            UI.Text(scope, {
                Text = props.Text,
                TextSize = props.TextSize or 22,
                Size = UDim2.new(0, 0, 1, 0),
                AutomaticSize = Enum.AutomaticSize.X,
                StrokeThickness = 2.5,
            }),
        },
    })
end

-- Dim backdrop that closes on click.
function UI.Backdrop(scope, props)
    return scope:New("TextButton")({
        Name = "Backdrop",
        Text = "",
        AutoButtonColor = false,
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = props.Transparency or 0.45,
        Size = UDim2.fromScale(1, 1),
        Selectable = false,
        [OnEvent("Activated")] = props.OnClick,
    })
end

-- Image from AssetConfig.Images by key (Blender renders), falling back to emoji text.
local AssetConfig = require(ReplicatedStorage.Config.AssetConfig)
function UI.Icon(scope, props)
    local function ImageFor(sKey)
        local iId = AssetConfig.Images[sKey]
        return if iId then "rbxassetid://" .. iId else ""
    end
    local vImage = if typeof(props.Key) == "string" then ImageFor(props.Key) else scope:Computed(function(use)
        return ImageFor(use(props.Key))
    end)
    return scope:New("ImageLabel")({
        Name = props.Name or "Icon",
        BackgroundTransparency = 1,
        Image = vImage,
        ImageColor3 = props.Tint,
        ScaleType = Enum.ScaleType.Fit,
        Size = props.Size or UDim2.fromOffset(120, 120),
        Position = props.Position,
        AnchorPoint = props.AnchorPoint,
        ZIndex = props.ZIndex,
        LayoutOrder = props.LayoutOrder,
        [Children] = props[Children],
    })
end

-- Selects a GuiObject for gamepad navigation if a gamepad is in use.
function UI.FocusForGamepad(oObject: GuiObject?)
    if oObject and UserInputService.GamepadEnabled then
        GuiService.SelectedObject = oObject
    end
end

return UI
