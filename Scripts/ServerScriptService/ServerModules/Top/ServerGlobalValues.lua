-- OmniRal

local ServerGlobalValues = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LevelEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum.LevelEnum)

ServerGlobalValues.InLevel = false

ServerGlobalValues.DefaultHistoryEntryCleanTime = 30
ServerGlobalValues.RootWalkSpeed = 0.01

ServerGlobalValues.SimpleDamage = true -- If enabled, there will not be multiple damage types.

ServerGlobalValues.AllowLevelRespawning = true -- If true, players can automatically respawn without needing to be revived (Only when in a level, not the lobby

ServerGlobalValues.StartLevelInfo = {
    ID = 1,
    ExpectedPlayers = {"OmniRal"},
    
    TestingMode = true, -- Test a level in studip; does not load lobby. ID should be set to the desired level
    TestWithoutPlayers = false, -- Test in studio without players; pressing RUN instead of PLAY SOLO,
}

ServerGlobalValues.CurrentLevel = nil :: LevelEnum.Level?

return ServerGlobalValues