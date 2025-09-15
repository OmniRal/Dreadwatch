-- OmniRal

local ModStoneEnum = {}

export type Mod = "None" | "Echo" | "Blast"

export type ModList = {
    [number]: Mod,
}

return ModStoneEnum