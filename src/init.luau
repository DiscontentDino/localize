--!strict

local dataModule = require("@self/data")
local interpolationModule = require("@self/interpolation")
local operandsModule = require("@self/numbers/operands")
local pluralizationModule = require("@self/numbers/pluralization")

export type LanguageCode = dataModule.LanguageCode
export type Metadata = dataModule.Metadata
export type PluralizationFunctions = dataModule.PluralizationFunctions
export type NumberFormattingData = dataModule.NumberFormattingData
export type LanguageConfiguration = dataModule.LanguageConfiguration
export type Operands = operandsModule.Operands
export type PluralizationCount = pluralizationModule.PluralizationCount

--[=[
    The translations of a namespace, by key.
]=]
export type Translations = { [string]: string }

--[=[
    Loads the translations of a language and namespace on demand.
]=]
export type Backend = {
    --[=[
        Read the translations of a language and namespace. May yield.
    ]=]
    read: (language: LanguageCode, namespace: string) -> Translations,
}

--[=[
    Options for creating a `Localize` instance.
]=]
export type LocalizeOptions = {
    --[=[
        The current language.
    ]=]
    language: LanguageCode,
    --[=[
        The language to use when a key is missing from the current language.
    ]=]
    fallbackLanguage: LanguageCode?,
    --[=[
        The namespaces to load. Defaults to `{ defaultNamespace }`.
    ]=]
    namespaces: { string }?,
    --[=[
        The namespace of keys without one. Defaults to the first of
        `namespaces`, or `"translation"`.
    ]=]
    defaultNamespace: string?,
    --[=[
        Loads the translations.
    ]=]
    backend: Backend,
    --[=[
        Separates a key from its plural form. Defaults to `"_"`.
    ]=]
    pluralSeparator: string?,
    --[=[
        Separates a namespace from a key. Defaults to `":"`, `false` disables
        namespaces in keys.
    ]=]
    namespaceSeparator: (string | false)?,
}

--[=[
    Options for a lookup. All entries are available to interpolation.
]=]
export type TranslationOptions = {
    --[=[
        The number that selects a plural form.
    ]=]
    count: number?,
    --[=[
        Whether `count` selects an ordinal plural form.
    ]=]
    ordinal: boolean?,
    [string]: any,
}

type Fields = {
    language: LanguageCode,
    fallbackLanguage: LanguageCode?,
    namespaces: { string },
    defaultNamespace: string,
    translations: { [string]: { [string]: Translations } },
    backend: Backend,
    pluralSeparator: string,
    namespaceSeparator: string | false,
    languageChangeId: number,
}

local Localize = {}
Localize.__index = Localize

export type Localize = typeof(setmetatable({} :: Fields, Localize))

--[=[
    Get the plural category of a count.

    @param language The language to get the category for.
    @param count The count.
    @param ordinal Whether to use the ordinal rules.
    @return The plural category.
]=]
local function getPluralCategory(
    language: string,
    count: number,
    ordinal: boolean
): PluralizationCount
    if (dataModule.LanguageMetadata :: any)[language] == nil then
        return "other"
    end

    local rules =
        dataModule.getLanguageConfiguration(language :: any).pluralization
    local operands = operandsModule.generateOperands(count)
    return if ordinal then rules.ordinal(operands) else rules.cardinal(operands)
end

--[=[
    Get the keys to try for a lookup in a language.

    @param language The language of the lookup.
    @param key The key, without its namespace.
    @param options The lookup options.
    @param separator The plural separator.
    @return The keys to try.
]=]
local function getCandidateKeys(
    language: string,
    key: string,
    options: TranslationOptions,
    separator: string
): { string }
    local count = options.count
    if type(count) ~= "number" then return { key } end

    local ordinal = options.ordinal == true
    local prefix = if ordinal
        then `{key}{separator}ordinal{separator}`
        else key .. separator
    local category = getPluralCategory(language, count, ordinal)
    return { prefix .. category, `{prefix}other`, key }
end

--[=[
    Replace the placeholders in a string.

    @param text The string.
    @param variables The values of the variables.
    @return The interpolated string.
]=]
local function interpolate(text: string, variables: { [string]: any }): string
    local result: { string } = {}
    for _, part in interpolationModule.parse(text) do
        if type(part) == "string" then
            table.insert(result, part)
            continue
        end

        local value = variables[part.name]
        table.insert(
            result,
            if value == nil then `\{\{{part.raw}}}` else tostring(value)
        )
    end
    return table.concat(result)
end

--[=[
    Warn if a language is not supported.

    @param language The language.
]=]
local function warnIfUnsupported(language: string)
    if (dataModule.LanguageMetadata :: any)[language] == nil then
        warn(`unsupported language "{language}"`)
    end
end

