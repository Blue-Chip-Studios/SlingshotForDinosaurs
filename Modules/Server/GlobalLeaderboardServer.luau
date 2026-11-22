--[[
    GlobalLeaderboardServer
    -----------------------
    Two physical boards on the rim (Best Distance, Top Earners) backed by
    OrderedDataStores. Scores are written for each player every few
    minutes and on leave (only when changed); boards refresh every 90 s.
    All DataStore calls are pcall'd so an outage never breaks gameplay.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Module = require(ReplicatedStorage.Shared.Module)
local CanyonMath = require(ReplicatedStorage.Shared.CanyonMath)
local Format = require(ReplicatedStorage.Shared.Format)
local Theme = require(ReplicatedStorage.Shared.Theme)

local PlayerDataServer = require(ServerStorage.ServerModules.PlayerDataServer)

local BOARDS = {
    { Key = "BestDistance", Title = "🏆 FARTHEST LAUNCH", Store = "SFD_BestDistance_v1", Format = Format.Meters, Position = Vector3.new(-62, 0, 128), Color = Theme.Variants.Blue[2] },
    { Key = "Income", Title = "💵 TOP EARNERS", Store = "SFD_Income_v1", Format = function(n) return Format.Cash(n) .. "/s" end, Position = Vector3.new(62, 0, 128), Color = Theme.Variants.Green[2] },
}
local WRITE_INTERVAL = 180
local READ_INTERVAL = 90
local ROWS = 10

local tStores = {}
local tLastWritten: { [Player]: { [string]: number } } = {}
local tNames: { [number]: string } = {}
local tLists: { [string]: Frame } = {}

local function Value(oPlayer: Player, sKey: string): number
    if sKey == "Income" then
        return math.floor(oPlayer:GetAttribute("Income") or 0)
    end
    return math.floor(PlayerDataServer:Get(oPlayer, sKey) or 0)
end

local function NameOf(iUserId: number): string
    if tNames[iUserId] then return tNames[iUserId] end
    local bOk, sName = pcall(Players.GetNameFromUserIdAsync, Players, iUserId)
    tNames[iUserId] = if bOk then sName else "Player"
    return tNames[iUserId]
end

local function BuildBoard(t)
    local nY = CanyonMath.RimY
    local oBoard = Instance.new("Part")
    oBoard.Name = "Leaderboard_" .. t.Key
    oBoard.Anchored = true
    oBoard.Size = Vector3.new(26, 30, 1.5)
    oBoard.CFrame = CFrame.lookAt(t.Position + Vector3.new(0, nY + 17, 0), t.Position + Vector3.new(0, nY + 17, -10))
    oBoard.Color = Theme.Ink
    oBoard.Material = Enum.Material.SmoothPlastic
    for _, nSide in { -1, 1 } do
        local oPost = Instance.new("Part")
        oPost.Anchored = true
        oPost.Size = Vector3.new(1.5, 32, 1.5)
        oPost.CFrame = oBoard.CFrame * CFrame.new(nSide * 13.5, -1, 0.5)
        oPost.Color = Color3.fromHex("A0703F")
        oPost.Material = Enum.Material.Wood
        oPost.Parent = oBoard
    end
    local oGui = Instance.new("SurfaceGui")
    oGui.Face = Enum.NormalId.Front
    oGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    oGui.PixelsPerStud = 25
    oGui.LightInfluence = 0
    local oHeader = Instance.new("TextLabel")
    oHeader.BackgroundColor3 = t.Color
    oHeader.Size = UDim2.new(1, 0, 0.13, 0)
    oHeader.FontFace = Theme.Display
    oHeader.TextScaled = true
    oHeader.TextColor3 = Color3.new(1, 1, 1)
    oHeader.Text = t.Title
    local oStroke = Instance.new("UIStroke")
    oStroke.Color = Theme.Ink
    oStroke.Thickness = 4
    oStroke.Parent = oHeader
    oHeader.Parent = oGui
    local oList = Instance.new("Frame")
    oList.Name = "List"
    oList.BackgroundTransparency = 1
    oList.Position = UDim2.fromScale(0.04, 0.15)
    oList.Size = UDim2.fromScale(0.92, 0.83)
    local oLayout = Instance.new("UIListLayout")
    oLayout.SortOrder = Enum.SortOrder.LayoutOrder
    oLayout.Padding = UDim.new(0.008, 0)
    oLayout.Parent = oList
    oList.Parent = oGui
    oGui.Parent = oBoard
    oBoard.Parent = Workspace:WaitForChild("World")
    tLists[t.Key] = oList
end

local function Refresh(t)
    local oStore = tStores[t.Key]
    local oList = tLists[t.Key]
    if not (oStore and oList) then return end
    local bOk, oPages = pcall(oStore.GetSortedAsync, oStore, false, ROWS)
    if not bOk then return end
    local tEntries = oPages:GetCurrentPage()
    for _, o in oList:GetChildren() do
        if o:IsA("TextLabel") then o:Destroy() end
    end
    for i, tEntry in tEntries do
        local oRow = Instance.new("TextLabel")
        oRow.LayoutOrder = i
        oRow.BackgroundTransparency = 1
        oRow.Size = UDim2.fromScale(1, 0.092)
        oRow.FontFace = Theme.Display
        oRow.TextScaled = true
        oRow.TextXAlignment = Enum.TextXAlignment.Left
        oRow.TextColor3 = if i == 1 then Theme.Variants.Gold[1] elseif i <= 3 then Color3.fromHex("D7E3F0") else Color3.new(1, 1, 1)
        oRow.Text = `#{i}  {NameOf(tonumber(tEntry.key) or 0)}  -  {t.Format(tEntry.value)}`
        oRow.Parent = oList
    end
end

local function Write(oPlayer: Player)
    if not PlayerDataServer:IsReady(oPlayer) then return end
    tLastWritten[oPlayer] = tLastWritten[oPlayer] or {}
    for _, t in BOARDS do
        local n = Value(oPlayer, t.Key)
        if n > 0 and tLastWritten[oPlayer][t.Key] ~= n then
            local bOk = pcall(tStores[t.Key].SetAsync, tStores[t.Key], tostring(oPlayer.UserId), n)
            if bOk then tLastWritten[oPlayer][t.Key] = n end
        end
    end
end

local mBoards = Module()

function mBoards.StartAsync(self)
    for _, t in BOARDS do
        local bOk, oStore = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, t.Store)
        if bOk then tStores[t.Key] = oStore end
        BuildBoard(t)
    end
    Players.PlayerRemoving:Connect(function(oPlayer)
        tLastWritten[oPlayer] = nil
    end)
    task.spawn(function()
        while true do
            for _, t in BOARDS do Refresh(t) end
            task.wait(READ_INTERVAL)
        end
    end)
    while true do
        task.wait(WRITE_INTERVAL)
        for _, oPlayer in Players:GetPlayers() do
            Write(oPlayer)
        end
    end
end

function mBoards.PlayerRemoving(self, oPlayer: Player)
    Write(oPlayer) -- profile still loaded here
end

return mBoards
