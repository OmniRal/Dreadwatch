-- OmniRal
--!nocheck

local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local CustomEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local QuestBoard = {}
QuestBoard.__index = QuestBoard

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------
-- Private API --
-----------------



------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------
-- Public API --
----------------

function QuestBoard.new(Board: Model)
    local Module = script:FindFirstChild(Board.Name)
    if not Module then return end

    local self: CustomEnum.QuestBoard = setmetatable({}, QuestBoard)
    self.Model = Board
    self.Module = require(Module)
    self.Quests = {}
    self.Details = {}

    self.Module.Init(self)
end

function QuestBoard:Spawn()
    local self: CustomEnum.QuestBoard = self

    if not self.Module then return end
    self.Module.Spawn(self)
end

function QuestBoard:Start()
    local self: CustomEnum.QuestBoard = self

    if not self.Module then return end
    self.Module.Start(self)
end

function QuestBoard:Drop()
    local self: CustomEnum.QuestBoard = self

    if not self.Module then return end
    self.Module.Drop(self)
end

function QuestBoard:Complete()
    local self: CustomEnum.QuestBoard = self

    if not self.Module then return end
    self.Module.Complete(self)
end

function QuestBoard:Clean()
    local self: CustomEnum.QuestBoard = self

    if not self.Module then return end
    self.Module.Clean(self)
end

return QuestBoard