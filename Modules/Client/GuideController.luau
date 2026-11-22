--[[
    GuideController
    ---------------
    FTUE guidance and world interaction:
      * Shows the next FTUE hint (Store.Hint) and a glowing beam from the
        player to the next goal (launch stand, training pad, pedestal).
      * Opens the shop on a pedestal's ProximityPrompt.
      * Queues server announcements and purchase confirmations as toasts.
      * Spins pedestal items.
    Progress is server-persisted (FTUEStep), so rejoining resumes correctly.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local Module = require(ReplicatedStorage.Shared.Module)
local Remote = require(ReplicatedStorage.BCDKShared.Remote)
local Store = require(ReplicatedStorage.BCDKClient.LMGui.Store)
local peek = require(ReplicatedStorage.Packages.fusion).peek
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local AnalyticsConfig = require(ReplicatedStorage.Config.AnalyticsConfig)
local ShopConfig = require(ReplicatedStorage.Config.ShopConfig)
local MonetizationConfig = require(ReplicatedStorage.Config.MonetizationConfig)
local DataClient = require(ReplicatedStorage.ClientModules.DataClient)
local SoundController = require(ReplicatedStorage.ClientModules.SoundController)

local oPlayer = Players.LocalPlayer
local STEPS = AnalyticsConfig.OnboardingSteps
local iAnnouncementId = 0

local oBeam: Beam
local oTargetAttachment: Attachment

local function Announce(sText: string, sKind: string, sMutation: string?)
    iAnnouncementId += 1
    local tQueue = table.clone(peek(Store.Values.Announcements))
    table.insert(tQueue, { Id = iAnnouncementId, Text = sText, Kind = sKind, Mutation = sMutation })
    if #tQueue > 3 then table.remove(tQueue, 1) end
    Store.Values.Announcements:set(tQueue)
    local iId = iAnnouncementId
    task.delay(4, function()
        local tNow = table.clone(peek(Store.Values.Announcements))
        for i, t in tNow do
            if t.Id == iId then
                table.remove(tNow, i)
                break
            end
        end
        Store.Values.Announcements:set(tNow)
    end)
end

-- Which goal the FTUE points at now: (hint text, world position or nil).
local function CurrentGoal(): (string, Vector3?)
    local iStep = DataClient:Get("FTUEStep") or 0
    local iPlot = oPlayer:GetAttribute("PlotIndex")
    if iStep < STEPS.FirstLaunch then
        local bPad = GuiService:IsTenFootInterface() or UserInputService:GetLastInputType().Name:sub(1, 7) == "Gamepad"
        return if bPad then "HOLD R2 to pull, RELEASE to launch!" else "HOLD to pull, LET GO to launch!", iPlot and WorldLayout.Plot(iPlot).LaunchStand
    elseif iStep < STEPS.FirstTrain then
        if iStep >= STEPS.FirstPlacement then
            return "Stand on a TRAINING PAD to get stronger!", WorldLayout.Pad(1)
        end
        return "", nil
    elseif iStep < STEPS.FirstUpgrade then
        local nCash = DataClient:Get("Cash") or 0
        if nCash >= ShopConfig.Slingshots[2].Price then
            return "Buy the BAMBOO SLINGSHOT to launch further!", WorldLayout.SlingshotPedestal(2)
        end
        return "Launch again to earn cash for a better slingshot!", iPlot and WorldLayout.Plot(iPlot).LaunchStand
    end
    return "", nil
end

local mGuide = Module()

function mGuide.PreloadAsync(self)
    Remote:GetEvent("Announcement"):OnClientEvent(function(t)
        Announce(t.Text, t.Kind, t.Mutation)
        if t.Kind == "Event" then
            SoundController:Play("Event")
        elseif t.Kind == "Catch" then
            SoundController:Play("Perfect")
        end
    end)
    Remote:GetEvent("PurchaseResult"):OnClientEvent(function(t)
        if not t.Ok then
            if typeof(t.Reason) == "string" then
                Announce(t.Reason, "Event")
                SoundController:Play("Error")
            end
            return
        end
        local tItem = MonetizationConfig.Products[t.Key] or MonetizationConfig.Passes[t.Key]
        local sSim = if t.Simulated then " (Studio test)" else ""
        Announce(`Thanks! {tItem and tItem.Name or t.Key} unlocked{sSim}`, "Purchase")
        SoundController:Play("Reveal")
    end)
end

function mGuide.StartAsync(self)
    -- Beam from the character to the current goal.
    local oTargetPart = Instance.new("Part")
    oTargetPart.Name = "SFD_GuideTarget"
    oTargetPart.Anchored = true
    oTargetPart.CanCollide = false
    oTargetPart.CanQuery = false
    oTargetPart.Transparency = 1
    oTargetPart.Size = Vector3.one
    oTargetPart.Parent = Workspace
    oTargetAttachment = Instance.new("Attachment", oTargetPart)
    oBeam = Instance.new("Beam")
    -- Beams lay textures along their length using the image's vertical axis, and the arrow points at
    -- Attachment0, so the TARGET is Attachment0 and the player Attachment1 (set below).
    oBeam.Texture = "rbxassetid://75997844550545" -- GuideArrow (Assets/Exports/Icons/GuideArrow.png)
    oBeam.TextureMode = Enum.TextureMode.Static
    oBeam.TextureLength = 4
    oBeam.TextureSpeed = -2 -- scroll toward the target (Attachment0)
    oBeam.Width0 = 2.5
    oBeam.Width1 = 2.5
    oBeam.Color = ColorSequence.new(Color3.fromHex("FFE14D"))
    oBeam.LightEmission = 0.8
    oBeam.FaceCamera = true
    oBeam.Attachment0 = oTargetAttachment
    oBeam.Parent = oTargetPart

    -- Pedestal prompts open the shop focused on that item.
    ProximityPromptService.PromptTriggered:Connect(function(oPrompt)
        local oModel = oPrompt:FindFirstAncestorWhichIsA("Model")
        if not oModel or not oModel:GetAttribute("Kind") then return end
        Store.Values.ShopTab:set(oModel:GetAttribute("Kind"))
        Store.Values.ShopFocus:set(oModel:GetAttribute("Tier") or 0)
        Store.Values.Modal:set("Shop")
        SoundController:Play("Click")
    end)

    local nSpin = 0
    RunService.Heartbeat:Connect(function(nDt)
        nSpin += nDt
        -- Guide beam
        local sHint, vGoal = CurrentGoal()
        if peek(Store.Values.Hint) ~= sHint then
            Store.Values.Hint:set(sHint)
        end
        local oCharacter = oPlayer.Character
        local oRoot = oCharacter and oCharacter:FindFirstChild("HumanoidRootPart")
        local bShow = vGoal ~= nil and oRoot ~= nil and not peek(Store.Values.Flying) and peek(Store.Values.Modal) == ""
        if bShow and oRoot and vGoal then
            local oAttachment = oRoot:FindFirstChild("SFD_GuideAttachment") or Instance.new("Attachment")
            oAttachment.Name = "SFD_GuideAttachment"
            oAttachment.Parent = oRoot
            oBeam.Attachment1 = oAttachment :: Attachment
            oTargetPart.Position = vGoal + Vector3.new(0, 2, 0)
            bShow = (oRoot.Position - vGoal).Magnitude > 10
        end
        oBeam.Enabled = bShow
    end)

    -- Spin shop items (cheap: a handful of parts).
    task.spawn(function()
        local oWorld = Workspace:WaitForChild("World")
        local oShop = oWorld:WaitForChild("Shop")
        local tItems = {}
        task.wait(1) -- let streamed pedestal items arrive
        for _, o in oShop:GetDescendants() do
            if (o:IsA("BasePart") or o:IsA("Model")) and o:GetAttribute("Spin") then
                table.insert(tItems, { o, o:GetPivot() })
            end
        end
        RunService.Heartbeat:Connect(function()
            for _, t in tItems do
                local cf = t[2] * CFrame.new(0, math.sin(nSpin * 2) * 0.4, 0) * CFrame.Angles(0, nSpin * 1.2, 0)
                if t[1]:IsA("Model") then
                    (t[1] :: Model):PivotTo(cf)
                else
                    (t[1] :: BasePart).CFrame = cf
                end
            end
        end)
    end)

    -- Toasts clear themselves.
    Store.Values.Toast:set("")
    task.spawn(function()
        local sLast = ""
        while true do
            task.wait(0.2)
            local s = peek(Store.Values.Toast)
            if s ~= "" and s ~= sLast then
                sLast = s
                Announce(s, "Toast")
                SoundController:Play("Error")
                Store.Values.Toast:set("")
                sLast = ""
            end
        end
    end)
end

return mGuide
