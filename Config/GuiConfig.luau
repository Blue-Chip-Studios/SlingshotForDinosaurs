--[[
    GuiConfig
    ---------
    What LMGui mounts on startup and the shared Fusion Store values every
    screen can read (Store.Values.<Name>).

        ConstantGuis: screens auto-mounted on client start (props table).
        Values:       initial seeds for Store.Values.
        GuiFolder:    where LMGui finds screen modules (ReplicatedStorage.Gui).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Screens auto-mounted on client start: [sGuiName] = tProps
local tConstantGuis = {
}

local tValues = {
}

-- Add a typed field here for each entry in tValues.
export type Values = { [string]: any }

return {
    ConstantGuis = tConstantGuis,
    Values = tValues,
    GuiFolder = ReplicatedStorage.Gui,
}
