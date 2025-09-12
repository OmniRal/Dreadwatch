--OmniRal

local CharacterService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)
local New = require(ReplicatedStorage.Source.Pronghorn.New)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local CustomEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum)

local DataService = require(ServerScriptService.Source.ServerModules.Top.DataService)
--local WorldUIService = require(ReplicatedStorage.Source.SharedModules.UI.WorldUIService)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Assets = ServerStorage.Assets
local SharedAssets = ReplicatedStorage.Assets

local Sides = {-1, 1}
local RNG = Random.new()

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------
-- Private API --
-----------------

function TestButtons()

end

local function AddNewAnimateScript(Character: Model)
    if not Character then return end

    task.spawn(function()
        local Animate = Character:WaitForChild("Animate")
        Animate:Destroy()
        
        task.wait()
        
        local NewAnimate = ReplicatedStorage.Assets.Player.Animate:Clone()
        NewAnimate.Parent = Character
    end)
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------
-- Public API --
----------------

function CharacterService:LoadCharacter(Player: Player)
    task.spawn(function()
        while Player.Character == nil do task.wait() end

        local Character = Player.Character
        if Character:GetAttribute("Loaded") then return end
        Character:SetAttribute("Loaded", true)

        local Human, Root = Character:WaitForChild("Humanoid"), Character:WaitForChild("HumanoidRootPart")

        for _, Part in pairs(Character:GetDescendants()) do
            if Part:IsA("BasePart") then
                Part.CollisionGroup = "Players"
            end
        end

        --AddNewAnimateScript(Character)
    end)
end

function CharacterService:Init()
    TestButtons()
end

return CharacterService