-- OmniRal

local RelicService = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)
local New = require(ReplicatedStorage.Source.Pronghorn.New)

local DataService = require(ServerScriptService.Source.ServerModules.Top.DataService)
local AbilityService = require(ServerScriptService.Source.ServerModules.General.AbilityService)
local UnitValuesService = require(ServerScriptService.Source.ServerModules.General.UnitValuesService)
local Utility = require(ReplicatedStorage.Source.SharedModules.Other.Utility)

local CustomEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum)
local UnitEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum.UnitEnum)
local RelicInfo = require(ReplicatedStorage.Source.SharedModules.Info.RelicInfo)

local RelicModules = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local PlayerRelics: {
    [Player]: {
        {Name: string, Last: string, Effect: UnitEnum.Effect?, Cooldown: number, Connection: RBXScriptConnection?}
    }
} = {}

local Events = ServerStorage.Events

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function CreateNewRelicModel(Relic: string, Position: Vector3): boolean?
    local Info = RelicInfo[Relic]
    if not Info then return end

    local NewRelic: Model = New.Instance("Model", Relic, Workspace)
    NewRelic:AddTag("Relic")

    local NewBase = New.Instance("Part", "Base", NewRelic,
        {
            Anchored = true, CanCollide = false, CanQuery = true, CanTouch = false, Color = Color3.fromRGB(200, 255, 255), 
            Material = Enum.Material.Metal, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(Position)
        }
    )

    NewRelic.PrimaryPart = NewBase

    return true
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Equip a relic, add its stat changes, and ability connection
-- @SlotNum : Which slot to add the relic
function RelicService:EquipRelic(Player: Player, SlotNum: number, RelicName: string)
    local P_Relics, Info = PlayerRelics[Player], RelicInfo[RelicName]
    if not P_Relics or not Info then return end

    Remotes.RelicService.Equipped:Fire(Player, RelicName)

        -- Unequip the old relic if it exists
    if P_Relics[SlotNum].Name ~= "None" then
        RelicService:UnequipRelic(Player, SlotNum, P_Relics[SlotNum].Name)
    end
    
    P_Relics[SlotNum].Last = P_Relics[SlotNum].Name
    P_Relics[SlotNum].Name = RelicName
    DataService:SetRelic(Player, SlotNum, RelicName)

    -- Anything past 3 is the backpack; inactive relics
    if SlotNum > 3 then return end

    -- Add relics stat changes
    local EffectDetails: UnitEnum.EffectDetails = {
        Name = Info.Name,
        From = Info.Name,
        Description = Info.Description,
        IsBuff = true,
        Icon = Info.Icon,
        Duration = -1,
        MaxStacks = Info.MaxStacks or 1,
        DoNotDisplay = true,
    }
    local RelicEffect = UnitValuesService:AddEffect(Player, EffectDetails, Info.Attributes, {})
    P_Relics[SlotNum].Effect = RelicEffect

    if not Info.Ability then return end
    
    -- Add the relic as an ability to AbilityService to track its cooldown
    AbilityService:AddNew(Player, RelicName, {[Info.Ability.Type] = {Equipped = true, BaseCooldown = Info.Ability.Cooldown}})

    -- If the relic has a passive, add a connection to check the players history
    if Info.Ability.Type == "Passive" then
        local Module = RelicModules[RelicName]
        if not Module then return end

        P_Relics[SlotNum].Connection = Events.Unit.NewHistoryEntry.Event:Connect(function(Unit: Player, Entry: UnitEnum.HistoryEntry)
            if P_Relics[SlotNum].Name ~= RelicName then return end
            if not Unit or not Entry or not Module then return end
            if not Unit:IsA("Player") then return end
            Module:UsePassive(Player, Entry)
        end)
    end
end

