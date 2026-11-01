--!strict

local module = {}

--[=[
    CLDR plural operands (Unicode TR35)

    https://unicode.org/reports/tr35/tr35-numbers.html#Operands

    Operands:
    * **n**: the absolute value of the number
    * **i**: the number as an integer
    * **v**: the number of visible fraction digits, with trailing zeros
    * **w**: the number of visible fraction digits, without trailing zeros
    * **f**: the visible fraction digits, with trailing zeros, as an integer
    * **t**: the visible fraction digits, without trailing zeros, as an integer
    * **c**: the compact decimal exponent, the power of 10 used in compact
      formatting (6 for "1.2M"), 0 when not compact-formatted
    * **e**: a deprecated synonym for `c`
]=]
export type Operands = {
    --[=[
        The absolute value of the number.
    ]=]
    n: number,
    --[=[
        The number as an integer.
    ]=]
    i: number,
    --[=[
        The number of visible fraction digits, with trailing zeros.
    ]=]
    v: number,
    --[=[
        The number of visible fraction digits, without trailing zeros.
    ]=]
    w: number,
    --[=[
        The visible fraction digits, with trailing zeros, as an integer.
    ]=]
    f: number,
    --[=[
        The visible fraction digits, without trailing zeros, as an integer.
    ]=]
    t: number,
    --[=[
        The compact decimal exponent, the power of 10 used in compact
        formatting.

        It is 0 for a plainly-formatted number, and the suffix exponent when
        compact-formatted:
        * 1200 shown as "1.2K" -> c = 3
        * 10100000 shown as "10.1M" -> c = 6
    ]=]
    c: number,
    --[=[
        The deprecated synonym for `c`.
    ]=]
    e: number,
}

--[=[
    The significant digits a double can represent without float noise.
]=]
local MAX_SIGNIFICANT_DIGITS = 15

--[=[
    Generates a table with CLDR operands given a number, an optional
    `fractionalDigits`, and an optional `compactExponent`.

    @param number The number that needs operands generated for. When compact
           formatted, this is the full value: 1200 for "1.2K".
    @param fractionalDigits The number of visible fractional digits, rounding
           the number to fit. An example would be the following: 20.400 -> 3
           and 80.00 -> 2. Without it, the digits come from the number itself.
    @param compactExponent The power of 10 used in compact formatting: 3 for
           "1.2K". Defaults to 0.
    @returns A table with the CLDR operands.
]=]
function module.generateOperands(
    number: number,
    fractionalDigits: number?,
    compactExponent: number?
): Operands
    local absolute = math.abs(number)
    local c = compactExponent or 0

    if absolute ~= absolute or absolute == math.huge then
        return {
            n = absolute,
            i = absolute,
            v = 0,
            w = 0,
            f = 0,
            t = 0,
            c = c,
            e = c,
        }
    end

    local whole = math.floor(absolute)
    local integerDigits = if whole == 0
        then 1
        else math.floor(math.log10(whole)) + 1
    local digits: number = fractionalDigits
        or if whole == absolute
            then 0
            else math.max(0, MAX_SIGNIFICANT_DIGITS - integerDigits)

    local text = string.format("%." .. digits .. "f", absolute)
    local dot = text:find(".", 1, true)
    local integerText = if dot ~= nil then text:sub(1, dot - 1) else text
    local fraction = if dot ~= nil then text:sub(dot + 1) else ""
    local trimmedLength = #fraction
    while
        trimmedLength > 0
        and fraction:sub(trimmedLength, trimmedLength) == "0"
    do
        trimmedLength -= 1
    end
    local trimmed = fraction:sub(1, trimmedLength)
    local visible = if fractionalDigits == nil then trimmed else fraction

    return {
        n = tonumber(text) :: number,
        i = tonumber(integerText) :: number,
        v = #visible,
        w = #trimmed,
        f = tonumber(visible) or 0,
        t = tonumber(trimmed) or 0,
        c = c,
        e = c,
    }
end

return module
