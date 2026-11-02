--!strict

local operandsModule = require("./operands")

--[=[
    Formats numbers for a locale, modelled on `Intl.NumberFormat`.
]=]
local module = {}

--[=[
    The number formatting data for a locale.
]=]
export type NumberFormattingData = {
    symbols: {
        decimal: string,
        group: string,
        minusSign: string,
        plusSign: string,
        percentSign: string,
        infinity: string,
        nan: string,
    },
    grouping: {
        primary: number,
        secondary: number,
        minimum: number,
    },
    compact: {
        short: { [string]: { [string]: string } },
        long: { [string]: { [string]: string } },
    },
}

--[=[
    Options controlling how a number is formatted.
]=]
export type FormatOptions = {
    notation: ("standard" | "compact")?,
    compactDisplay: ("short" | "long")?,
    minimumFractionDigits: number?,
    maximumFractionDigits: number?,
    useGrouping: boolean?,
}

--[=[
    The plural rules that pick a compact pattern.
]=]
type CardinalRules = (operands: operandsModule.Operands) -> string

--[=[
    Round a non-negative number to a number of fraction digits.

    @param value The number.
    @param digits The number of fraction digits.
    @return The rounded number.
]=]
local function roundTo(value: number, digits: number): number
    local scale = 10 ^ digits
    local scaled = tonumber(string.format("%.15g", value * scale)) :: number
    return math.floor(scaled + 0.5) / scale
end

--[=[
    Group the integer digits of a number with the locale's separator.

    @param digits The integer digits.
    @param grouping The grouping sizes.
    @param separator The group separator.
    @return The grouped digits.
]=]
local function groupInteger(
    digits: string,
    grouping: { primary: number, secondary: number },
    separator: string
): string
    local count = #digits
    if grouping.primary <= 0 or count <= grouping.primary then return digits end

    local result = digits:sub(count - grouping.primary + 1)
    local rest = digits:sub(1, count - grouping.primary)
    while #rest > grouping.secondary do
        local cut = #rest - grouping.secondary + 1
        result = rest:sub(cut) .. separator .. result
        rest = rest:sub(1, cut - 1)
    end
    return rest .. separator .. result
end

--[=[
    Format a non-negative number as a standard decimal.

    @param value The number.
    @param data The locale's number formatting data.
    @param minimumFractionDigits The minimum number of fraction digits.
    @param maximumFractionDigits The maximum number of fraction digits.
    @param minimumGroupedDigits The fewest integer digits to group.
    @return The formatted number.
]=]
local function formatDecimal(
    value: number,
    data: NumberFormattingData,
    minimumFractionDigits: number,
    maximumFractionDigits: number,
    minimumGroupedDigits: number
): string
    local rounded = roundTo(value, maximumFractionDigits)
    local text = string.format("%." .. maximumFractionDigits .. "f", rounded)
    local dot = text:find(".", 1, true)
    local integerPart = if dot ~= nil then text:sub(1, dot - 1) else text
    local fractionPart = if dot ~= nil then text:sub(dot + 1) else ""

    while
        #fractionPart > minimumFractionDigits
        and fractionPart:sub(-1) == "0"
    do
        fractionPart = fractionPart:sub(1, -2)
    end

    local grouped = if #integerPart >= minimumGroupedDigits
        then groupInteger(integerPart, data.grouping, data.symbols.group)
        else integerPart

    if #fractionPart > 0 then
        return grouped .. data.symbols.decimal .. fractionPart
    end
    return grouped
end

--[=[
    Find the run of zeros in a compact pattern.

    @param pattern The pattern.
    @return The first and last index of the zeros, or `nil` if there are none.
]=]
local function findZeros(pattern: string): (number?, number?)
    local first = pattern:find("0", 1, true)
    if first == nil then return nil, nil end

    local last = first
    while pattern:sub(last + 1, last + 1) == "0" do
        last += 1
    end
    return first, last
end

--[=[
    Get the key of a magnitude's compact patterns.

    @param magnitude The power of 10.
    @return The key, like `"1000"`.
]=]
local function getBucketKey(magnitude: number): string
    return "1" .. string.rep("0", magnitude)
end

