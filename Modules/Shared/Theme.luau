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

Theme.Ink = hex("141218")
Theme.White = hex("FFFFFF")
-- Window body / cards: cool light greys (ref 04), framed by Ink.
Theme.Panel = hex("ECEDF2")
Theme.PanelDeep = hex("CFD1DC")
Theme.Cash = hex("6BFF3D")
Theme.Power = hex("FFE14D")

-- Button colour variants: { Face, Base }. Flat, saturated faces (refs 01/06) with a
-- darker same-hue base underneath instead of a black lip.
Theme.Variants = {
    Green = { hex("52E52F"), hex("2A9E14") },
    Blue = { hex("2FC2FF"), hex("1577C9") },
    Gold = { hex("FFD91F"), hex("D69A00") },
    Orange = { hex("FF9F1C"), hex("C96500") },
    Red = { hex("FF3B3B"), hex("B31212") },
    Purple = { hex("A95CFF"), hex("6A22C9") },
    Grey = { hex("9A9AAA"), hex("5C5C6E") },
    Teal = { hex("1FE0C8"), hex("0D8F80") },
    Pink = { hex("FF5FB8"), hex("BF2479") },
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

-- Squarer, chunkier shapes (refs 01/04/06) rather than soft capsules.
Theme.Radius = { Button = 6, Card = 8, Modal = 10 }
Theme.Stroke = { Button = 3.5, Card = 3, Modal = 5, Text = 3 }
Theme.Lip = 6

return Theme
