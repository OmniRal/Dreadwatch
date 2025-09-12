-- OmniRal
--!nocheck

local QuestService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local CustomEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum)
local DataService = require(ServerScriptService.Source.ServerModules.Top.DataService)

local Quest = require(ServerScriptService.Source.ServerModules.Classes.Quest)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Quests: {[string]: CustomEnum.Quest} = {}
local Boards: {
    [Model]: {
        {Quest: string, Display: Model}
    }
} = {}

local RunSystem: RBXScriptConnection? = nil

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------
-- Private API --
-----------------

local function GetQuestBoards()
    for _, Board in CollectionService:GetTagged("QuestBoard") do
        if not Board then continue end
        Boards[Board] = {}
    end
end

local function RunQuests()
    for Name, Quest in Quests do
        if not Quest then continue end
        local AtleastOne, _ = QuestService:CheckPlayersInGame(Quest.Players)
        if not AtleastOne then return end
    end
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------
-- Public API --
----------------

function QuestService:CheckPlayersInGame(List: {Players}): (boolean?, {Player}?)
    if not List then return end

    local AtleastOne = false
    local NewList: {Player} = {}

    for _, Player in List do
        if not Players:FindFirstChild(Player.Name) then continue end

        AtleastOne = true
        table.insert(NewList, Player)
    end

    return AtleastOne, NewList
end

function QuestService:CheckPlayerEligable(Module: CustomEnum.QuestModule, Player: Player)
    if not Module or not Player then return end
    if not Module.Requirements then return end

    local PlayerData = DataService:GetProfileTable(Player)
    if not PlayerData then return end

    if PlayerData.Level < Module.Requirements.Level then return false end
    if #Module.Requirements.Quests <= 0 then return true end
    
    local HasOtherComplete = true
    for _, Name in Module.Requirements.Quests do
        if not Name then continue end
        if table.find(PlayerData.Quests.Complete, Name) then continue end
        HasOtherComplete = false
        break
    end

    return HasOtherComplete
end

function QuestService:CreateQuest(Name: string, Players: {})
    local Constructor: CustomEnum.QuestConstructor = {}
    Constructor.Name = ""
    Constructor.Players = {}

    Quest.new(Constructor)
end

function QuestService:Run()
    QuestService:Stop()

    RunService.Heartbeat:Connect(function(DeltaTime: number)
        RunQuests()
    end)
end

function QuestService:Stop()
    if not RunSystem then return end
    RunSystem:Disconnect()
    RunSystem = nil
end

function QuestService:Init()
    GetQuestBoards()
end

function QuestService:Deferred()
    QuestService:Run()
end

return QuestService