-- Unequip a relic, remove its effect (stat) changes and remove the ability connection
function RelicService:UnequipRelic(Player: Player, SlotNum: number, RelicName: string, IgnoreSetters: boolean?)
    local P_Relics, Info = PlayerRelics[Player], RelicInfo[RelicName]
    if not P_Relics or not Info then return end

    Remotes.RelicService.Unequipped:Fire(Player, RelicName)

    if not IgnoreSetters then 
        P_Relics[SlotNum].Name = "None"
        P_Relics[SlotNum].Last = RelicName
        DataService:SetRelic(Player, SlotNum, "None")
        print("Unequipping")
    end

    -- Clean up the stat changes 
    UnitValuesService:CleanThisEffect(Player, P_Relics[SlotNum].Effect)
    P_Relics[SlotNum].Effect = nil

    -- Disconnect passive ability if exists
    local Connection = PlayerRelics[Player][SlotNum].Connection
    if Connection then
        Connection:Disconnect()
        P_Relics[SlotNum].Connection = nil
    end
end

function RelicService:UseActive(Player: Player, SlotNum: number, ShootFrom: Vector3?, ShootGoal: Vector3?): (number?, number?)
    local Slot = PlayerRelics[Player][SlotNum]
    local Info = RelicInfo[Slot.Name]
    if not Info then return CustomEnum.ReturnCodes.ComplexError, -1 end
    if not Info.Ability then return CustomEnum.ReturnCodes.ComplexError, -2 end
    if Info.Ability.Type == "Passive" then return CustomEnum.ReturnCodes.ComplexError, -3 end
    
    local Module = RelicModules[Slot.Name]
    return Module:UseActive(Player, ShootFrom, ShootGoal)
end

function RelicService:RequestSwapRelics(Player: Player, SlotNum_A: number, SlotNum_B: number): (number?, number?)
    local P_Relics = PlayerRelics[Player]
    if not P_Relics then return end

    local Slot_A = P_Relics[SlotNum_A]
    local Slot_B = P_Relics[SlotNum_B]
    local A_Info, B_Info = RelicInfo[Slot_A.Name], RelicInfo[Slot_B.Name]
    if not A_Info then return CustomEnum.ReturnCodes.ComplexError, -1 end
    if Slot_B.Name ~= "None" and not B_Info then return CustomEnum.ReturnCodes.ComplexError, -2 end

    -- Make sure the DataService approves of the swap
    if not DataService:SwapRelics(Player, SlotNum_A, SlotNum_B) then return CustomEnum.ReturnCodes.ComplexError, -3 end

    RelicService:UnequipRelic(Player, SlotNum_A, A_Info.Name)
    RelicService:EquipRelic(Player, SlotNum_B, A_Info.Name)

    if B_Info then
        RelicService:EquipRelic(Player, SlotNum_A, B_Info.Name)
    end

    return 1
end

-- Player attempts to drop a relic out near them
-- @SlotNum : The relic slot in their data they wish to drop
-- @DropTo : Where to drop it
function RelicService:RequestDropRelic(Player: Player, SlotNum: number, DropTo: Vector3?)
    if not Player or not SlotNum then return end
    local Alive, _, Root = Utility:CheckPlayerAlive(Player)
    if not Alive or not Root then return end

    local Relics = DataService:GetPlayerRelics(Player)
    if not Relics then return end
    if not Relics[SlotNum] then return end
    if Relics[SlotNum] == "None" then return end

    local DropPosition = DropTo
    
    if not DropPosition then
        -- If DropTo was not provided, set DropPosition to be in front of the player
        DropPosition = (Root.CFrame * CFrame.new(0, 0, -10)).Position

    else
        -- If DropTo is too far, bring reduce its distance but keeping it in the same direction
        DropPosition = (CFrame.new(Root.Position, DropPosition) * CFrame.new(0, 0, -10)).Position
    end

    -- Try to drop the relic onto the ground using a raycast
    local Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.FilterDescendantsInstances = {Player.Character, Workspace.Units}
    Params.IgnoreWater = true
    local NewRay, Dropped = Workspace:Raycast(DropPosition + Vector3.new(0, 10, 0), Vector3.new(0, -25, 0), Params), false
    if NewRay then
        if NewRay.Position then
            Dropped = CreateNewRelicModel(Relics[SlotNum], NewRay.Position)
        end
    end

    if not Dropped then return end

    RelicService:UnequipRelic(Player, SlotNum, Relics[SlotNum])

    return true
