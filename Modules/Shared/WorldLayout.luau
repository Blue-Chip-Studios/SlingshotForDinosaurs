--!strict
--[[
    WorldLayout
    -----------
    Where everything on the launch rim lives. Shared so the server (world
    building, validation) and the client (guidance arrows, cameras) agree.

    The rim is a plateau at CanyonMath.RimY. Its front edge is at
    CanyonMath.CanyonStartZ, overlooking the canyon that runs along -Z.
    Eight plots sit in a row along the edge; the training station and shop
    pedestals sit behind them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CanyonMath = require(ReplicatedStorage.Shared.CanyonMath)
local ShopConfig = require(ReplicatedStorage.Config.ShopConfig)

local WorldLayout = {}

local nY = CanyonMath.RimY
local nEdgeZ = CanyonMath.CanyonStartZ

WorldLayout.RimMinX = -200
WorldLayout.RimMaxX = 200
WorldLayout.RimMinZ = nEdgeZ
WorldLayout.RimMaxZ = 150

WorldLayout.PlotWidth = 40
WorldLayout.PlotDepth = 56
WorldLayout.PlotSpacing = 44

-- Plot i (1..8): enclosure centre, the launch stand at its front edge, and the spawn point.
function WorldLayout.Plot(i: number)
    local nX = -154 + (i - 1) * WorldLayout.PlotSpacing
    local nFrontZ = nEdgeZ + 8
    local vCenter = Vector3.new(nX, nY, nFrontZ + 6 + WorldLayout.PlotDepth / 2)
    return {
        Center = vCenter,
        Size = Vector3.new(WorldLayout.PlotWidth, 1, WorldLayout.PlotDepth),
        LaunchStand = Vector3.new(nX, nY, nFrontZ),
        Spawn = CFrame.lookAt(Vector3.new(nX, nY + 3, nFrontZ + 3), Vector3.new(nX, nY + 3, nFrontZ - 50)),
    }
end

-- Point a dino stands at inside plot i (deterministic per dino id so it doesn't jump on refresh).
function WorldLayout.DinoSpot(iPlot: number, iSlot: number, iSlots: number): Vector3
    local tPlot = WorldLayout.Plot(iPlot)
    local iColumns = 3
    local iRows = math.max(1, math.ceil(iSlots / iColumns))
    local iCol = (iSlot - 1) % iColumns
    local iRow = (iSlot - 1) // iColumns
    local nX = tPlot.Center.X + (iCol - 1) * (WorldLayout.PlotWidth / 3.2)
    local nZ = tPlot.Center.Z - WorldLayout.PlotDepth / 2 + 10 + iRow * ((WorldLayout.PlotDepth - 16) / math.max(1, iRows - 1 + 0.0001))
    return Vector3.new(nX, nY, math.min(nZ, tPlot.Center.Z + WorldLayout.PlotDepth / 2 - 6))
end

-- Training pads (index matches ShopConfig.Pads).
WorldLayout.PadSize = Vector3.new(18, 1, 18)
function WorldLayout.Pad(i: number): Vector3
    local iCount = #ShopConfig.Pads
    local nX = (i - (iCount + 1) / 2) * 26
    return Vector3.new(nX, nY, 60)
end
WorldLayout.TrainingSign = Vector3.new(0, nY, 80)

-- Shop pedestals: slingshots on the left, bait on the right.
function WorldLayout.SlingshotPedestal(i: number): Vector3
    return Vector3.new(-170 + (i - 1) * 18, nY, 105)
end
function WorldLayout.BaitPedestal(i: number): Vector3
    return Vector3.new(60 + (i - 1) * 20, nY, 105)
end

-- Player is "on the rim" (allowed to launch) if inside this box.
function WorldLayout.IsOnRim(vPosition: Vector3): boolean
    return vPosition.X >= WorldLayout.RimMinX and vPosition.X <= WorldLayout.RimMaxX
        and vPosition.Z >= WorldLayout.RimMinZ - 6 and vPosition.Z <= WorldLayout.RimMaxZ
        and vPosition.Y > nY - 6 and vPosition.Y < nY + 40
end

function WorldLayout.PadAt(vPosition: Vector3): number?
    for i = 1, #ShopConfig.Pads do
        local vPad = WorldLayout.Pad(i)
        local vDelta = vPosition - vPad
        if math.abs(vDelta.X) <= WorldLayout.PadSize.X / 2 + 1 and math.abs(vDelta.Z) <= WorldLayout.PadSize.Z / 2 + 1 and vDelta.Y > -2 and vDelta.Y < 8 then
            return i
        end
    end
    return nil
end

return WorldLayout