--[=[
    Format a non-negative number in compact notation.

    @param value The number.
    @param data The locale's number formatting data.
    @param cardinal The locale's cardinal plural rules.
    @param display The compact display.
    @param minimumFractionDigits The minimum number of fraction digits.
    @param maximumFractionDigits The maximum number of fraction digits.
    @param minimumGroupedDigits The fewest integer digits to group.
    @return The formatted number.
]=]
local function formatCompact(
    value: number,
    data: NumberFormattingData,
    cardinal: CardinalRules,
    display: "short" | "long",
    minimumFractionDigits: number,
    maximumFractionDigits: number,
    minimumGroupedDigits: number
): string
    local patterns = data.compact[display]
    local rounded = roundTo(value, maximumFractionDigits)
    local exactMagnitude = math.floor(math.log10(value))

    -- Rounding can push a small number up to the first bucket (999.95 -> 1K).
    local magnitude = if rounded >= 1000
        then math.max(exactMagnitude, 3)
        else exactMagnitude
    if magnitude < 3 then
        return formatDecimal(
            value,
            data,
            minimumFractionDigits,
            maximumFractionDigits,
            minimumGroupedDigits
        )
    end

    while patterns[getBucketKey(magnitude)] == nil do
        magnitude -= 1
    end
    local bucket = patterns[getBucketKey(magnitude)]
    local hasNextBucket = patterns[getBucketKey(magnitude + 1)] ~= nil
    local other = bucket.other

    -- A bare "0" pattern means this magnitude is not compacted.
    local firstZero, lastZero = findZeros(other)
    if firstZero == 1 and lastZero == #other then
        -- Rounding can still reach the next bucket (9999.95 -> 1万).
        if rounded >= 10 ^ (magnitude + 1) and hasNextBucket then
            return formatCompact(
                10 ^ (magnitude + 1),
                data,
                cardinal,
                display,
                minimumFractionDigits,
                maximumFractionDigits,
                minimumGroupedDigits
            )
        end
        return formatDecimal(
            value,
            data,
            minimumFractionDigits,
            maximumFractionDigits,
            minimumGroupedDigits
        )
    end

    local zeros = (lastZero :: number) - (firstZero :: number) + 1
    local exponent = magnitude - (zeros - 1)
    local mantissa = roundTo(value / 10 ^ exponent, maximumFractionDigits)

    -- Rounding can push the mantissa into the next bucket (999.9K -> 1M).
    if mantissa >= 10 ^ zeros and hasNextBucket then
        return formatCompact(
            10 ^ (magnitude + 1),
            data,
            cardinal,
            display,
            minimumFractionDigits,
            maximumFractionDigits,
            minimumGroupedDigits
        )
    end

    local mantissaText = formatDecimal(
        mantissa,
        data,
        minimumFractionDigits,
        maximumFractionDigits,
        minimumGroupedDigits
    )
    local operands = operandsModule.generateOperands(mantissa, nil, exponent)
    local exactPattern = if mantissa == 1 then bucket["1"] else nil
    local pattern = exactPattern or bucket[cardinal(operands)] or other
    local first, last = findZeros(pattern)
    if first == nil then return pattern end

    return pattern:sub(1, (first :: number) - 1)
        .. mantissaText
        .. pattern:sub((last :: number) + 1)
end

--[=[
    Format a number for a locale.

    @param value The number to format.
    @param data The locale's number formatting data.
    @param cardinal The locale's cardinal plural rules.
    @param options How to format the number.
    @return The formatted number.
]=]
function module.format(
    value: number,
    data: NumberFormattingData,
    cardinal: CardinalRules,
    options: FormatOptions?
): string
    if value ~= value then return data.symbols.nan end

    local resolved: FormatOptions = options or {}
    local notation = resolved.notation or "standard"
    local isCompact = notation == "compact"
    local minimumFractionDigits = resolved.minimumFractionDigits or 0
    local maximumFractionDigits = math.max(
        minimumFractionDigits,
        resolved.maximumFractionDigits or if isCompact then 1 else 3
    )

    -- By default, compact numbers only group from 5 digits (1234万).
    local minimumGroupedDigits = if resolved.useGrouping == false
        then math.huge
        elseif resolved.useGrouping == nil and isCompact then 5
        elseif resolved.useGrouping == nil then data.grouping.primary
            + data.grouping.minimum
        else 1

    local sign = if value < 0 then data.symbols.minusSign else ""
    local absolute = math.abs(value)
    if absolute == math.huge then return sign .. data.symbols.infinity end

    local body = if isCompact
        then formatCompact(
            absolute,
            data,
            cardinal,
            resolved.compactDisplay or "short",
            minimumFractionDigits,
            maximumFractionDigits,
            minimumGroupedDigits
        )
        else formatDecimal(
            absolute,
            data,
            minimumFractionDigits,
            maximumFractionDigits,
            minimumGroupedDigits
        )

    return sign .. body
end

return module
