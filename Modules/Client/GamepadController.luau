--[[
    GamepadController
    -----------------
    Console/controller access to the HUD, which otherwise needs Roblox's hidden
    "press View to select UI" behaviour:
      * D-pad Left  -> selects the left menu (Shop, Rewards, Quests, ...)
      * D-pad Right -> selects the right column (limited dino, storm, rerolls, ...)
      * D-pad Down  -> leaves menu selection (back to playing)
    Once selected, Roblox's normal gamepad navigation moves between buttons and
    A presses them. Modals focus themselves and close with B (Modals.luau).
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Module = require(ReplicatedStorage.Shared.Module)
local Store = require(ReplicatedStorage.BCDKClient.LMGui.Store)
local Fusion = require(ReplicatedStorage.Packages.fusion)

local peek = Fusion.peek
local oPlayer = Players.LocalPlayer

local function FirstVisibleButton(sStack: string): GuiObject?
    local oHud = oPlayer.PlayerGui:FindFirstChild("HUD")
    local oStack = oHud and oHud:FindFirstChild(sStack, true)
    if not oStack then return nil end
    local oBest: GuiObject? = nil
    for _, o in oStack:GetDescendants() do
        if o:IsA("GuiButton") and o.Visible and o.Selectable then
            if not oBest or o.AbsolutePosition.Y < oBest.AbsolutePosition.Y then
                oBest = o
            end
        end
    end
    return oBest
end

local mGamepad = Module()

function mGamepad.StartAsync(self)
    ContextActionService:BindAction("SFD_GamepadMenu", function(_, eState, oInput)
        if eState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
        -- Leave D-pad alone while a modal is open (it navigates inside the modal) or mid-flight.
        if peek(Store.Values.Modal) ~= "" or peek(Store.Values.Flying) then
            return Enum.ContextActionResult.Pass
        end
        local eKey = oInput.KeyCode
        if eKey == Enum.KeyCode.DPadDown and GuiService.SelectedObject then
            GuiService.SelectedObject = nil
            return Enum.ContextActionResult.Sink
        end
        if GuiService.SelectedObject then
            return Enum.ContextActionResult.Pass -- already navigating: let Roblox move the selection
        end
        local oTarget = if eKey == Enum.KeyCode.DPadLeft then FirstVisibleButton("LeftStack")
            elseif eKey == Enum.KeyCode.DPadRight then FirstVisibleButton("RightStack")
            else nil
        if oTarget then
            GuiService.SelectedObject = oTarget
            return Enum.ContextActionResult.Sink
        end
        return Enum.ContextActionResult.Pass
    end, false, Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadRight, Enum.KeyCode.DPadDown)
end

return mGamepad