end

-- Player attempts to pick up / equip a relic that is on the ground
-- @Relic : The model of the relic in the 3D world
function RelicService:RequestPickupRelic(Player: Player, Relic: Model)
    if not Player or not Relic then return end
    local Info = RelicInfo[Relic.Name]
    if not Info then return end

    local Full, OpenSlot = DataService:AreRelicSlotsFull(Player)
    if Full or not OpenSlot then return end

    RelicService:EquipRelic(Player, OpenSlot, Info.Name)

    Relic:Destroy()

    return true
end

function RelicService:Init()
    Remotes:CreateToClient("Equipped", {"string"}, "Reliable")
    Remotes:CreateToClient("Unequipped", {"string"}, "Reliable")
    Remotes:CreateToClient("RelicSlotsUpdated", {"table"}, "Reliable")

    -- Remote to use active ability of a relic
    Remotes:CreateToServer("UseActive", {"number", "Vector3?", "Vector3?"}, "Returns", function(Player: Player, SlotNum: number, ShootFrom: Vector3?, ShootGoal: Vector3?)
        return RelicService:UseActive(Player, SlotNum, ShootFrom, ShootGoal)
    end)

    Remotes:CreateToServer("RequestSwapRelics", {"number", "number"}, "Returns", function(Player: Player, SlotNum_A: number, SlotNum_B: number)
        return RelicService:RequestSwapRelics(Player, SlotNum_A, SlotNum_B)
    end)

    Remotes:CreateToServer("RequestDropRelic", {"number", "Vector3?"}, "Returns", function(Player: Player, SlotNum: number, DropTo: Vector3?)
        return RelicService:RequestDropRelic(Player, SlotNum, DropTo)
    end)

    Remotes:CreateToServer("RequestPickupRelic", {"Model"}, "Returns", function(Player: Player, Relic: Model)
        return RelicService:RequestPickupRelic(Player, Relic)
    end)

    for _, Module in ServerScriptService.Source.ServerModules.Relics:GetChildren() do
        if Module.Name == "RelicService" then continue end
        RelicModules[string.sub(Module.Name, 1, string.len(Module.Name) - 7)] = require(Module) 
    end

	print("RelicService initialized...")
end

function RelicService:Deferred()
    print("RelicService deferred...")
end

function RelicService.PlayerAdded(Player: Player)
    local CurrentRelics = DataService:GetPlayerRelics(Player)

    PlayerRelics[Player] = {
        {Name = CurrentRelics[1], Last = CurrentRelics[1], Effect = nil, Cooldown = 0},
        {Name = CurrentRelics[2], Last = CurrentRelics[2], Effect = nil, Cooldown = 0},
        {Name = CurrentRelics[3], Last = CurrentRelics[3], Effect = nil, Cooldown = 0},
        {Name = CurrentRelics[4], Last = CurrentRelics[4], Effect = nil, Cooldown = 0},
        {Name = CurrentRelics[5], Last = CurrentRelics[5], Effect = nil, Cooldown = 0},
        {Name = CurrentRelics[6], Last = CurrentRelics[6], Effect = nil, Cooldown = 0},
    }

    task.delay(1, function()
        for x = 1, 3 do
            local Slot = PlayerRelics[Player][x]
            if Slot.Name == "None" then continue end

            local Info = RelicInfo[Slot.Name]

            RelicService:EquipRelic(Player, x, Info.Name)
        end
    
        if not CurrentRelics then return end
        Remotes.RelicService.RelicSlotsUpdated:Fire(Player, CurrentRelics)
    end)

end

return RelicService