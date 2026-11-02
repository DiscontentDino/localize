--!strict

local numberFormatterModule = require("./numbers/numberFormatter")

type FormatOptions = numberFormatterModule.FormatOptions

local module = {}

--[=[
    A placeholder in a translation.
]=]
export type Placeholder = {
    --[=[
        The text between the braces.
    ]=]
    raw: string,
    --[=[
        The name of the variable.
    ]=]
    name: string,
    --[=[
        Whether the placeholder has a format.
    ]=]
    isFormatted: boolean,
    --[=[
        The parsed format, or `nil` if the format is invalid.
    ]=]
    options: FormatOptions?,
}

--[=[
    A part of a translation: literal text or a placeholder.
]=]
export type Part = string | Placeholder

local cache: { [string]: { Part } } = {}

--[=[
    Check whether a byte is whitespace.

    @param byte The byte.
    @return Whether the byte is whitespace.
]=]
local function isWhitespace(byte: number): boolean
    return byte == 32 or (byte >= 9 and byte <= 13)
end

--[=[
    Remove the whitespace around a string.

    @param text The string.
    @return The trimmed string.
]=]
local function trim(text: string): string
    local first = 1
    local last = #text
    while first <= last and isWhitespace(text:byte(first) :: number) do
        first += 1
    end
    while last >= first and isWhitespace(text:byte(last) :: number) do
        last -= 1
    end
    return text:sub(first, last)
end

--[=[
    Parse the value of a format option.

    @param name The option's name.
    @param text The option's value, as text.
    @return The value, or `nil` if the option or value is invalid.
]=]
local function parseOption(name: string, text: string): any
    if name == "notation" then
        return if text == "standard" or text == "compact" then text else nil
    elseif name == "compactDisplay" then
        return if text == "short" or text == "long" then text else nil
    elseif name == "useGrouping" then
        if text == "true" then return true end
        return if text == "false" then false else nil
    elseif
        name == "minimumFractionDigits" or name == "maximumFractionDigits"
    then
        local digits = tonumber(text)
        local isValid = digits ~= nil
            and digits % 1 == 0
            and digits >= 0
            and digits <= 20
        return if isValid then digits else nil
    end
    return nil
end

--[=[
    Parse an interpolation format.

    @param format The format.
    @return The options, or `nil` if the format is invalid.
]=]
local function parseFormat(format: string): FormatOptions?
    local name = format
    local body = ""
    local open = format:find("(", 1, true)
    if open ~= nil then
        if format:sub(-1) ~= ")" then return nil end
        name = trim(format:sub(1, open - 1))
        body = format:sub(open + 1, -2)
    end
    if name ~= "number" then return nil end

    local options: any = {}
    for _, entry in body:split(";") do
        local trimmed = trim(entry)
        if trimmed ~= "" then
            local colon = trimmed:find(":", 1, true)
            if colon == nil then return nil end

            local key = trim(trimmed:sub(1, colon - 1))
            local value = parseOption(key, trim(trimmed:sub(colon + 1)))
            if value == nil then return nil end
            options[key] = value
        end
    end
    return options
end

--[=[
    Parse the text between the braces of a placeholder.

    @param raw The text.
    @return The placeholder.
]=]
local function parsePlaceholder(raw: string): Placeholder
    local comma = raw:find(",", 1, true)
    if comma == nil then
        return { raw = raw, name = trim(raw), isFormatted = false }
    end

    return {
        raw = raw,
        name = trim(raw:sub(1, comma - 1)),
        isFormatted = true,
        options = parseFormat(trim(raw:sub(comma + 1))),
    }
end

--[=[
    Parse a translation into parts. Results are cached by text.

    @param text The translation.
    @return The parts.
]=]
function module.parse(text: string): { Part }
    local cached = cache[text]
    if cached ~= nil then return cached end

    local parts: { Part } = {}
    local literal: { string } = {}

    local function flushLiteral()
        if #literal == 0 then return end
        table.insert(parts, table.concat(literal))
        table.clear(literal)
    end

    local index = 1
    local length = #text
    while index <= length do
        local pair = text:sub(index, index + 1)
        if text:sub(index, index + 2) == "\\{{" then
            table.insert(literal, "{{")
            index += 3
        elseif pair == "\\\\" then
            table.insert(literal, "\\")
            index += 2
        elseif pair == "{{" then
            local close = text:find("}}", index + 2, true)
            if close == nil then
                table.insert(literal, text:sub(index))
                break
            end

            flushLiteral()
            table.insert(
                parts,
                parsePlaceholder(text:sub(index + 2, close - 1))
            )
            index = close + 2
        else
            table.insert(literal, text:sub(index, index))
            index += 1
        end
    end
    flushLiteral()

    cache[text] = parts
    return parts
end

return module
