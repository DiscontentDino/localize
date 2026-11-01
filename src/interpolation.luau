--!strict

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
    Parse the text between the braces of a placeholder.

    @param raw The text.
    @return The placeholder.
]=]
local function parsePlaceholder(raw: string): Placeholder
    return { raw = raw, name = trim(raw) }
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
