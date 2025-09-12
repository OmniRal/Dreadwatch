-- OmniRal

local UnitAttributeService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local PhysicsService = game:GetService("PhysicsService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)
local New = require(ReplicatedStorage.Source.Pronghorn.New)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local CustomEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local States = {}

local Assets = ServerStorage.Assets

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local BaseAttributes = {
    Health = 100,
    HealthGain = 1,
    AttackSpeed = 0,
    Armor = 0,
    CritChance = 0,
    CritPercent = 0,
    DamageAmp = 0,
    WalkSpeed = 0,
} :: CustomEnum.BaseAttributes

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------
-- Private API --
-----------------

-- Hello

function TestButtons()
    local function SetButton(Button: any)
        if not Button then return end
        Button:SetAttribute("Debounce", false)

        Button.Touched:Connect(function(Hit: any)
            if Button:GetAttribute("Debounce") or not Hit.Parent then return end
            local Player = Players:FindFirstChild(Hit.Parent.Name)
            if not Player then return end

            Button:SetAttribute("Debounce", true)

            if Button.Name ~= "TeamButton" then
                if string.find(Button.Name, "1") then
                    UnitAttributeService:AddEffect(Player, 
                        {
                            From = "Bing", 
                            IsBuff = true, 
                            Name = "Test Buff", 
                            Description = "This is a test buff.", 
                            Icon = 0, 
                            Duration = 10, 
                            MaxStacks = 2
                        }, 
                            {Health = 25, Armor = 15, AttackSpeed = 25, WalkSpeed = 4}, 
                            {}
                    )
                elseif string.find(Button.Name, "2") then
                    UnitAttributeService:AddEffect(Player, {From = "Bing 2", IsBuff = true, Name = "Test Buff 2", Description = "This is a test buff 2.", Icon = 0, Duration = 15, MaxStacks = 1}, {HealthGain = 7, AttackSpeed = 40, WalkSpeed = 2}, {})
                elseif string.find(Button.Name, "3") then
                    UnitAttributeService:AddEffect(Player, {From = "Bing 3", IsBuff = false, Name = "Test Debuff", Description = "This is a test debuff.", Icon = 0, Duration = -1, MaxStacks = 3}, {Health = -25, WalkSpeed = -3, AttackSpeed = -15, HealthGain = -2}, {})
                elseif string.find(Button.Name, "4") then
                    UnitAttributeService:CleanAllEffectsWithNames(Player, "Test Debuff")

                elseif string.find(Button.Name, "5") then
                    task.delay(2, function()
                        UnitAttributeService:AddEffect(Player, {From = "Bing 4", IsBuff = false, Name = "Test Debuff 2", Description = "This is a test debuff.", Icon = 0, Duration = 4, MaxStacks = 1}, {}, {Break = true})
                    end)

                elseif string.find(Button.Name, "6") then
                    task.delay(2, function()
                        UnitAttributeService:AddEffect(Player, {From = "Bing 5", IsBuff = false, Name = "Test Debuff 3", Description = "This is a test debuff.", Icon = 0, Duration = 2, MaxStacks = 1}, {}, {Stunned = true})
                    end)

                elseif string.find(Button.Name, "70") then
                    UnitAttributeService:AddEffect(Player, 
                    {
                        From = "Bing 5", 
                        IsBuff = true, 
                        Name = "Test Buff 3", 
                        Description = "This is a test buff.", 
                        Icon = 0, 
                        Duration = -1, 
                        MaxStacks = 1
                    }, {WalkSpeed = 16}, {})
                end
            else
                if Player:GetAttribute("Team") == CustomEnum.Teams.Red.DisplayName then
                    Player:SetAttribute("Team", "Blue")
                else
                    Player:SetAttribute("Team", "Red")
                end
                if Player.Character then
                    Player.Character:SetAttribute("Team", Player:GetAttribute("Team"))
                end
            end

            task.delay(2, function()
                Button:SetAttribute("Debounce", false)
            end)
        end)
    end

    for _, Button in pairs(Workspace:GetChildren()) do
        if not string.find(Button.Name, "TestEffect_") and Button.Name ~= "TeamButton" then continue end
        SetButton(Button)
    end
end

function CreateStateFolder(UnitAttributes: CustomEnum.UnitAttributes, Unit: Model)
    if not Unit then return end

    local Folder = Assets.Misc.UnitAttributes:Clone()
    Folder.Parent = Unit
    
    for Stat, Value in UnitAttributes.Base do
        Folder.Base:SetAttribute(Stat, Value + (UnitAttributes.Offsets[Stat]))
    end

    for State, Value in UnitAttributes.States do
        if typeof(Value) == "boolean" then
            Folder.States:SetAttribute(State, Value)

        elseif typeof(Value) == "table" then
            Folder.States:SetAttribute(State, Value.Active)
            if State == "Taunt" then
                Folder.States.TauntGoal.Value = Value.Goal
            elseif State == "Panc" then
                Folder.States.PanicFrom.Value = Value.From
            end
        end
    end

    Folder.Current.Health.Value = UnitAttributes.Base.Health + UnitAttributes.Offsets.Health

    return Folder
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------
-- Public API --
----------------

function UnitAttributeService:AddEffect(Unit: Player | Model, EffectDetails: CustomEnum.EffectDetails, BaseAttributes: CustomEnum.BaseAttributes, BaseStates: CustomEnum.BaseStates)
    local UnitAttributes = States[Unit] :: CustomEnum.UnitAttributes
    if not UnitAttributes then return end
    if not UnitAttributes.Folder then return end
    if UnitAttributes.Folder.Parent == nil then return end

    local SpawnTime = os.clock()

    local MaxStacksReached, CopyEffectFound = false, false
    if #UnitAttributes.Effects > 0 then
        local FoundEffects = {}
        for Num, Effect in ipairs(UnitAttributes.Effects) do
            if Effect.Name ~= EffectDetails.Name then continue end
            CopyEffectFound = true
            table.insert(FoundEffects, Effect)
        end

        if #FoundEffects >= EffectDetails.MaxStacks then
            MaxStacksReached = true

            local Difference = #FoundEffects - EffectDetails.MaxStacks
            if Difference > 0 then
                for x = 1, Difference do
                    UnitAttributeService:CleanThisEffect(Unit, FoundEffects[1 + x])
                end
            end
        end
    end
    
    if MaxStacksReached or CopyEffectFound then
        UnitAttributeService:SetTimeOfExistingEffects(Unit, EffectDetails.Name, EffectDetails.Duration, SpawnTime)
        if MaxStacksReached then return end
    end

    local NewConfig = New.Instance("Configuration", EffectDetails.Name, UnitAttributes.Folder.Effects)
    NewConfig:SetAttribute("IsBuff", EffectDetails.IsBuff)
    NewConfig:SetAttribute("Description", EffectDetails.Description)
    NewConfig:SetAttribute("Icon", EffectDetails.Icon)
    NewConfig:SetAttribute("Duration", EffectDetails.Duration)

    for Key, Value in BaseStates do
        NewConfig:SetAttribute(Key, Value or nil)
    end

    local Timer = New.Instance("NumberValue", "Timer", NewConfig, {Value = EffectDetails.Duration})
    local TimerTween = TweenService:Create(Timer, TweenInfo.new(EffectDetails.Duration, Enum.EasingStyle.Linear, Enum.EasingDirection.In), {Value = 0})
    TimerTween:Play()


    local NewEffect: CustomEnum.Effect
    NewEffect = {
        From = EffectDetails.From,
        IsBuff = EffectDetails.IsBuff,
        Name = EffectDetails.Name,
        Description = EffectDetails.Description,
        Icon = EffectDetails.Icon,
        SpawnTime = SpawnTime,
        Duration = EffectDetails.Duration,
        MaxStacks = EffectDetails.MaxStacks,

        Offsets = {
            Health = BaseAttributes.Health,
            HealthGain = BaseAttributes.HealthGain,
            Armor = BaseAttributes.Armor,
            WalkSpeed = BaseAttributes.WalkSpeed,
            AttackSpeed = BaseAttributes.AttackSpeed,
            CritChance = BaseAttributes.CritChance,
            CritPercent = BaseAttributes.CritPercent,
            DamageAmp = BaseAttributes.DamageAmp,
        },

        States = {
            Sturdy = BaseStates.Sturdy or false,
            Stunned = BaseStates.Stunned or false,
            Rooted = BaseStates.Rooted or false,
            Taunt = BaseStates.Taunt or false,
            Panic = BaseStates.Panic or false,
            Disarmed = BaseStates.Disarmed or false,
            Break = BaseStates.Break or false,
        },

        CleanFunction = function()
            --print("Cleaning Effect ", EffectDetails.Name, " in ", EffectDetails.Duration, " seconds.")
            if NewEffect.CleanDelay then
                task.cancel(NewEffect.CleanDelay)
            end

            if EffectDetails.Duration > 0 then
                NewEffect.CleanDelay = task.delay(EffectDetails.Duration, function()
                    UnitAttributeService:CleanThisEffect(Unit, NewEffect)
                end)

                if TimerTween then
                    TimerTween:Cancel()
                end

                Timer.Value = EffectDetails.Duration
                TimerTween = TweenService:Create(Timer, TweenInfo.new(EffectDetails.Duration, Enum.EasingStyle.Linear, Enum.EasingDirection.In), {Value = 0})
                TimerTween:Play()
            end
        end,

        CleanDelay = nil,

        Config = NewConfig,
    }

    NewEffect.CleanFunction()

    table.insert(UnitAttributes.Effects, NewEffect)

    --print(Unit.Name, " Updated States: ", UnitAttributes)
    UnitAttributeService:RecalculateAttributes(Unit, BaseAttributes)
end

function UnitAttributeService:SetTimeOfExistingEffects(Unit: Player | Model, EffectName: string, NewDuration: number, NewSpawnTime: number?)
    local UnitAttributes = States[Unit]
    if not UnitAttributes then return end

    for _, Effect : CustomEnum.Effect in ipairs(UnitAttributes.Effects) do
        if Effect.Name ~= EffectName then continue end
        Effect.Duration = NewDuration 
        Effect.SpawnTime = NewSpawnTime or Effect.SpawnTime
        Effect.CleanFunction()
    end
end

function UnitAttributeService:CleanThisEffect(Unit: Player | Model, ThisEffect: CustomEnum.Effect)
    local UnitAttributes = States[Unit]
    if not UnitAttributes then return end

    for Num, Effect in ipairs(UnitAttributes.Effects) do
        if Effect ~= ThisEffect then continue end
        if Effect.Config then
            Effect.Config:Destroy()
            Effect.Config = nil
        end
        table.remove(UnitAttributes.Effects, Num)
    end

    UnitAttributeService:RecalculateAttributes(Unit, BaseAttributes)
    --print(Unit.Name, " Updated States: ", UnitAttributes)
end

function UnitAttributeService:CleanAllEffectsWithNames(Unit: Player | Model, EffectName: string)
    local UnitAttributes = States[Unit] :: CustomEnum.UnitAttributes
    if not UnitAttributes then return end

    pcall(function()
        local CleanThese = {}
        for Num, Effect in ipairs(UnitAttributes.Effects) do
            if Effect.Name ~= EffectName then continue end
            if Effect.Config then
                Effect.Config:SetAttribute("Clean", true)
                Debris:AddItem(Effect.Config, 1)
                Effect.Config = nil
            end
            table.insert(CleanThese, Effect)
        end

        for _, Effect in ipairs(CleanThese) do
            if not Effect then continue end
            local CleanNum = table.find(UnitAttributes.Effects, Effect)
            if not CleanNum then continue end

            table.remove(UnitAttributes.Effects, CleanNum)
        end

        UnitAttributeService:RecalculateAttributes(Unit, BaseAttributes)
    end)

    --print(Unit.Name, " Updated States: ", UnitAttributes)
end

function UnitAttributeService:CleanAllEffects(Unit: Player | Model, Only: string?)
    local UnitAttributes = States[Unit]
    if not UnitAttributes then return end

    pcall(function()
        local CleanThese = {}
        for Num, Effect : CustomEnum.Effect in ipairs(UnitAttributes.Effects) do
            if not Effect.Config then continue end
            if Only == "Buffs" then
                if not Effect.IsBuff then continue end
            elseif Only == "Debuffs" then
                if Effect.IsBuff then continue end
            end
            Effect.Config:SetAttribute("Clean", true)
            Debris:AddItem(Effect.Config, 1)
            Effect.Config = nil
            table.insert(CleanThese, Effect)
        end

        for _, Effect in ipairs(CleanThese) do
            if not Effect then continue end
            local CleanNum = table.find(UnitAttributes.Effects, Effect)
            if not CleanNum then continue end

            table.remove(UnitAttributes.Effects, CleanNum)
        end

        UnitAttributeService:RecalculateAttributes(Unit, BaseAttributes)
    end)
end

function UnitAttributeService:RecalculateAttributes(Unit: Player | Model, UnitStats: CustomEnum.BaseStats, NewBaseAttributes: {}?)
    local UnitAttributes = States[Unit] :: CustomEnum.UnitAttributes
    if not UnitAttributes then return end

    local OriginalMaxHealth = UnitAttributes.Base.Health + UnitAttributes.Offsets.Health
    local OriginalMaxMana = UnitAttributes.Base.Mana + UnitAttributes.Offsets.Mana
    local PercentHealth = 1
    local PercentMana = 1
    if UnitAttributes.Folder then
        PercentHealth = UnitAttributes.Folder.Current.Health.Value / OriginalMaxHealth
        PercentMana = UnitAttributes.Folder.Current.Mana.Value / OriginalMaxMana
        --print("Current Health: ", UnitAttributes.Folder.Current.Health.Value)
    end

    if NewBaseAttributes then
        for Key, Num in NewBaseAttributes do
            if not UnitAttributes.Base[Key] then continue end
            UnitAttributes.Base[Key] = Num
        end
    end

    local Offsets : CustomEnum.BaseAttributes
    Offsets = {
        Health = 0,
        HealthGain = 0,
        WalkSpeed = 0,
        AttackSpeed = 0,
        Armor = 0,
        CritChance = 0,
        CritPercent = 0,
        DamageAmp = 0,
    }
    --local PercentOffsets : CustomEnum.BaseAttributes
    local States : CustomEnum.BaseStates
    States = {
        Stunned = false,
        Rooted = false,
        Sturdy = false,
        Taunt = {
            Active = false,
            Goal = nil,
        },
        Panic = {
            Active = false,
            From = nil,
        },
        Disarmed = false,
        Break = false,
    }

    for _, Effect : CustomEnum.Effect in UnitAttributes.Effects do
        if not Effect then continue end
        for Stat, Change in Effect.Offsets :: any do
            Offsets[Stat] += Change
            --[[if typeof(Change) == "number" then
                Offsets[Name] += Change
            elseif typeof(Change) == "string" then
                PercentOffsets[Name] += Change
            end]]
        end

        for State, Value in Effect.States :: any do
            if typeof(Value) == "boolean" then
                if Value then
                    States[State] = true
                end
            
            elseif typeof(Value) == "table" then
                if Value.Active then
                    States[State].Active = true
                    if State == "Taunt" then
                        States[State].Goal = Value.Goal
                    elseif State == "Panic" then
                        States[State].From = Value.From
                    end
                end
            end
        end
    end

    for Stat, Change in Offsets do
        UnitAttributes.Offsets[Stat] = Change
    end

    if UnitAttributes.Folder then
        for Stat, Value in UnitAttributes.Base do
            local Limit = CustomEnum.BaseAttributeLimits[Stat]
            if Limit then
                --print(Stat, " limit is ", Limit)
                UnitAttributes.Folder.Base:SetAttribute(Stat, math.clamp(Value + UnitAttributes.Offsets[Stat], Limit.Min, Limit.Max))
            else
                UnitAttributes.Folder.Base:SetAttribute(Stat, Value + UnitAttributes.Offsets[Stat])
            end
        end

        for State, Value in States do
            if typeof(Value) == "boolean" then
                UnitAttributes.Folder.States:SetAttribute(State, Value)

            elseif typeof(Value) == "table" then
                UnitAttributes.Folder.States:SetAttribute(State, Value.Active)
                if State == "Taunt" then
                    UnitAttributes.Folder.States.TauntGoal.Value = Value.Goal
                elseif State == "Panc" then
                    UnitAttributes.Folder.States.PanicFrom.Value = Value.From
                end
            end
        end

        if not NewBaseAttributes then
            if UnitAttributes.Folder.Base:GetAttribute("Health") ~= OriginalMaxHealth then
                UnitAttributes.Folder.Current.Health.Value = PercentHealth * (UnitAttributes.Base.Health + UnitAttributes.Offsets.Health)
            end
            if UnitAttributes.Folder.Base:GetAttribute("Mana") ~= OriginalMaxMana then
                UnitAttributes.Folder.Current.Mana.Value = PercentMana * (UnitAttributes.Base.Mana + UnitAttributes.Offsets.Mana)
            end
        else
            UnitAttributes.Folder.Current.Health.Value = UnitAttributes.Base.Health + UnitAttributes.Offsets.Health
            UnitAttributes.Folder.Current.Mana.Value = UnitAttributes.Base.Mana + UnitAttributes.Offsets.Mana
        end
    end
end

function UnitAttributeService:AddHistoryEntry(Unit: Player | Model, Entry: CustomEnum.HistoryEntry)
    local UnitAttributes = States[Unit] :: CustomEnum.UnitAttributes
    if not UnitAttributes then return end
    if not UnitAttributes.History then return end

    if not Entry.TimeAdded then
        Entry.TimeAdded = os.clock()
    end

    table.insert(UnitAttributes.History, Entry)
    --print("History: ", UnitAttributes.History)

    if Entry.CleanTime then
        task.delay(Entry.CleanTime, function()
            pcall(function()
                for Num, OldEntry in ipairs(UnitAttributes.History) do
                    if not OldEntry then continue end
                    if OldEntry ~= Entry then continue end
                    table.remove(UnitAttributes.History, Num)
                end

                --print("History: ", UnitAttributes.History)
            end)
        end)
    end
end

function UnitAttributeService:CleanHistroy(Unit: Player | Model)
    local UnitAttributes = States[Unit] :: CustomEnum.UnitAttributes
    if not UnitAttributes then return end
    if not UnitAttributes.History then return end

    table.clear(UnitAttributes.History)
end

function UnitAttributeService:Get(Unit: Player | Model | string) : CustomEnum.UnitAttributes?
    local UnitAttributes = States[Unit]
    if not UnitAttributes then return end

    return UnitAttributes 
end

function UnitAttributeService:New(Unit: Player | Model, BaseAttributes: {}?)
    if States[Unit] then
        warn("Attribute Values for ", Unit.Name, " already exists.")
        return
    end

    local Base = {
        Health = 100,
        HealthGain = 1,
        WalkSpeed = 16,
        AttackSpeed = 100,
        Armor = 0,
        CritChance = 0,
        CritPercent = 0,
        DamageAmp = 0,
    } :: CustomEnum.BaseAttributes
    
    if BaseAttributes then
        for Key, Num in BaseAttributes do
            if not Base[Key] then continue end
            Base[Key] = Num
        end
    end

    local NewAttributes: CustomEnum.UnitAttributes = {
        Base = Base,

        Offsets = {
            Health = 0,
            HealthGain = 0,
            WalkSpeed = 0,
            AttackSpeed = 0,
            Armor = 0,
            CritChance = 0,
            CritPercent = 0,
            DamageAmp = 0,
        },

        States = {
            Sturdy = false,
            Stunned = false,
            Rooted = false,
            Taunt = {Active = false},
            Panic = {Active = false},
            Tracked = false,
            Disarmed = false,
            Silenced = false,
            Break = false,
        },

        Effects = {},
        History = {},
    }

    if Unit:IsA("Player") then
        Unit.CharacterAdded:Connect(function(Character: Model)
            NewAttributes.Folder = CreateStateFolder(NewAttributes, Character)
        end)
    else
        NewAttributes.Folder = CreateStateFolder(NewAttributes, Unit)
    end

    States[Unit] = NewAttributes

    --print(Unit.Name, " States: ", NewAttributes)
end

function UnitAttributeService:Remove(Unit: Player | Model)
    if not States[Unit] then return end
    States[Unit] = nil
end

function UnitAttributeService:Init()
    TestButtons()

    Remotes:CreateToServer("SetHidden", {"boolean"}, "Reliable", function(Player: Player, Set: boolean)
        if not Player then return end
        if not States[Player] then return end
        if not States[Player].Folder then return end
        if not States[Player].Folder:FindFirstChild("Current") then return end
        States[Player].Folder.Current.Hidden.Value = Set
    end)
end

function UnitAttributeService.PlayerAdded(Player: Player)
    UnitAttributeService:New(Player)
end

return UnitAttributeService