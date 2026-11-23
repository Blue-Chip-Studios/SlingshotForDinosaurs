--[[
    SprintController
    ----------------
    Run faster around the rim, park and shop.
        Keyboard   hold Shift
        Gamepad    click the left stick (toggles), or hold the stick fully over for half a second
        Touch      push the thumbstick all the way out for half a second
    Speed eases up and down so it never snaps. Roblox's Shift-Lock option is turned off in
    default.project.json (StarterPlayer.EnableMouseLockOption) so Shift is free for running.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Module = require(ReplicatedStorage.Shared.Module)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)

local tSprint = GameConfig.Sprint
local bShift = false          -- keyboard Shift held
local bToggle = false         -- gamepad L3 toggle
local nFullTiltSince: number? = nil

local function OnSprintKey(_, eState: Enum.UserInputState, oInput: InputObject)
    if oInput.KeyCode == Enum.KeyCode.ButtonL3 then
        if eState == Enum.UserInputState.Begin then bToggle = not bToggle end
    else
        bShift = eState == Enum.UserInputState.Begin
    end
    return Enum.ContextActionResult.Pass
end

local mSprint = Module()

function mSprint.StartAsync(self)
    ContextActionService:BindAction("SFD_Sprint", OnSprintKey, false, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3)
    local nSpeed = tSprint.Walk
    RunService.Heartbeat:Connect(function(nDt)
        local oCharacter = Players.LocalPlayer.Character
        local oHumanoid = oCharacter and oCharacter:FindFirstChildOfClass("Humanoid")
        if not oHumanoid or oHumanoid.Health <= 0 then return end
        local nTilt = oHumanoid.MoveDirection.Magnitude
        local eLast = UserInputService:GetLastInputType()
        local bAnalogue = eLast == Enum.UserInputType.Touch or eLast == Enum.UserInputType.Gamepad1
        -- Analogue sticks: a full push held briefly breaks into a run (keyboard WASD is always "full").
        if bAnalogue and nTilt > 0.93 then
            nFullTiltSince = nFullTiltSince or os.clock()
        else
            nFullTiltSince = nil
        end
        if nTilt < 0.1 then bToggle = false end   -- stopping ends a toggled run
        local bRun = nTilt > 0.1 and (bShift or bToggle or (nFullTiltSince ~= nil and os.clock() - nFullTiltSince > tSprint.TiltDelay))
        local nGoal = if bRun then tSprint.Run else tSprint.Walk
        nSpeed += (nGoal - nSpeed) * math.min(1, nDt * tSprint.Ease)
        if math.abs(oHumanoid.WalkSpeed - nSpeed) > 0.05 then
            oHumanoid.WalkSpeed = nSpeed
        end
    end)
end

return mSprint
