--!strict

local module = {}

--[=[
    A pluralization count, as defined by the CLDR pluralization rules.
]=]
export type PluralizationCount =
    | "zero"
    | "one"
    | "two"
    | "few"
    | "many"
    | "other"

return module
