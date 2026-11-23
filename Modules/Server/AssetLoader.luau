--[[
    AssetLoader
    -----------
    Loads the pipeline's Model assets (Config/AssetConfig) with
    InsertService at server start and places normalised templates in
    ReplicatedStorage.Assets.{Dinos,World}, so both server (WorldBuilder)
    and clients (DinoModels) can clone them. Runs before WorldBuilder builds
    the world (it's required from WorldBuilder.PreloadAsync).

    Normalising: anchored, no collisions on dinos, WorldPivot at the
    bottom-centre of the bounding box facing -Z.
]]

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetConfig = require(ReplicatedStorage.Config.AssetConfig)

local AssetLoader = {}

local bLoaded = false

local function Folder(oParent: Instance, sName: string): Folder
    local o = oParent:FindFirstChild(sName)
    if not o then
        o = Instance.new("Folder")
        o.Name = sName
        o.Parent = oParent
    end
    return o :: Folder
end

local function Load(iAssetId: number, sName: string, bCollide: boolean): Model?
    local bOk, oContainer = pcall(InsertService.LoadAsset, InsertService, iAssetId)
    if not bOk then
        warn(`[AssetLoader] could not load {sName} ({iAssetId}): {oContainer}`)
        return nil
    end
    local oSource = oContainer:FindFirstChildWhichIsA("Model") or oContainer
    local oModel = Instance.new("Model")
    oModel.Name = sName
    for _, o in oSource:GetChildren() do
        o.Parent = oModel
    end
    oContainer:Destroy()
    for _, o in oModel:GetDescendants() do
        if o:IsA("BasePart") then
            o.Anchored = true
            o.CanCollide = bCollide
            o.CanTouch = false
            o.CanQuery = bCollide
        end
    end
    local cfBox, vSize = oModel:GetBoundingBox()
    oModel.WorldPivot = CFrame.new(cfBox.Position - Vector3.new(0, vSize.Y / 2, 0))
    return oModel
end

-- Loads every configured model once, all in parallel, waiting at most nTimeout seconds.
-- Anything still loading after the timeout keeps loading in the background; callers
-- fall back to TEMP stand-ins for it. Safe to call more than once.
function AssetLoader.LoadAll(nTimeout: number?)
    if bLoaded then return end
    bLoaded = true
    local oAssets = Folder(ReplicatedStorage, "Assets")
    local oDinos = Folder(oAssets, "Dinos")
    local oWorld = Folder(oAssets, "World")
    local oCritters = Folder(oAssets, "Critters")
    local iPending = 0
    local function Queue(tList, oFolder: Folder, bCollide: boolean)
        for sName, iId in tList do
            if not oFolder:FindFirstChild(sName) then
                iPending += 1
                task.spawn(function()
                    local oModel = Load(iId, sName, bCollide)
                    if oModel then oModel.Parent = oFolder end
                    iPending -= 1
                end)
            end
        end
    end
    Queue(AssetConfig.Dinos, oDinos, false)
    Queue(AssetConfig.World, oWorld, true)
    Queue(AssetConfig.Critters, oCritters, false)
    local nStart = os.clock()
    while iPending > 0 and os.clock() - nStart < (nTimeout or 8) do
        task.wait(0.05)
    end
    if iPending > 0 then
        warn(`[AssetLoader] {iPending} assets still loading after {nTimeout or 8}s; using stand-ins for now`)
    end
end

return AssetLoader