--[=[
    Create a `Localize` instance and load its language.

    @yields based on the backend's `read` method.
    @param options The options.
    @return The instance.
]=]
function Localize.new(options: LocalizeOptions): Localize
    local namespaces = options.namespaces
    local defaultNamespace = options.defaultNamespace
        or (namespaces and namespaces[1])
        or "translation"

    local self: Fields = {
        language = options.language,
        fallbackLanguage = options.fallbackLanguage,
        namespaces = if namespaces
            then table.clone(namespaces)
            else { defaultNamespace },
        defaultNamespace = defaultNamespace,
        translations = {},
        backend = options.backend,
        pluralSeparator = options.pluralSeparator or "_",
        namespaceSeparator = if options.namespaceSeparator == nil
            then ":"
            else options.namespaceSeparator,
        languageChangeId = 0,
    }

    local instance: any = setmetatable(self, Localize)
    local language = options.language
    local fallback = options.fallbackLanguage
    instance:loadLanguages(
        if fallback ~= nil and fallback ~= language
            then { language, fallback }
            else language
    )
    return instance
end

--[=[
    Translate a key.

    @param key The key, optionally prefixed with a namespace.
    @param options The plural options and interpolation variables.
    @return The translation, or the key if there is none.
]=]
function Localize.t(
    self: Localize,
    key: string,
    options: TranslationOptions?
): string
    local variables: TranslationOptions = options or {} :: any
    local namespace = self.defaultNamespace
    local name = key

    local separator = self.namespaceSeparator
    if type(separator) == "string" then
        local first, last = key:find(separator, 1, true)
        if first ~= nil and last ~= nil then
            namespace = key:sub(1, first - 1)
            name = key:sub(last + 1)
        end
    end

    local fallback = self.fallbackLanguage
    local languages: { string } = if fallback ~= nil
            and fallback ~= self.language
        then { self.language, fallback }
        else { self.language }

    for _, language in languages do
        local languageTranslations = self.translations[language]
        local translations = languageTranslations
            and languageTranslations[namespace]
        if translations ~= nil then
            local candidates = getCandidateKeys(
                language,
                name,
                variables,
                self.pluralSeparator
            )
            for _, candidate in candidates do
                local text = translations[candidate]
                if type(text) == "string" then
                    return interpolate(text, variables)
                end
            end
        end
    end

    return key
end

--[=[
    Load a namespace of a language, unless it is already available.

    @param language The language.
    @param namespace The namespace.
]=]
local function loadNamespace(
    self: Localize,
    language: string,
    namespace: string
)
    local loaded = self.translations[language]
    if loaded ~= nil and loaded[namespace] ~= nil then return end

    local translations = self.backend.read(language :: any, namespace)
    if type(translations) ~= "table" then
        error(`backend.read({language}, {namespace}) did not return a table`, 0)
    end

    local languageTranslations = self.translations[language] or {}
    languageTranslations[namespace] = translations
    self.translations[language] = languageTranslations
end

--[=[
    Load the current namespaces of languages through the backend.

    @yields based on the backend's `read` method.
    @param languages The language or languages to load.
]=]
function Localize.loadLanguages(
    self: Localize,
    languages: LanguageCode | { LanguageCode }
)
    local list: { LanguageCode } = if type(languages) == "table"
        then languages
        else { languages }
    for _, language in list do
        warnIfUnsupported(language)
    end

    for _, language in list do
        for _, namespace in self.namespaces do
            loadNamespace(self, language, namespace)
        end
    end
end

--[=[
    Add and load namespaces through the backend.

    @yields based on the backend's `read` method.
    @param namespaces The namespace or namespaces to add.
]=]
function Localize.loadNamespaces(
    self: Localize,
    namespaces: string | { string }
)
    local list: { string } = if type(namespaces) == "table"
        then namespaces
        else { namespaces }

    for _, namespace in list do
        if table.find(self.namespaces, namespace) == nil then
            table.insert(self.namespaces, namespace)
        end
    end

    local fallback = self.fallbackLanguage
    for _, namespace in list do
        loadNamespace(self, self.language, namespace)
        if fallback ~= nil and fallback ~= self.language then
            loadNamespace(self, fallback, namespace)
        end
    end
end

--[=[
    Change the current language.

    @yields based on the backend's `read` method.
    @param language The language to change to.
]=]
function Localize.changeLanguage(self: Localize, language: LanguageCode)
    self.languageChangeId += 1
    local id = self.languageChangeId

    local fallback = self.fallbackLanguage
    local languages: any = if fallback ~= nil
        then { language, fallback :: any }
        else language
    self:loadLanguages(languages)

    if id ~= self.languageChangeId then return end
    self.language = language
end

return {
    Localize = Localize,
    new = Localize.new,
    LanguageCodes = dataModule.LanguageCodes,
    LanguageMetadata = dataModule.LanguageMetadata,
    robloxLocaleIdToLanguageCode = dataModule.robloxLocaleIdToLanguageCode,
    getLanguageConfiguration = dataModule.getLanguageConfiguration,
    generateOperands = operandsModule.generateOperands,
}
