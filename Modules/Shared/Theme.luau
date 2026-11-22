--!strict
--[[
    Theme
    -----
    Design-system tokens from Docs/UI/DesignSystem.md. Every Gui component
    reads colours, fonts, radii and strokes from here; change a token here,
    not in a screen.
]]

local Theme = {}

local function hex(s: string): Color3
    return Color3.fromHex(s)
end

Theme.Ink = hex("1E1B2E")
Theme.White = hex("FFFFFF")
Theme.Panel = hex("F4F1EA")
Theme.PanelDeep = hex("E4DDCF")
Theme.Cash = hex("5CFF5C")
Theme.Power = hex("FFE14D")

-- Button colour variants: { Light, Dark } for the vertical gradient.
Theme.Variants = {
    Green = { hex("3DDC4E"), hex("1FA82F") },
    Blue = { hex("3FB8FF"), hex("1C86E0") },
    Gold = { hex("FFD23F"), hex("F5A200") },
    Orange = { hex("FFA62B"), hex("F07800") },
    Red = { hex("FF4B4B"), hex("D11A1A") },
    Purple = { hex("B266FF"), hex("7C2BE0") },
    Grey = { hex("8A8797"), hex("5E5B6B") },
}

Theme.Mutation = {
    Normal = hex("FFFFFF"),
    Golden = hex("FFC531"),
    Frost = hex("9FE3FF"),
    Magma = hex("FF4D1A"),
    Toxic = hex("9BE22D"),
    Cosmic = hex("B266FF"),
}

Theme.Rarity = {
    Common = hex("B0BEC5"),
    Rare = hex("3FB8FF"),
    Legendary = hex("FFC531"),
}

Theme.Size = {
    Tiny = hex("B0BEC5"),
    Normal = hex("FFFFFF"),
    Big = hex("7ED957"),
    Huge = hex("FFA62B"),
    Colossal = hex("FF4B4B"),
}

Theme.Display = Font.fromEnum(Enum.Font.FredokaOne)
Theme.Body = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)

Theme.Radius = { Button = 14, Card = 16, Modal = 20 }
Theme.Stroke = { Button = 3, Card = 3, Modal = 4, Text = 3 }
Theme.Lip = 5

return Theme
