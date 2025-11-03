-- OmniRal

local ObjectService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)
local New = require(ReplicatedStorage.Source.Pronghorn.New)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local CustomEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum)
local ItemInfo = require(ReplicatedStorage.Source.SharedModules.Info.ItemInfo)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Assets = ServerStorage.Assets
local RNG = Random.new()

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------
-- Private API --
-----------------

local function RunSpawning()
    task.spawn(function()
        while true do
            task.wait(1)
            if #Workspace.Items:GetChildren() > 3 then return end

            local Part = Workspace.CrateSpawner
            local SpawnHere = Part.CFrame * CFrame.new(RNG:NextInteger(-Part.Size.X / 2, Part.Size.X / 2), 0, RNG:NextInteger(-Part.Size.Z / 2, Part.Size.Z / 2))
            ObjectService:SpawnCrate(SpawnHere, ItemInfo.NormalCrate)
        end
    end)
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------
-- Public API --
----------------

function ObjectService:SpawnCrate(CF: CFrame, Crate: CustomEnum.Crate, Pickups: {{PickupType: CustomEnum.Pickup, Amount: number | NumberRange}}?, Health: number?)
    if not CF or not Crate then return end
    local CrateModels = Assets.Items.Crates[Crate.Name]
    local NewCrate = CrateModels:GetChildren()[RNG:NextInteger(1, #CrateModels:GetChildren())]:Clone() :: Model
    NewCrate:PivotTo(CF)
    NewCrate.Parent = Workspace.Items
    Crate.Setup(NewCrate)
end

function ObjectService:Init()
    --RunSpawning()
end

return ObjectService