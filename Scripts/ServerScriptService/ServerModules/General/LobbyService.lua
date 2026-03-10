-- OmniRal

local LobbyService = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local CustomEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum)
local ServerGlobalValues = require(ServerScriptService.Source.ServerModules.Top.ServerGlobalValues)

local RoomPadService = require(ServerScriptService.Source.ServerModules.General.RoomPadService)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Remotes
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Loaded = false

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function CheckHaveAllPlayers(Info: CustomEnum.TeleportInfo): boolean
    local GotPlayers = {}
    for _, Player in Players:GetPlayers() do
        if not Player then continue end

        for n, Expected in ipairs(Info.ExpectedPlayers) do
            if not Expected then continue end
            if Player.Name ~= Expected.Name or Player.UserId ~= Expected.ID then
                -- May need to kick this player?
                continue
            end

            table.insert(GotPlayers, Player)

            if n == 1 and not ServerGlobalValues.PartyLeader then
                ServerGlobalValues.PartyLeader = Player
                Player:SetAttribute("PartyLeader", true)
            end
        end
    end

    if #GotPlayers < #Info.ExpectedPlayers then return false end

    ServerGlobalValues.LevelPlayers = GotPlayers

    return true
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Decide if the place will be a lobby or a level based on the first players join data
-- If returns TRUE without a LevelID, it means the game is waiting for all players to load; delete the lobby
function LobbyService.CheckLoadLevel(Player: Player): (boolean, number?)
    if not Player then return false end

    if ServerGlobalValues.StartLevelInfo.TestingMode then
        if not ServerGlobalValues.StartLevelInfo.TestWithoutPlayers then
            if not CheckHaveAllPlayers(ServerGlobalValues.StartLevelInfo) then return true end
            return true, ServerGlobalValues.StartLevelInfo.ID
        end

        return true, ServerGlobalValues.StartLevelInfo.ID
    end

    local JoinData = Player:GetJoinData()
    if not JoinData then
        -- No join data exists, assume its a lobby
        return false
    end

    print("Got join data from", Player, " :", JoinData)

    local TeleportInfo: CustomEnum.TeleportInfo = JoinData.TeleportInfo
    if not TeleportInfo then return false end
    if not TeleportInfo.MissionID or not TeleportInfo.ExpectedPlayers then return false end
    if not CheckHaveAllPlayers(TeleportInfo) then return true end

    -- May need fail safe here if a players teleport data is corrupted; send them back to their lobby ideally

    return true, TeleportInfo.MissionID
end

function LobbyService.Load()
    if Loaded then return end

    Loaded = true
    RoomPadService.GetAllPads()
end

return LobbyService