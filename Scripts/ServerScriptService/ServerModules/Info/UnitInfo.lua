-- OmniRal

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local New = require(ReplicatedStorage.Source.Pronghorn.New)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local CustomEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

export type UnitPatrolStyle = "Stationary" | "Loop" | "BackNForth" | "RandomPoints" | "FreeRoam"
        -- Stationary = Don't move, ideal for NPCs
        -- Free = Move randomly around the areas the Unit has spawned
        -- Loop = Move through all the points in an endless loop
        -- BackNForth = Move through all the points in a loop, but once reached the last point, start walking back. Restart the cycle once reaching the first point again
        -- RandomPoints = Move between the points randomly

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

export type UnitBase = {
    DisplayName: string,
    
    Models: {{Choice: Model, Chance: number}}, -- Use the dict if multiple Unit models to choose from (some versions with alt colors)

    BaseStats: {
        Health: number,
        WalkSpeed: number,
        RunSpeed: number,
    },

    EnemyStats: {
        Agro: {
            Is: boolean, -- If set to false, enemies will only attack if a player attacks them first
            Range: number, -- How close the player needs before the Unit starts chasing
        },

        ChaseRange: number, -- How far the unit can chase a player from their original spawn position before stopping

        HealthThresholdForCombat: number, -- Set to MAX PERCENT if it should always attack. Set to ZERO PERCENT if it should only run away.
        SearchTime: number, -- How long a unit will stand in one spot and search for a target after losing vision of them
    
        Attacks: {
            [string]: { -- The name of the attack
                HealthThreshold: number, -- What health % the unit needs to be at before being allowed to use this attack
                Cooldown: NumberRange,
                Chance: number, -- Chance to use this attack
                Damage: NumberRange,
                Speed: number,
                Style: CustomEnum.AttackType, 
                Type: CustomEnum.DamageType,
                UseRange: number,
                DamageRange: number,
                MoveSpeedWhileAttacking: number, -- What their movement speed percent should be when attacking
                RequireVision: boolean,
            }?
        },
    }?,

    Vision: {
        Type: "Cone" | "360",
            -- Cone = Sees other units only when they are in front of this unit and in their field of view
            -- 360 = Sees other untis from all direction regardless which way this unit is facing

        XRay: boolean?, -- Can see through walls
        Range: number?, -- How far the enemy can see
        Angle: number?, -- In degrees of how wide the field of view is for the enemy to detect players in front of it
    }?,

    RoamRange: number?, -- How far the unit will wander if the patrol style is set to FreeRoam

    PathParams: { -- If the unit uses path finding, these need to be defined
        Radius: number, -- Min HORIZONTAL empty space required to traverse a path
        Height: number,  -- Min VERTICAL empty space required to traverse a path
        CanJump: boolean,
        Costs: {
            [string]: number -- Example: ["Snow"] = 10, ["Grass"] = 1. A unit with these costs will prefer finding paths that go over grass while avoiding snow. Leave empty if none of that matters
        }
    }?,

    Animations: {
        Base: {[string]: {ID: number, Priority: Enum.AnimationPriority}},
        Actions: {[string]: {ID: number, Priority: Enum.AnimationPriority}}
    }
}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local UnitInfo: {[string]: UnitBase} = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local UnitDied = New.Event()
UnitInfo.UnitDied = UnitDied

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Enemies = ServerStorage.Assets.Enemies

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


UnitInfo["TestBot"] = {
    DisplayName = "Test Bot",
    
    Models = {
        {Choice = Enemies.TestBot.T1, Chance = 75},
        {Choice = Enemies.TestBot.T2, Chance = 25},
    },
    
    BaseStats = {
        Health = 25,
        WalkSpeed = 4,
        RunSpeed = 14,
    },

    EnemyStats = {
        Agro = {
            Is = true,
            Range = 35,
        },
    
        ChaseRange = 60,
        HealthThresholdForCombat = 25,
        SearchTime = 3,

        Attacks = {
            ["Melee_Attack"] = {
                HealthThreshold = 25,
                Cooldown = NumberRange.new(1.5, 2),
                Chance = 75,
                Damage = NumberRange.new(7, 10),
                Speed = 1,
                Style = "Melee",
                Type = "Physical",
                UseRange = 5,
                DamageRange = 8,
                MoveSpeedWhileAttacking = 25,
                RequireVision = false,
            },

            ["Ranged_Attack"] = {
                HealthThreshold = 100,
                Cooldown = NumberRange.new(4, 4),
                Chance = 25,
                Damage = NumberRange.new(2, 2),
                Speed = 0.5,
                Style = "Ranged",
                Type = "Physical",
                UseRange = 50,
                DamageRange = 10,
                MoveSpeedWhileAttacking = 0,
                RequireVision = true,
            },
        },
    },

    Vision = {
        Type = "Cone",
        XRay = false,
        Range = 40,
        Angle = 30
    },

    PathParams = {
        Radius = 5,
        Height = 6,
        CanJump = false,
        Costs = {},
    },
    
    Animations = {
        Base = {
            ["Idle"] = {ID = 82720915858983, Priority = Enum.AnimationPriority.Idle},
            ["Walk"] = {ID = 82759466071599, Priority = Enum.AnimationPriority.Movement},
            ["Run"] = {ID = 71347537996202, Priority = Enum.AnimationPriority.Movement},
        },

        Actions = {
            ["Ranged_Attack"] = {ID = 87114672922708, Priority = Enum.AnimationPriority.Action2},
            ["Melee_Attack"] = {ID = 71363639882617, Priority = Enum.AnimationPriority.Action2},
        }
    }
}

return UnitInfo