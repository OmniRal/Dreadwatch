-- OmniRal
--!nocheck

local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local CustomEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local GenericContractBoard: CustomEnum.QuestBoardModule = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local RNG = Random.new()

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------
-- Private API --
-----------------



------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------
-- Public API --
----------------

GenericContractBoard.Init = function(QuestBoard: CustomEnum.QuestBoard)
    if not QuestBoard then return end
    if not QuestBoard.Model then return end

    local OGContract = QuestBoard.Model:FindFirstChild("OGContract")
    if not OGContract then return end

    QuestBoard.Details.OGContract = OGContract
    QuestBoard.Details.OGContract.Parent = nil
end

GenericContractBoard.Spawn = function(QuestBoard: CustomEnum.QuestBoard, Quest: CustomEnum.Quest)
    if not QuestBoard then return end
    if not QuestBoard.Details then return end
    if not QuestBoard.Details.OGContract then return end

    local Board = QuestBoard.Model.Board
    local NewContract = Quest.Details.OGContract:Clone()
    NewContract:PivotTo(Board.CFrame * CFrame.new(RNG:NextInteger(-Board.Size.X / 2, Board.Size.X / 2), RNG:NextInteger(-Board.Size.Y / 2, Board.Size.Y / 2), -0.5))
    NewContract.Parent = QuestBoard.Model
end



return GenericContractBoard