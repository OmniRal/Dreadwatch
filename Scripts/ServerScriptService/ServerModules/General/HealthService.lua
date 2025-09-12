-- OmniRal

local HealthService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)
local New = require(ReplicatedStorage.Source.Pronghorn.New)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local CustomEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum)
local ItemInfo = require(ReplicatedStorage.Source.SharedModules.Info.ItemInfo)

--local UnitAttributeService = require(ServerScriptService.Source.ServerModules.Units.UnitAttributeService)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Assets = ServerStorage.Assets
local RNG = Random.new()

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------
-- Private API --
-----------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------
-- Public API --
----------------

function HealthService:ApplyDamage(Source: Player | Model | string, Victim: Player | Model, Damage: number, DamageName: string, CritPossible: boolean?)
    if not Source or not Victim then return end

    local VictimModel = Victim
    if Victim:IsA("Player") then
        VictimModel = Victim.Character
    end

    if not VictimModel then return end

    local TotalDamage = Damage
    local IsCrit = false
    local TrueStrike = false
    local Missed = false
    local Evade = false

    local From, Affects, DisplayType, Position, OtherDetails = Source, Victim.Name, CustomEnum.TextDisplayType.KillerDamage, Vector3.new(0, 0, 0), {}

    local SourceAttributes
    if typeof(Source) ~= "string" then
        SourceAttributes = UnitAttributeService:Get(Source) :: CustomEnum.UnitAttributes

        TotalDamage += math.clamp(SourceAttributes.Base.DamageAmp + SourceAttributes.Offsets.DamageAmp, CustomEnum.BaseAttributeLimits.DamageAmp.Min, CustomEnum.BaseAttributeLimits.DamageAmp.Max)

        if CritPossible then
            local CritChance = SourceAttributes.Base.CritChance + SourceAttributes.Offsets.CritChance
            if RNG:NextInteger(1, 100) <= CritChance then
                IsCrit = true
                TotalDamage += (TotalDamage * ((SourceAttributes.Base.CritPercent + SourceAttributes.Offsets.CritPercent) / 100))

                DisplayType = CustomEnum.TextDisplayType.Crit
            end
        end

        From = Source.Name
    end

    local VictimAttributes = UnitAttributeService:Get(Victim) :: CustomEnum.UnitAttributes
    if VictimAttributes then
        local AttributesFolder = VictimModel:FindFirstChild("UnitAttributes")
        if not AttributesFolder then return end

        local RootPart = VictimModel.PrimaryPart

        if not RootPart then return end

        Position = RootPart.Position + Vector3.new(
            math.sign(RNG:NextNumber(-1, 1)) * RNG:NextNumber(0.75, 1.25),
            math.sign(RNG:NextNumber(-1, 1)) * RNG:NextNumber(0.75, 1.25),
            math.sign(RNG:NextNumber(-1, 1)) * RNG:NextNumber(0.75, 1.25)
        )

        TotalDamage = math.round(TotalDamage)

        if TotalDamage < 0 then return end
        
        if not Evade then
            AttributesFolder.Current.Health.Value = math.clamp(AttributesFolder.Current.Health.Value - TotalDamage, 0, VictimAttributes.Base.Health + VictimAttributes.Offsets.Health)
            OtherDetails.Amount = TotalDamage
        end
        
        local HistoryEntry : CustomEnum.HistoryEntry = {
            Source = Source,
            Name = DamageName,
            Type = CustomEnum.HistoryEntryType.Damage,
            Amount = TotalDamage,
            TimeAdded = os.clock(),
            CleanTime = CustomEnum.DefaultHistoryEntryCleanTime
        }
        UnitAttributeService:AddHistoryEntry(Victim, HistoryEntry)
        Remotes.VisualService.SpawnTextDisplay:FireAll(From, Affects, DisplayType, Position, OtherDetails)
    
    else
        if CollectionService:HasTag(Victim, "Breakable") then
            Victim:SetAttribute("Health", Victim:GetAttribute("Health") - TotalDamage)
        end
    end
end

function HealthService:ApplyHeal(Source: Player | Model | string, Receiver: Player | Model, Heal: number, HealName: string?)
    if not Source or not Receiver then return end

    local ReceiverModel = Receiver
    if Receiver:IsA("Player") then
        ReceiverModel = Receiver.Character
    end

    if not ReceiverModel then return end

    local ReceiverAttributes, AttributesFolder = UnitAttributeService:Get(Receiver) :: CustomEnum.UnitAttributes, ReceiverModel:FindFirstChild("UnitAttributes")
    if not ReceiverAttributes or not AttributesFolder then return end

    AttributesFolder.Current.Health.Value = math.clamp(AttributesFolder.Current.Health.Value + Heal, 0, ReceiverAttributes.Base.Health + ReceiverAttributes.Offsets.Health)

    if not HealName then return end

    local From, Affects, DisplayType, Position, OtherDetails = Source, Receiver.Name, CustomEnum.TextDisplayType.Heal, Vector3.new(0, 0, 0), {Amount = Heal}

    if typeof(Source) ~= "string" then
        From = Source.Name
    end

    local RootPart = ReceiverModel.PrimaryPart
    if not RootPart then return end

    Position = RootPart.Position + Vector3.new(
        math.sign(RNG:NextNumber(-1, 1)) * RNG:NextNumber(0.75, 1.25),
        math.sign(RNG:NextNumber(-1, 1)) * RNG:NextNumber(0.75, 1.25),
        math.sign(RNG:NextNumber(-1, 1)) * RNG:NextNumber(0.75, 1.25)
    )

    local HistoryEntry : CustomEnum.HistoryEntry = {
        Source = Source,
        Name = HealName,
        Type = CustomEnum.HistoryEntryType.Heal,
        Amount = Heal,
        TimeAdded = os.clock(),
        CleanTime = CustomEnum.DefaultHistoryEntryCleanTime,
    }
    UnitAttributeService:AddHistoryEntry(Receiver, HistoryEntry)
    Remotes.VisualService.SpawnTextDisplay:FireAll(From, Affects, DisplayType, Position, OtherDetails)
end

return HealthService